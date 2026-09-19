# ActionMailer delivery method for Brevo's transactional email API.
#
# Registered via ActionMailer::Base.add_delivery_method in
# config/environments/production.rb, selected via MAIL_PROVIDER=brevo.
class BrevoDeliveryMethod
  attr_accessor :settings

  def initialize(settings, api_client: nil)
    @settings = settings
    @api_client = api_client
  end

  def deliver!(mail)
    Brevo.configure { |config| config.api_key["api-key"] = settings.fetch(:api_key) }

    api_instance = @api_client || Brevo::TransactionalEmailsApi.new
    # Brevo::SendSmtpEmail#initialize keys its incoming hash by the JSON
    # (camelCase) names, not the snake_case Ruby attribute names its
    # accessors expose — confirmed by reading the gem source directly.
    send_smtp_email = Brevo::SendSmtpEmail.new(
      sender: sender_for(mail),
      to: recipients_for(mail),
      subject: mail.subject,
      htmlContent: part_body(mail, :html),
      textContent: part_body(mail, :text)
    )

    api_instance.send_transac_email(send_smtp_email)
  end

  private

  def sender_for(mail)
    address = Mail::Address.new(mail[:from].to_s)
    { email: address.address, name: address.display_name }.compact
  end

  def recipients_for(mail)
    Array(mail.to).map do |email|
      address = mail[:to].addrs.find { |a| a.address == email } || Mail::Address.new(email)
      { email: address.address, name: address.display_name }.compact
    end
  end

  def part_body(mail, kind)
    return mail.body.decoded unless mail.multipart?

    mime_type = kind == :html ? "text/html" : "text/plain"
    mail.all_parts.find { |p| p.mime_type == mime_type }&.body&.decoded
  end
end
