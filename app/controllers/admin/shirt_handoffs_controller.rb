require "csv"

class Admin::ShirtHandoffsController < AdminController
  # Phase 2: volunteers work the swag table, so they get full access here.
  # Every other admin page stays admin-only via AdminController.
  skip_before_action :require_admin!
  before_action :require_admin_or_volunteer!

  before_action :set_handoff, only: %i[edit update mark_given unmark]

  def index
    @status = ShirtHandoff.statuses.key?(params[:status].to_s) ? params[:status] : nil
    @query = params[:q].to_s.strip
    @release_options = release_options
    @releases = Array(params[:release]).map(&:to_s) & @release_options
    @handoffs = filtered_handoffs.to_a
    @size_counts = size_counts
    @status_counts = ShirtHandoff.group(:status).count
    @release_counts = ShirtHandoff.joins(:user).where.not(users: { tito_release_title: [ nil, "" ] })
                                  .group("users.tito_release_title").count
    @inventory_rows, @inventory_total_left, @inventory_total_given, @inventory_no_size = inventory
  end

  def edit
  end

  def update
    if @handoff.update(handoff_params)
      redirect_to admin_shirt_handoffs_path(index_params),
                  notice: "Swag record updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def mark_given
    @handoff.mark_given!
    redirect_to admin_shirt_handoffs_path(index_params)
  end

  def unmark
    @handoff.unmark!
    redirect_to admin_shirt_handoffs_path(index_params)
  end

  def export
    @status = ShirtHandoff.statuses.key?(params[:status].to_s) ? params[:status] : nil
    @query = params[:q].to_s.strip
    @release_options = release_options
    @releases = Array(params[:release]).map(&:to_s) & @release_options
    csv = CSV.generate(headers: true) do |rows|
      rows << %w[name email size status ticket_type note given_at]
      filtered_handoffs.each do |handoff|
        rows << [
          handoff.user.full_name,
          handoff.user.email,
          handoff.size,
          handoff.status,
          handoff.user.tito_release_title,
          handoff.note,
          handoff.given_at&.iso8601
        ]
      end
    end
    filename = "#{Date.current.year}-rmr-app-shirts-export#{('-' + @status) if @status.present?}.csv"
    send_data csv, filename: filename, type: "text/csv"
  end

  private

  def set_handoff
    @handoff = ShirtHandoff.includes(:user).find(params[:id])
  end

  def filtered_handoffs
    scope = ShirtHandoff.for_status(@status).joins(:user).includes(:user)
                        .order("users.last_name ASC", "users.first_name ASC")
    scope = scope.where(users: { tito_release_title: @releases }) if @releases.any?
    return scope if @query.blank?

    term = "%#{@query}%"
    scope.where(
      "users.first_name ILIKE :t OR users.last_name ILIKE :t OR users.email ILIKE :t",
      t: term
    )
  end

  # Pending + given counts per size for at-a-glance inventory.
  def size_counts
    ShirtHandoff.where(status: %i[pending given])
                .group(:size, :status).count
  end

  # Per-size inventory rows plus totals for the collapsed summary.
  def inventory
    rows = ShirtHandoff::SIZES.map do |size|
      [ size, @size_counts[[ size, "pending" ]] || 0, @size_counts[[ size, "given" ]] || 0 ]
    end
    blank_left = @size_counts.select { |(size, status), _| size.blank? && status == "pending" }.values.sum
    blank_given = @size_counts.select { |(size, status), _| size.blank? && status == "given" }.values.sum
    rows << [ "No answer", blank_left, blank_given ] if blank_left.positive? || blank_given.positive?
    [ rows, rows.sum(&:second), rows.sum(&:third), blank_left + blank_given ]
  end

  # Distinct raw Tito release titles, for the ticket-type filter.
  def release_options
    User.where.not(tito_release_title: [ nil, "" ]).distinct.order(:tito_release_title).pluck(:tito_release_title)
  end

  def handoff_params
    params.require(:shirt_handoff).permit(:size, :status, :note)
  end

  def index_params
    releases = Array(params[:release]).map(&:to_s).reject(&:blank?)
    { q: params[:q].to_s.strip, status: params[:status], release: releases.presence }.compact_blank
  end
end
