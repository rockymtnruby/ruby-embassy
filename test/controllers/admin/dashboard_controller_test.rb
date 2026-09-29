require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "anonymous GET /admin returns 404" do
    get admin_root_path
    assert_response :not_found
  end

  test "attendee GET /admin returns 404" do
    sign_in_as users(:attendee_one)
    get admin_root_path
    assert_response :not_found
  end

  test "volunteer GET /admin returns 200 with Volunteer Dashboard and only the Swag tile" do
    sign_in_as users(:volunteer_one)
    get admin_root_path
    assert_response :success
    assert_match "Volunteer Dashboard", response.body
    assert_select "a[href=?]", admin_shirt_handoffs_path
    assert_select "a[href=?]", admin_users_path, count: 0
    assert_select "a[href=?]", admin_root_path, count: 0
    assert_select ".stat-card", count: 0
  end

  test "admin GET /admin returns 200 and shows section links" do
    sign_in_as users(:jeremy)
    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", admin_schedule_items_path
    assert_select "a[href=?]", "/admin/jobs"
  end

  test "dashboard shows counts" do
    # Seed a handful of items so counts are non-zero
    ScheduleItem.create!(day: "mon", title: "Count test", kind: :activity, is_public: true)

    sign_in_as users(:jeremy)
    get admin_root_path

    assert_match(/#{User.count}/, response.body)
  end

  test "rsvps count excludes talks, reception, and volunteer kinds" do
    activity  = ScheduleItem.create!(day: "mon", title: "Hike",    kind: :activity)
    talk      = ScheduleItem.create!(day: "mon", title: "Keynote", kind: :talk)
    reception = ScheduleItem.create!(day: "mon", title: "Welcome", kind: :reception)
    volunteer = ScheduleItem.create!(day: "mon", title: "Stamp",   kind: :volunteer, volunteer_capacity: 5)

    activity.plan_items.create!(user: users(:attendee_one))   # counted
    talk.plan_items.create!(user: users(:attendee_one))       # excluded
    reception.plan_items.create!(user: users(:attendee_one))  # excluded
    volunteer.plan_items.create!(user: users(:volunteer_one)) # excluded

    sign_in_as users(:jeremy)
    get admin_root_path

    rsvp_card = stat_card_with_label("RSVPs")
    assert rsvp_card, "expected an RSVPs stat-card"
    assert_equal "1", stat_card_value(rsvp_card)
  end

  test "volunteers needed count: empty volunteer slots on today or later days" do
    travel_to Date.new(2026, 9, 28) do # mon
      ScheduleItem.create!(day: "sun", title: "Past empty",   kind: :volunteer, volunteer_capacity: 3)
      ScheduleItem.create!(day: "mon", title: "Today empty",  kind: :volunteer, volunteer_capacity: 3)
      ScheduleItem.create!(day: "tue", title: "Future empty", kind: :volunteer, volunteer_capacity: 3)
      filled = ScheduleItem.create!(day: "mon", title: "Filled", kind: :volunteer, volunteer_capacity: 1)
      filled.plan_items.create!(user: users(:volunteer_one))

      sign_in_as users(:jeremy)
      get admin_root_path

      vol_card = stat_card_with_label("Volunteers Needed")
      assert vol_card, "expected a Volunteers Needed stat-card"
      assert_equal "2", stat_card_value(vol_card)
    end
  end

  test "dashboard no longer renders a Schedule Items stat card" do
    sign_in_as users(:jeremy)
    get admin_root_path

    labels = css_select(".stat-card__label").map(&:text).map(&:strip)
    assert_not_includes labels, "Schedule Items"
  end

  private

  def stat_card_with_label(label)
    css_select(".stat-card").find { |c| c.css(".stat-card__label").text.strip == label }
  end

  def stat_card_value(card)
    card.css(".stat-card__value").text.strip
  end
end
