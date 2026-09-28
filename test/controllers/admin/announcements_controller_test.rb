require "test_helper"

class Admin::AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "attendee GET /admin/announcements returns 404" do
    sign_in_as users(:attendee_one)
    get admin_announcements_path
    assert_response :not_found
  end

  test "admin GET /admin/announcements returns 200" do
    sign_in_as users(:jeremy)
    get admin_announcements_path
    assert_response :success
  end

  test "admin can create an announcement with pinned" do
    sign_in_as users(:jeremy)
    assert_difference -> { Announcement.count }, 1 do
      post admin_announcements_path, params: {
        announcement: { title: "Wifi", body: "Network: RMR26", pinned: "1" }
      }
    end
    assert Announcement.last.pinned?
  end

  test "admin can update an announcement" do
    announcement = Announcement.create!(title: "Old", body: "old")
    sign_in_as users(:jeremy)
    patch admin_announcement_path(announcement), params: {
      announcement: { title: "New", body: "new", pinned: "1" }
    }
    announcement.reload
    assert_equal "New", announcement.title
    assert announcement.pinned?
  end

  test "admin can delete an announcement" do
    announcement = Announcement.create!(title: "Gone", body: "bye")
    sign_in_as users(:jeremy)
    assert_difference -> { Announcement.count }, -1 do
      delete admin_announcement_path(announcement)
    end
  end
end
