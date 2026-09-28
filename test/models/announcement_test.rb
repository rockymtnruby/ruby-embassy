require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "requires title and body" do
    announcement = Announcement.new
    assert_not announcement.valid?
    assert_includes announcement.errors[:title], "can't be blank"
    assert_includes announcement.errors[:body], "can't be blank"
  end

  test "visible orders pinned first, then newest" do
    old = Announcement.create!(title: "Old", body: "old")
    pinned = Announcement.create!(title: "Wifi", body: "password", pinned: true)
    fresh = Announcement.create!(title: "Fresh", body: "new")

    assert_equal [ pinned, fresh, old ], Announcement.visible.to_a
  end
end
