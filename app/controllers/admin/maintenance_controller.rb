module Admin
  # One-off queue housekeeping. Admin-only via AdminController#require_admin!
  # (deliberately no skip_before_action here, unlike DashboardController) —
  # volunteers and attendees get a 404, same as the rest of the admin area.
  class MaintenanceController < AdminController
    # On-demand replacement for the old hourly recurring cleanup task (see the
    # commented-out entry in config/recurring.yml). Runs synchronously: the
    # finished-jobs table is small (a handful of rows a week post-event) so the
    # batched delete completes in well under a second — no background job needed.
    # If the table ever grows large enough for this to feel slow, switch to
    # enqueueing a job à la TitoSyncJob instead of running inline here.
    #
    # finished_before: Time.current (instead of Solid Queue's 1-day-retention
    # default) is deliberate: the /admin/jobs finished tab lists ALL finished
    # jobs, so an admin clicking "Clear finished" past a confirm dialog expects
    # all of them gone — including ones finished minutes ago. The old hourly
    # task kept a day of retention; this button does not.
    def clear_finished_jobs
      SolidQueue::Job.clear_finished_in_batches(finished_before: Time.current)
      redirect_back_or_to "/admin/jobs", notice: "Finished jobs cleared."
    end
  end
end
