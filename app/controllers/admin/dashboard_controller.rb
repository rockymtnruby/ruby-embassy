module Admin
  class DashboardController < AdminController
    skip_before_action :require_admin!
    before_action :require_admin_or_volunteer!

    def show
      return if current_user.volunteer?

      @attendees_count            = User.attendee.count
      @embassy_applications_count = EmbassyApplication.submitted.where(passport_received_at: nil).count
      @rsvps_count                = PlanItem.joins(:schedule_item)
                                            .merge(ScheduleItem.where.not(kind: [ :talk, :reception, :volunteer ]))
                                            .count
      @volunteers_needed_count    = ScheduleItem.volunteer_empty
                                                .where(day: ScheduleItem.upcoming_day_keys)
                                                .count
    end
  end
end
