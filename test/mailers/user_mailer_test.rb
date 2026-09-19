require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "login_link" do
    user = users(:attendee_one)

    email = UserMailer.login_link(user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ user.email ], email.to
    assert_equal [ "noreply@rockymtnruby.dev" ], email.from
    assert_equal "Your Ruby Embassy login link", email.subject

    login_url_prefix = Rails.application.routes.url_helpers.callback_session_url(host: "example.com")
    assert_includes email.text_part.body.to_s, login_url_prefix
    assert_includes email.html_part.body.to_s, login_url_prefix
  end
end
