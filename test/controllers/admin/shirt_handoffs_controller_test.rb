require "test_helper"

class Admin::ShirtHandoffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:attendee_one)
    @handoff = @user.shirt_handoff
  end

  test "attendee GET /admin/shirt_handoffs returns 404" do
    sign_in_as users(:attendee_one)
    get admin_shirt_handoffs_path
    assert_response :not_found
  end

  test "admin GET /admin/shirt_handoffs returns 200 with search and filters" do
    sign_in_as users(:jeremy)
    get admin_shirt_handoffs_path
    assert_response :success
    assert_select "form[action=?]", admin_shirt_handoffs_path
    assert_select "a[href^=?]", "/admin/shirt_handoffs/export"
  end

  test "admin can filter by status and search by name" do
    @handoff.update!(status: :given)

    sign_in_as users(:jeremy)
    get admin_shirt_handoffs_path, params: { status: "given" }
    assert_match @user.full_name, response.body
    assert_no_match users(:volunteer_one).full_name, response.body

    get admin_shirt_handoffs_path, params: { q: "vic" }
    assert_match users(:volunteer_one).full_name, response.body
    assert_no_match @user.full_name, response.body
  end

  test "admin can mark given and undo" do
    sign_in_as users(:jeremy)

    patch mark_given_admin_shirt_handoff_path(@handoff)
    assert @handoff.reload.given?
    assert @handoff.given_at.present?

    patch unmark_admin_shirt_handoff_path(@handoff)
    assert @handoff.reload.pending?
    assert_nil @handoff.given_at
  end

  test "admin GET edit returns 200" do
    sign_in_as users(:jeremy)
    get edit_admin_shirt_handoff_path(@handoff)
    assert_response :success
    assert_match "Size", response.body
  end

  test "admin can update size, status, and note" do
    sign_in_as users(:jeremy)
    patch admin_shirt_handoff_path(@handoff), params: {
      shirt_handoff: { size: "XL", status: "missed", note: "Ran out of L" }
    }
    @handoff.reload
    assert_equal "XL", @handoff.size
    assert @handoff.missed?
    assert_equal "Ran out of L", @handoff.note
  end

  test "export CSV respects the active filter" do
    @handoff.update!(status: :missed, note: "no-show")

    sign_in_as users(:jeremy)
    get export_admin_shirt_handoffs_path, params: { status: "missed", format: :csv }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "name,email,size,status,note,given_at", response.body
    assert_match @user.email, response.body
    assert_no_match users(:volunteer_one).email, response.body
  end
end
