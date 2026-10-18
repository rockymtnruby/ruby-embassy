# require "test_helper"
#
# class Admin::MaintenanceControllerTest < ActionDispatch::IntegrationTest
#   test "attendee POST clear_finished_jobs returns 404" do
#     sign_in_as users(:attendee_one)
#     post admin_clear_finished_jobs_path
#     assert_response :not_found
#   end
#
#   test "volunteer POST clear_finished_jobs returns 404" do
#     sign_in_as users(:volunteer_one)
#     post admin_clear_finished_jobs_path
#     assert_response :not_found
#   end
#
#   test "admin POST clear_finished_jobs clears and redirects back to jobs dashboard" do
#     sign_in_as users(:jeremy)
#
#     # Swap the method directly (minitest 6 has no minitest/mock). The real
#     # method is never invoked, so this never touches the queue database —
#     # which isn't even configured in the test env.
#     original = SolidQueue::Job.method(:clear_finished_in_batches)
#     cleared = false
#     seen_kwargs = nil
#     SolidQueue::Job.define_singleton_method(:clear_finished_in_batches) do |*args, **kwargs|
#       cleared = true
#       seen_kwargs = kwargs
#     end
#     begin
#       post admin_clear_finished_jobs_path
#     ensure
#       SolidQueue::Job.define_singleton_method(:clear_finished_in_batches, original)
#     end
#
#     assert cleared, "expected SolidQueue::Job.clear_finished_in_batches to run"
#     # Must clear ALL finished rows, not just ones older than Solid Queue's
#     # 1-day retention default — otherwise recently finished jobs survive the
#     # click while the flash claims success.
#     assert seen_kwargs[:finished_before] >= 1.minute.ago
#     assert_redirected_to "/admin/jobs"
#     assert_equal "Finished jobs cleared.", flash[:notice]
#   end
# end
