source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# Pin below the 3.x major bump until app/test compatibility with it is verified
gem "json", "~> 2.19"
# CSV export for the admin swag page (bundled gem since Ruby 3.4)
gem "csv", require: false
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# Commented out 2026-10 (memory trim): no .jbuilder views and no Jbuilder
# constant usage — controllers render HTML/Turbo via respond_to. Restore if a
# JSON API is added.
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "mission_control-jobs"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# Commented out 2026-10 (memory trim): no attachments anywhere in the app
# (no has_one_attached/has_many_attached, no active_storage_* tables, no file
# inputs — lightning talks use a slides URL string). Restore if uploads are added.
# gem "image_processing", "~> 1.2"

# Tito API client for event registration lookup
gem "tito_ruby"

# Postmark for transactional email in production
gem "postmark-rails"

# Brevo for backup transactional email. Its API client is used instead of an
# SMTP delivery method because Brevo's SMTP relay requires a separate,
# support-activated gate on new accounts that the API doesn't have.
# require: false 2026-10 (memory trim): only loaded when MAIL_PROVIDER=brevo,
# via explicit require in lib/brevo_delivery_method.rb.
gem "brevo", require: false

# PDF generation for the passport application form
# require: false 2026-10 (memory trim): both PDF services self-require
# ("prawn" / "prawn/table" at the top of each file), so boot skips ~20-40MB
# until a PDF is actually rendered.
gem "prawn", require: false
gem "prawn-table", require: false

group :development, :test do
  gem "dotenv-rails"
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  gem "letter_opener"

  gem "bullet"
  gem "rack-mini-profiler"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
