class TitoSyncJob < ApplicationJob
  CACHE_KEY = "tito_sync:status"
  STALE_AFTER = 15.minutes

  # Maps a Tito release title to the role a ticket-holder should get.
  # Matched by title, not release_id — release ids are recreated every year,
  # but a "Volunteer"-ish title is likely to persist. Falls back to :attendee
  # for anything unmatched, so a brand-new release type next year is safe by
  # default rather than erroring.
  ROLE_BY_RELEASE_TITLE = {
    /volunteer/i => :volunteer
  }.freeze

  # Matches a Tito release whose buyers get no shirt (late purchases go on
  # hold for leftovers). Same title-matching approach as ROLE_BY_RELEASE_TITLE.
  WAITLIST_BY_RELEASE_TITLE = {
    /late ticket/i => true
  }.freeze

  # Title of the Tito ticket question holding the attendee's shirt size.
  SHIRT_SIZE_QUESTION_TITLE = /t-shirt size/i.freeze

  retry_on Tito::Error, wait: 30.seconds, attempts: 3 if defined?(Tito::Error)

  def self.status
    Rails.cache.read(CACHE_KEY)
  end

  def self.running?
    status = self.status
    status && status[:state] == :running && status[:started_at] > STALE_AFTER.ago
  end

  def self.mark_running!
    Rails.cache.write(CACHE_KEY, { state: :running, started_at: Time.current })
  end

  def perform
    users = User.all.to_a
    slugs  = users.each_with_object({}) { |u, h| h[u.tito_ticket_slug] = u if u.tito_ticket_slug.present? }
    emails = users.each_with_object({}) { |u, h| (h[u.email.downcase] ||= u) if u.email.present? && u.tito_ticket_slug.blank? }
    release_titles = fetch_release_titles
    shirt_sizes = fetch_shirt_sizes

    already = 0
    connected = 0
    added = 0
    failed = 0

    User.tito_client.tickets.where(state: %w[complete]).each do |ticket|
      role = role_for(release_titles[ticket.release_id])
      fresh = false

      if (user = slugs[ticket.slug])
        # This has to run here too, not just on connect/create below — most
        # tickets hit this branch on every resync after the first, since
        # they're already linked by slug.
        promote!(user, role)
        already += 1
      elsif (user = emails[ticket.email.to_s.downcase])
        user.update!(
          tito_ticket_slug: ticket.slug,
          first_name: ticket.first_name,
          last_name: ticket.last_name
        )
        promote!(user, role)
        connected += 1
      else
        user = User.create!(
          tito_ticket_slug: ticket.slug,
          first_name: ticket.first_name,
          last_name: ticket.last_name,
          email: ticket.email,
          role: role
        )
        added += 1
        fresh = true
      end
      sync_shirt_handoff!(
        user,
        ticket_size: shirt_sizes[ticket.id],
        waitlisted: waitlisted?(release_titles[ticket.release_id]),
        fresh: fresh
      )
    rescue StandardError => e
      # One malformed ticket shouldn't abort the whole run — count it and move on.
      Rails.logger.error("Tito sync: skipped ticket #{ticket&.slug.inspect}: #{e.class}: #{e.message}")
      failed += 1
    end

    write_status(state: :finished, already: already, connected: connected, added: added, failed: failed)
  rescue StandardError => e
    Rails.logger.error("Tito sync error: #{e.class}: #{e.message}")
    write_status(state: :failed, error: e.message)
  end

  private

  def fetch_release_titles
    User.tito_client.releases.to_a.each_with_object({}) { |r, h| h[r.id] = r.title }
  end

  def role_for(release_title)
    _, role = ROLE_BY_RELEASE_TITLE.find { |pattern, _| release_title&.match?(pattern) }
    role || :attendee
  end

  def waitlisted?(release_title)
    WAITLIST_BY_RELEASE_TITLE.any? { |pattern, _| release_title&.match?(pattern) }
  end

  # Swag sync never overrides human decisions: status is set only for users
  # created on this run (late-ticket release → waitlist), and size is only
  # ever filled when blank. Marking given/missed and notes belong to admins.
  def sync_shirt_handoff!(user, ticket_size:, waitlisted:, fresh:)
    handoff = user.shirt_handoff || user.ensure_shirt_handoff
    handoff.update!(size: ticket_size) if handoff.size.blank? && ticket_size.present?
    handoff.update!(status: :waitlist) if fresh && waitlisted && handoff.pending?
  end

  # Maps Tito ticket ids to shirt sizes via the size question's answers.
  # Best-effort: any failure returns {} and sizes stay admin-editable —
  # the sync must never fail because of swag.
  def fetch_shirt_sizes
    question = User.tito_client.questions.detect { |q| q.title.to_s.match?(SHIRT_SIZE_QUESTION_TITLE) }
    return {} unless question

    question.answers.each_with_object({}) do |answer, map|
      size = answer.response.to_s.strip
      map[answer.ticket_id] = size if answer.ticket_id && size.present?
    end
  rescue StandardError => e
    Rails.logger.error("Tito sync: shirt sizes unavailable: #{e.class}: #{e.message}")
    {}
  end

  # Promotes only — never demotes — and never touches a user whose role an
  # admin has explicitly set, even if that's "attendee". Sync re-walks every
  # ticket on every run with no since-last-sync filter, so this check runs
  # on every single sync, not just the first time a ticket is seen.
  def promote!(user, role)
    return unless user.attendee? && role != :attendee && !user.role_set_by_admin?
    user.update!(role: role)
  end

  def write_status(**attrs)
    status = (Rails.cache.read(CACHE_KEY) || {}).merge(finished_at: Time.current, **attrs)
    Rails.cache.write(CACHE_KEY, status)
    broadcast_status(status)
  end

  def broadcast_status(status)
    Turbo::StreamsChannel.broadcast_replace_to(
      "tito_sync",
      target: "sync_status",
      partial: "admin/users/sync_status",
      locals: { status: status }
    )
  end
end
