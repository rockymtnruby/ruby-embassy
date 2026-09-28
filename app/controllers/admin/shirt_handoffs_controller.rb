require "csv"

class Admin::ShirtHandoffsController < AdminController
  before_action :set_handoff, only: %i[edit update mark_given unmark]

  def index
    @status = ShirtHandoff.statuses.key?(params[:status].to_s) ? params[:status] : nil
    @query = params[:q].to_s.strip
    @handoffs = filtered_handoffs.to_a
    @size_counts = size_counts
    @status_counts = ShirtHandoff.group(:status).count
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
    redirect_to admin_shirt_handoffs_path(index_params),
                notice: "Shirt marked as given to #{@handoff.user.full_name}."
  end

  def unmark
    @handoff.unmark!
    redirect_to admin_shirt_handoffs_path(index_params),
                notice: "Handoff undone for #{@handoff.user.full_name}."
  end

  def export
    @status = ShirtHandoff.statuses.key?(params[:status].to_s) ? params[:status] : nil
    @query = params[:q].to_s.strip
    csv = CSV.generate(headers: true) do |rows|
      rows << %w[name email size status note given_at]
      filtered_handoffs.each do |handoff|
        rows << [
          handoff.user.full_name,
          handoff.user.email,
          handoff.size,
          handoff.status,
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

  def handoff_params
    params.require(:shirt_handoff).permit(:size, :status, :note)
  end

  def index_params
    { q: params[:q].to_s.strip, status: params[:status] }.compact_blank
  end
end
