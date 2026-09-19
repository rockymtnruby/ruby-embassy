require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "destroying user destroys their plan_items" do
    user = users(:attendee_one)
    item = ScheduleItem.create!(day: "mon", title: "Destroy test", kind: :activity, is_public: true)
    user.plan_items.create!(schedule_item: item)

    assert_difference -> { PlanItem.count }, -1 do
      user.destroy
    end
  end

  test "destroying user nullifies created_schedule_items (items survive)" do
    creator = users(:attendee_one)
    item = ScheduleItem.create!(
      day: "mon",
      title: "Creator-owned",
      kind: :activity,
      is_public: true,
      created_by: creator
    )

    creator.destroy

    assert ScheduleItem.exists?(item.id), "schedule_item should survive creator deletion"
    assert_nil item.reload.created_by_id
  end

  test "planned_schedule_items returns items on user's plan" do
    user = users(:attendee_one)
    item = ScheduleItem.create!(day: "mon", title: "Planned", kind: :talk, is_public: true)
    user.plan_items.create!(schedule_item: item)

    assert_includes user.planned_schedule_items, item
  end

  test "new user is auto-RSVPed to all default-plan items" do
    talk      = ScheduleItem.create!(day: "mon", title: "Default Talk", kind: :talk, is_public: true)
    reception = ScheduleItem.create!(day: "mon", title: "Default Reception", kind: :reception, is_public: true)
    activity  = ScheduleItem.create!(day: "tue", title: "Optional Activity", kind: :activity, is_public: true)
    private_talk = ScheduleItem.create!(day: "mon", title: "Private Talk", kind: :talk, is_public: false)
    volunteers_only_reception = ScheduleItem.create!(
      day: "mon", title: "Crew Reception", kind: :reception,
      is_public: true, audience: "volunteers_only"
    )

    user = User.create!(email: "newbie@example.com", first_name: "New", last_name: "Bie")

    assert_includes user.planned_schedule_items, talk
    assert_includes user.planned_schedule_items, reception
    assert_not_includes user.planned_schedule_items, activity, "non-default kinds should not be auto-added"
    assert_not_includes user.planned_schedule_items, private_talk, "private items should not be auto-added"
    assert_not_includes user.planned_schedule_items, volunteers_only_reception, "volunteers_only items should not be auto-added to attendees"
  end

  test "new user is auto-RSVPed to slug-allowlisted items even when kind isn't a default" do
    # DEFAULT_PLAN_SLUGS is empty for the current (RMR) schedule — this fork
    # has no one-off item that needs force-adding. Stub it so the general
    # mechanism (added for BRR's "Mystery Activity") still has coverage
    # independent of whatever the seeded schedule happens to contain.
    allowlisted = ScheduleItem.create!(
      slug: "test-oneoff", day: "mon", title: "One-off Activity",
      kind: :community, is_public: true
    )
    other_community = ScheduleItem.create!(
      slug: "test-other-community", day: "sun", title: "Other Community Item",
      kind: :community, is_public: true
    )

    ScheduleItem.send(:remove_const, :DEFAULT_PLAN_SLUGS)
    ScheduleItem.const_set(:DEFAULT_PLAN_SLUGS, %w[test-oneoff].freeze)

    user = User.create!(email: "mystery@example.com", first_name: "M", last_name: "Y")

    assert_includes user.planned_schedule_items, allowlisted, "slug-allowlisted item should be auto-added"
    assert_not_includes user.planned_schedule_items, other_community, "other community items should not auto-add"
  ensure
    ScheduleItem.send(:remove_const, :DEFAULT_PLAN_SLUGS)
    ScheduleItem.const_set(:DEFAULT_PLAN_SLUGS, [].freeze)
  end

  test "materialize_default_plan_items is idempotent" do
    ScheduleItem.create!(day: "mon", title: "Default Talk", kind: :talk, is_public: true)
    user = User.create!(email: "idem@example.com", first_name: "I", last_name: "D")

    assert_no_difference -> { user.plan_items.count } do
      user.materialize_default_plan_items
      user.materialize_default_plan_items
    end
  end

  test "last_rsvp_contact_method returns nil when no prior RSVPs have one" do
    assert_nil users(:attendee_one).last_rsvp_contact_method
  end

  test "last_rsvp_contact_method picks the most recent value across meals and activities" do
    user = users(:attendee_one)
    activity = ScheduleItem.create!(day: "mon", title: "Hike", kind: :activity, is_public: true)
    plan = user.plan_items.create!(schedule_item: activity, contact_method: "older value")
    plan.update_columns(updated_at: 2.days.ago)

    meal = ScheduleItem.create!(day: "mon", title: "Lunch", kind: :meal, is_public: true)
    spot = meal.meal_spots.create!(name: "Pinewood", created_by: users(:volunteer_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: user, contact_method: "newer value")

    assert_equal "newer value", user.last_rsvp_contact_method
  end

  test "last_rsvp_contact_method ignores blank entries" do
    user = users(:attendee_one)
    activity = ScheduleItem.create!(day: "mon", title: "Hike", kind: :activity, is_public: true)
    user.plan_items.create!(schedule_item: activity, contact_method: "real value")

    other = ScheduleItem.create!(day: "mon", title: "Other", kind: :activity, is_public: true)
    user.plan_items.create!(schedule_item: other, contact_method: "")

    assert_equal "real value", user.last_rsvp_contact_method
  end

  test "propagate_contact_to_blank_rsvps! fills only blank meal RSVPs and plan_items" do
    user = users(:attendee_one)
    blank_activity = ScheduleItem.create!(day: "mon", title: "Hike", kind: :activity, is_public: true)
    set_activity   = ScheduleItem.create!(day: "mon", title: "Bike", kind: :activity, is_public: true)
    blank_pi = user.plan_items.create!(schedule_item: blank_activity)
    blank_pi.update_columns(contact_method: nil)
    set_pi   = user.plan_items.create!(schedule_item: set_activity, contact_method: "explicit")

    meal = ScheduleItem.create!(day: "mon", title: "Lunch", kind: :meal, is_public: true)
    spot = meal.meal_spots.create!(name: "Pinewood", created_by: users(:volunteer_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    blank_rsvp = transport.rsvps.create!(user: user)
    blank_rsvp.update_columns(contact_method: nil)

    user.propagate_contact_to_blank_rsvps!("555-9999")

    assert_equal "555-9999", blank_pi.reload.contact_method
    assert_equal "explicit", set_pi.reload.contact_method
    assert_equal "555-9999", blank_rsvp.reload.contact_method
  end

  test "admin_ticket_url is nil when tito_ticket_slug is blank" do
    assert_nil users(:attendee_one).admin_ticket_url
  end

  test "admin_ticket_url builds a ti.to URL from the row's memorialized slugs" do
    user = User.create!(
      email: "ticketed@example.com", first_name: "Tick", last_name: "Eted",
      tito_ticket_slug: "abc123", tito_account_slug: "some-org", tito_event_slug: "some-event"
    )

    assert_equal "https://ti.to/some-org/some-event/tickets/abc123", user.admin_ticket_url
  end

  test "admin_ticket_url uses the memorialized slugs, not current ENV, once set" do
    user = User.create!(
      email: "ticketed2@example.com", first_name: "Tick", last_name: "Eted",
      tito_ticket_slug: "xyz789", tito_account_slug: "old-org", tito_event_slug: "old-event"
    )

    original_account_slug, original_event_slug = ENV["TITO_ACCOUNT_SLUG"], ENV["TITO_EVENT_SLUG"]
    ENV["TITO_ACCOUNT_SLUG"] = "new-org-from-env"
    ENV["TITO_EVENT_SLUG"] = "new-event-from-env"

    assert_equal "https://ti.to/old-org/old-event/tickets/xyz789", user.admin_ticket_url
  ensure
    ENV["TITO_ACCOUNT_SLUG"], ENV["TITO_EVENT_SLUG"] = original_account_slug, original_event_slug
  end

  test "propagate_contact_to_blank_rsvps! is a no-op for blank input" do
    user = users(:attendee_one)
    activity = ScheduleItem.create!(day: "mon", title: "Hike", kind: :activity, is_public: true)
    pi = user.plan_items.create!(schedule_item: activity)
    pi.update_columns(contact_method: nil)

    user.propagate_contact_to_blank_rsvps!("")
    user.propagate_contact_to_blank_rsvps!(nil)
    user.propagate_contact_to_blank_rsvps!("   ")

    assert_nil pi.reload.contact_method
  end
end
