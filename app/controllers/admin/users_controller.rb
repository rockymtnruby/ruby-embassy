module Admin
  class UsersController < AdminController
    SORTABLE_COLUMNS = {
      "name"      => "users.last_name, users.first_name",
      "role"      => "users.role",
      "last_seen" => "users.last_seen_at"
    }.freeze
    DEFAULT_ORDER = "users.last_name ASC, users.first_name ASC"
    COMPUTED_SORTS = %w[rsvps volunteer_spots hosting].freeze

    def index
      @sync_status = TitoSyncJob.status
      order_clause = apply_sort(SORTABLE_COLUMNS) || DEFAULT_ORDER
      @query = params[:q].to_s.strip
      @users = filtered_users.reorder(Arel.sql(order_clause)).to_a

      user_ids = @users.map(&:id)

      @rsvp_counts = PlanItem.joins(:schedule_item)
                             .where(user_id: user_ids)
                             .merge(ScheduleItem.where.not(kind: [ :talk, :reception, :volunteer ]))
                             .group(:user_id)
                             .count

      @volunteer_counts = PlanItem.joins(:schedule_item)
                                  .where(user_id: user_ids)
                                  .merge(ScheduleItem.volunteer)
                                  .group(:user_id)
                                  .count

      @hosting_counts = ScheduleItem.public_items
                                    .where.not(host: [ nil, "" ])
                                    .group(:host)
                                    .count

      apply_computed_sort
    end

    def show
      @user = User.find(params[:id])
      @show_past = params[:show_past].present?

      all_plan_items = @user.plan_items
                            .includes(:schedule_item)
                            .sort_by { |pi|
                              [
                                ScheduleItem::DAY_META.keys.index(pi.schedule_item.day) || 99,
                                pi.schedule_item.sort_time.to_i
                              ]
                            }
      all_plan_items = all_plan_items.reject { |pi| pi.schedule_item.passed? } unless @show_past

      @embassy_plan_items = all_plan_items.select { |pi| pi.schedule_item.embassy? }
      @other_plan_items = all_plan_items.reject do |pi|
        pi.schedule_item.embassy? || ScheduleItem::DEFAULT_PLAN_KINDS.include?(pi.schedule_item.kind)
      end

      # "Hosting" = any schedule_item whose host string matches this user's
      # full_name. Catches both admin-dropdown assignments and user-created
      # custom blocks (the user-facing controller auto-sets host to
      # current_user.full_name on create).
      hosted_scope = ScheduleItem.where(host: @user.full_name).ordered
      hosted_scope = hosted_scope.not_passed unless @show_past
      @hosted_items = hosted_scope
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      # Locks the role against TitoSyncJob's auto-promotion. An admin
      # explicitly choosing a role here — even the default — is a
      # deliberate decision the sync should never override.
      @user.role_set_by_admin = true if @user.role_changed?

      if @user.save(context: :interactive)
        redirect_to admin_users_path, notice: "User added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.assign_attributes(user_params)
      # See the same line in #create — an admin changing role here locks it
      # against TitoSyncJob's auto-promotion.
      @user.role_set_by_admin = true if @user.role_changed?

      if @user.save(context: :interactive)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      User.find(params[:id]).destroy
      redirect_to admin_users_path, notice: "User removed."
    end

    def sync
      if TitoSyncJob.running?
        return redirect_to admin_users_path, alert: "A sync is already running."
      end

      TitoSyncJob.mark_running!
      TitoSyncJob.perform_later
      redirect_to admin_users_path, notice: "Sync started."
    end

    private

    # Sorts @users in-memory by one of the computed count columns. apply_sort
    # already cleared @sort/@dir because these keys aren't in SORTABLE_COLUMNS;
    # we set them here so the view's sort_link can render the active arrow.
    def apply_computed_sort
      return unless COMPUTED_SORTS.include?(params[:sort]) &&
                    %w[asc desc].include?(params[:dir])

      @sort = params[:sort]
      @dir  = params[:dir]
      value_for =
        case @sort
        when "rsvps"           then ->(u) { @rsvp_counts[u.id] || 0 }
        when "volunteer_spots" then ->(u) { @volunteer_counts[u.id] || 0 }
        when "hosting"         then ->(u) { @hosting_counts[u.full_name] || 0 }
        end

      @users = @users.sort_by { |u| [ value_for.call(u), u.last_name.to_s, u.first_name.to_s ] }
      @users.reverse! if @dir == "desc"
    end

    def filtered_users
      scope = User.all
      return scope if @query.blank?

      term = "%#{@query}%"
      scope.where(
        "first_name ILIKE :t OR last_name ILIKE :t OR email ILIKE :t",
        t: term
      )
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :role)
    end
  end
end
