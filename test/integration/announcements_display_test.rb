require "test_helper"

class AnnouncementsDisplayTest < ActionDispatch::IntegrationTest
  test "signed-in guest sees announcements on dashboard, pinned first" do
    Announcement.create!(title: "Lunch", body: "Tacos at noon")
    Announcement.create!(title: "Wifi", body: "Network: RMR26", pinned: true)

    sign_in_as users(:attendee_one)
    get dashboard_path
    assert_response :success
    assert_match "Wifi", response.body
    assert_match "Lunch", response.body
    assert response.body.index("Wifi") < response.body.index("Lunch")
  end

  test "signed-in guest sees announcements on schedule" do
    Announcement.create!(title: "Wifi", body: "Network: RMR26", pinned: true)

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_response :success
    assert_match "Wifi", response.body
  end

  test "signed-out guest is redirected, not shown wifi" do
    Announcement.create!(title: "Wifi", body: "Network: RMR26", pinned: true)

    get dashboard_path
    assert_redirected_to new_session_path
  end
end
