source 'https://rubygems.org'

ruby file: '.tool-versions'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.3'

gem 'aasm'
gem 'activeadmin', '~> 3.5'
gem 'anyway_config'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false
gem 'flipper'
gem 'httpx'
gem 'jbuilder' # Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jwt'
# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false
gem 'ngrok-wrapper'
gem 'puma', '>= 5.0'
gem 'rest-client'

# Asset pipeline
gem 'sprockets-rails'
gem 'dartsass-sprockets'

# Use the database-backed adapters for Rails.cache and Active Job
gem 'solid_cache'
gem 'solid_queue'

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '>= 2.1'

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[ windows jruby ]

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt', '~> 3.1.7'

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false
  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'
  gem 'dotenv'
  gem 'factory_bot_rails'
  gem 'rspec-rails', '~> 8.0'

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false
end

group :development do
  gem 'annotaterb', require: false
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'shoulda-matchers'
  gem 'selenium-webdriver', '>= 4.11'
  gem 'webmock'
end
