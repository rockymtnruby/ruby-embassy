require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "attendee GET /admin/users/:id returns 404" do
    sign_in_as users(:attendee_one)
    get admin_user_path(users(:volunteer_one))
    assert_response :not_found
  end

  test "admin GET /admin/users/:id returns 200" do
    sign_in_as users(:jeremy)
    get admin_user_path(users(:attendee_one))
    assert_response :success
    assert_match users(:attendee_one).full_name, response.body
    assert_match users(:attendee_one).email,     response.body
  end

  test "admin show page lists the user's plan items" do
    alice = users(:attendee_one)
    item = ScheduleItem.create!(
      day: "mon",
      title: "Alice planned activity",
      kind: :activity,
      is_public: true,
      time_label: "10:00 AM",
      sort_time: 1000
    )
    alice.plan_items.create!(schedule_item: item)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_match "Alice planned activity", response.body
  end

  test "admin show hides passed plan items by default and shows them with show_past=1" do
    alice = users(:attendee_one)
    upcoming = ScheduleItem.create!(day: "mon", title: "Show-upcoming", kind: :activity,
                                    is_public: true, time_label: "10:00 AM", sort_time: 1000)
    finished = ScheduleItem.create!(day: "mon", title: "Show-done", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    alice.plan_items.create!(schedule_item: upcoming)
    alice.plan_items.create!(schedule_item: finished)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_match upcoming.title, response.body
    assert_no_match finished.title, response.body

    get admin_user_path(alice), params: { show_past: "1" }
    assert_match upcoming.title, response.body
    assert_match finished.title, response.body
  end

  test "admin show page hides talks and receptions from the plan section" do
    alice = users(:attendee_one)
    talk = ScheduleItem.create!(
      day: "mon", title: "Default Talk", kind: :talk,
      is_public: true, time_label: "10:00 AM", sort_time: 1000
    )
    reception = ScheduleItem.create!(
      day: "mon", title: "Default Reception", kind: :reception,
      is_public: true, time_label: "6:00 PM", sort_time: 1800
    )
    activity = ScheduleItem.create!(
      day: "tue", title: "Optional Activity", kind: :activity,
      is_public: true, time_label: "2:00 PM", sort_time: 1400
    )
    alice.plan_items.create!(schedule_item: talk)
    alice.plan_items.create!(schedule_item: reception)
    alice.plan_items.create!(schedule_item: activity)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_response :success
    assert_match "Optional Activity", response.body
    assert_no_match(/Default Talk/, response.body)
    assert_no_match(/Default Reception/, response.body)
  end

  test "admin users index links to each user's show page" do
    sign_in_as users(:jeremy)
    get admin_users_path

    User.all.each do |u|
      assert_select "a[href=?]", admin_user_path(u)
    end
  end

  test "show page lists events the user is hosting under Hosting" do
    alice = users(:attendee_one)
    ScheduleItem.create!(
      day: "mon",
      title: "Alice hosted session",
      host: alice.full_name,
      kind: :talk,
      is_public: true,
      time_label: "2:00 PM",
      sort_time: 1400
    )

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_response :success
    assert_match "Hosting", response.body
    assert_match "Alice hosted session", response.body
  end

  test "show page surfaces an embassy plan item under its own section" do
    alice = users(:attendee_one)
    embassy = ScheduleItem.create!(
      day: "tue",
      title: "Alice embassy slot",
      kind: :embassy,
      is_public: true,
      offers_new_passport: true,
      new_passport_capacity: 4,
      time_label: "10:00 AM",
      sort_time: 1000,
      flexible: true
    )
    alice.plan_items.create!(schedule_item: embassy)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_select "h2", text: "Embassy"
    assert_match "Alice embassy slot", response.body
  end

  test "embassy plan items do not appear in the generic plan section" do
    alice = users(:attendee_one)
    embassy = ScheduleItem.create!(
      day: "tue",
      title: "Only embassy item",
      kind: :embassy,
      is_public: true,
      offers_new_passport: true,
      new_passport_capacity: 4,
      time_label: "10:00 AM",
      sort_time: 1000
    )
    alice.plan_items.create!(schedule_item: embassy)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    # The embassy header and item render once in the Embassy section,
    # and the catch-all "On their plan" section should show the empty
    # state since this user has no non-embassy plan items.
    assert_match "Nothing else planned", response.body
  end

  test "admin PATCH /admin/users/:id with a role change locks it against TitoSyncJob promotion" do
    sign_in_as users(:jeremy)
    attendee = users(:attendee_one)

    patch admin_user_path(attendee), params: { user: { role: "volunteer" } }

    assert attendee.reload.role_set_by_admin?
    assert attendee.volunteer?
  end

  test "admin PATCH /admin/users/:id without changing role does not lock it" do
    sign_in_as users(:jeremy)
    attendee = users(:attendee_one)

    patch admin_user_path(attendee), params: { user: { role: "attendee", first_name: "Ali" } }

    assert_not attendee.reload.role_set_by_admin?
  end

  test "admin creating a user with an explicit non-default role locks it" do
    sign_in_as users(:jeremy)

    post admin_users_path, params: { user: { email: "newvol@example.com", first_name: "New", last_name: "Vol", role: "volunteer" } }

    assert User.find_by(email: "newvol@example.com").role_set_by_admin?
  end

  test "attendee POST /admin/users/sync returns 404" do
    sign_in_as users(:attendee_one)
    post sync_admin_users_path
    assert_response :not_found
  end

  test "admin POST /admin/users/sync enqueues TitoSyncJob and redirects immediately" do
    sign_in_as users(:jeremy)

    assert_enqueued_with(job: TitoSyncJob) do
      post sync_admin_users_path
    end

    assert_redirected_to admin_users_path
    assert_equal "Sync started.", flash[:notice]
    assert_equal :running, TitoSyncJob.status[:state]
  end

  test "admin POST /admin/users/sync while already running is refused" do
    sign_in_as users(:jeremy)
    TitoSyncJob.mark_running!

    assert_no_enqueued_jobs do
      post sync_admin_users_path
    end

    assert_redirected_to admin_users_path
    assert_equal "A sync is already running.", flash[:alert]
  end

  test "admin POST /admin/users/sync allows re-enqueueing once the running status is stale" do
    sign_in_as users(:jeremy)
    Rails.cache.write(TitoSyncJob::CACHE_KEY, { state: :running, started_at: 1.hour.ago })

    assert_enqueued_with(job: TitoSyncJob) do
      post sync_admin_users_path
    end

    assert_equal "Sync started.", flash[:notice]
  end
end
