class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM_ADDRESS", "noreply@rockymtnruby.dev")
  layout "mailer"
end
