require "test_helper"

class ShirtHandoffTest < ActiveSupport::TestCase
  test "one handoff per user" do
    user = users(:attendee_one)
    assert user.shirt_handoff.present?

    duplicate = ShirtHandoff.new(user: user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "new users automatically get a pending handoff" do
    user = User.create!(email: "fresh@example.com", first_name: "Fresh", last_name: "One")
    assert_equal "pending", user.shirt_handoff.status
  end

  test "mark_given! stamps given_at, unmark! resets to pending" do
    handoff = users(:attendee_one).shirt_handoff

    handoff.mark_given!
    assert handoff.given?
    assert handoff.given_at.present?

    handoff.unmark!
    assert handoff.pending?
    assert_nil handoff.given_at
  end

  test "for_status is junk-safe" do
    assert_equal ShirtHandoff.all.to_a, ShirtHandoff.for_status("bogus").to_a
    assert_equal ShirtHandoff.all.to_a, ShirtHandoff.for_status(nil).to_a
  end

  test "ordered sorts by last name, then first name" do
    last_names = ShirtHandoff.ordered.map { |h| h.user.last_name }
    assert_equal last_names.sort, last_names
  end
end
