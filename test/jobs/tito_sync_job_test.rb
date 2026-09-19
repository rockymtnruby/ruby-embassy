require "test_helper"

class TitoSyncJobTest < ActiveJob::TestCase
  FakeTicket = Struct.new(:slug, :email, :first_name, :last_name, :release_id)
  FakeRelease = Struct.new(:id, :title)

  class FakeTicketsScope
    def initialize(tickets)
      @tickets = tickets
    end

    def where(**)
      @tickets
    end
  end

  class FakeTitoClient
    def initialize(tickets, releases)
      @tickets = tickets
      @releases = releases
    end

    def tickets
      FakeTicketsScope.new(@tickets)
    end

    def releases
      @releases
    end
  end

  def with_fake_tito_client(tickets, releases: [])
    fake_client = FakeTitoClient.new(tickets, releases)
    User.define_singleton_method(:tito_client) { fake_client }
    yield
  ensure
    User.singleton_class.send(:remove_method, :tito_client)
  end

  test "counts already-linked, connects by email, and creates new users" do
    already_linked = users(:attendee_one).tap { |u| u.update!(tito_ticket_slug: "existing-slug") }
    to_connect = User.create!(email: "connectme@example.com", first_name: "Con", last_name: "Nect")

    tickets = [
      FakeTicket.new(already_linked.tito_ticket_slug, already_linked.email, "Alice", "Attendee"),
      FakeTicket.new("connect-slug", to_connect.email, "Con", "Nect"),
      FakeTicket.new("new-slug", "brandnew@example.com", "Brand", "New")
    ]

    with_fake_tito_client(tickets) { TitoSyncJob.perform_now }

    status = TitoSyncJob.status
    assert_equal :finished, status[:state]
    assert_equal 1, status[:already]
    assert_equal 1, status[:connected]
    assert_equal 1, status[:added]
    assert_equal 0, status[:failed]

    assert_equal "connect-slug", to_connect.reload.tito_ticket_slug
    assert User.exists?(email: "brandnew@example.com")
  end

  test "a bad ticket is skipped and counted as failed, without aborting the rest" do
    good_ticket = FakeTicket.new("good-slug", "good@example.com", "Good", "One")
    bad_ticket = FakeTicket.new("bad-slug", nil, "Bad", "One") # nil email breaks .downcase

    with_fake_tito_client([ bad_ticket, good_ticket ]) { TitoSyncJob.perform_now }

    status = TitoSyncJob.status
    assert_equal :finished, status[:state]
    assert_equal 1, status[:added]
    assert_equal 1, status[:failed]
    assert User.exists?(email: "good@example.com")
  end

  test "never modifies role on an existing user, even when re-synced" do
    volunteer = users(:volunteer_one)
    volunteer.update!(tito_ticket_slug: "vol-slug")
    ticket = FakeTicket.new("vol-slug", volunteer.email, volunteer.first_name, volunteer.last_name)

    with_fake_tito_client([ ticket ]) { TitoSyncJob.perform_now }

    assert volunteer.reload.volunteer?
  end

  test "a new user's role is set from their ticket's release title" do
    releases = [ FakeRelease.new(1, "Awesome Volunteer Ticket"), FakeRelease.new(2, "Standard Ticket") ]
    tickets = [
      FakeTicket.new("vol-slug", "newvol@example.com", "New", "Vol", 1),
      FakeTicket.new("std-slug", "newstd@example.com", "New", "Std", 2)
    ]

    with_fake_tito_client(tickets, releases: releases) { TitoSyncJob.perform_now }

    assert_equal "volunteer", User.find_by(email: "newvol@example.com").role
    assert_equal "attendee", User.find_by(email: "newstd@example.com").role
  end

  test "matches release title case-insensitively and independent of exact wording" do
    releases = [ FakeRelease.new(1, "VOLUNTEER (Crew)") ]
    ticket = FakeTicket.new("vol-slug", "crew@example.com", "Crew", "One", 1)

    with_fake_tito_client([ ticket ], releases: releases) { TitoSyncJob.perform_now }

    assert_equal "volunteer", User.find_by(email: "crew@example.com").role
  end

  test "an existing attendee is promoted to volunteer when their release matches on re-sync, connecting by email" do
    attendee = users(:attendee_one)
    releases = [ FakeRelease.new(1, "Awesome Volunteer Ticket") ]
    ticket = FakeTicket.new("vol-slug", attendee.email, attendee.first_name, attendee.last_name, 1)

    with_fake_tito_client([ ticket ], releases: releases) { TitoSyncJob.perform_now }

    assert attendee.reload.volunteer?
  end

  test "an existing attendee already linked by slug is still promoted on a later re-sync" do
    # The most common real-world path: someone was already synced once (so
    # they're linked by tito_ticket_slug, not connected fresh by email), and
    # a later re-sync is what's supposed to notice their volunteer release.
    attendee = users(:attendee_one)
    attendee.update!(tito_ticket_slug: "already-linked-slug")
    releases = [ FakeRelease.new(1, "Awesome Volunteer Ticket") ]
    ticket = FakeTicket.new("already-linked-slug", attendee.email, attendee.first_name, attendee.last_name, 1)

    with_fake_tito_client([ ticket ], releases: releases) { TitoSyncJob.perform_now }

    assert attendee.reload.volunteer?
    assert_equal 1, TitoSyncJob.status[:already]
  end

  test "an attendee whose role was set by an admin is not auto-promoted, even matching a volunteer release" do
    attendee = users(:attendee_one)
    attendee.update!(role_set_by_admin: true)
    attendee.update!(tito_ticket_slug: "already-linked-slug")
    releases = [ FakeRelease.new(1, "Awesome Volunteer Ticket") ]
    ticket = FakeTicket.new("already-linked-slug", attendee.email, attendee.first_name, attendee.last_name, 1)

    with_fake_tito_client([ ticket ], releases: releases) { TitoSyncJob.perform_now }

    assert attendee.reload.attendee?
  end

  test "an existing volunteer or admin is never demoted, regardless of release" do
    volunteer = users(:volunteer_one)
    admin = users(:jeremy)
    releases = [ FakeRelease.new(1, "Standard Ticket") ]
    tickets = [
      FakeTicket.new("vol-slug", volunteer.email, volunteer.first_name, volunteer.last_name, 1),
      FakeTicket.new("admin-slug", admin.email, admin.first_name, admin.last_name, 1)
    ]

    with_fake_tito_client(tickets, releases: releases) { TitoSyncJob.perform_now }

    assert volunteer.reload.volunteer?
    assert admin.reload.admin?
  end

  test "unmatched or missing release titles default to attendee" do
    releases = [ FakeRelease.new(1, "Scholarship") ]
    tickets = [
      FakeTicket.new("scholar-slug", "scholar@example.com", "Scholar", "One", 1),
      FakeTicket.new("unknown-release-slug", "unknownrelease@example.com", "Unknown", "Release", 999)
    ]

    with_fake_tito_client(tickets, releases: releases) { TitoSyncJob.perform_now }

    assert_equal "attendee", User.find_by(email: "scholar@example.com").role
    assert_equal "attendee", User.find_by(email: "unknownrelease@example.com").role
  end

  test "a fatal error writes a failed status" do
    User.define_singleton_method(:tito_client) { raise "boom: unreachable" }

    TitoSyncJob.perform_now

    status = TitoSyncJob.status
    assert_equal :failed, status[:state]
    assert_match "boom: unreachable", status[:error]
  ensure
    User.singleton_class.send(:remove_method, :tito_client)
  end
end
