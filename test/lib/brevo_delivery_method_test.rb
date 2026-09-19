require "test_helper"

class BrevoDeliveryMethodTest < ActiveSupport::TestCase
  class FakeTransactionalEmailsApi
    attr_reader :sent_email

    def send_transac_email(email)
      @sent_email = email
      true
    end
  end

  test "maps a real mailer's Mail::Message to a Brevo send_transac_email call" do
    user = users(:attendee_one)
    mail = UserMailer.login_link(user)
    fake_api = FakeTransactionalEmailsApi.new

    BrevoDeliveryMethod.new({ api_key: "test-key" }, api_client: fake_api).deliver!(mail)

    sent_email = fake_api.sent_email
    assert_equal({ email: "noreply@rockymtnruby.dev" }, sent_email.sender)
    assert_equal [ { email: user.email } ], sent_email.to
    assert_equal "Your Ruby Embassy login link", sent_email.subject
    assert_includes sent_email.html_content, "Sign in"
    assert_includes sent_email.text_content, "Sign in"
  end
end
