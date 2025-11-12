# frozen_string_literal: true
source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 7.0.5'
gem 'zeitwerk', '~> 2.6.18' # keep zeitwerk 2.6 until Ruby is 3.2 or higher
gem 'pg', '>= 0.20'

# Fixing "uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger"
# that fails after upgrading to 1.3.5. Can be removed after upgrading to Rails 7.1
gem 'concurrent-ruby', '1.3.4'

# Use Puma as the app server
gem 'puma', '~> 5.2'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

gem 'activerecord-pg_enum'

gem 'responders', '~> 3.0.1'
gem '3scale-api'

gem 'bootsnap', '>= 1.4.4'

gem 'que', '~> 2.2.1'
gem 'que-web'

gem 'bugsnag'

# This fork allows setting SSL_CERT_FILE and SSL_CERT_DIR
# https://github.com/nahi/httpclient/issues/369
gem 'httpclient', github: '3scale/httpclient', branch: 'ssl-env-cert'
gem 'oauth2'
gem 'k8s-ruby'

gem 'lograge'

gem 'message_bus' # for publishing notifications about integration status

gem 'validate_url'

gem 'prometheus-client', '~> 2.1.0', require: %w[prometheus/client]
gem 'yabeda-rails'
gem 'yabeda-prometheus', '~> 0.6.1'
gem 'yabeda-puma-plugin'

# Dependency for yabeda-prometheus
gem 'webrick'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'

  gem 'license_finder', '~> 7.0.1'

  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

group :test do
  gem 'minitest-reporters'
  gem 'minitest-stub-const'
  gem 'webmock'
  gem 'codecov', require: false
  gem 'simplecov', '~> 0.21.2', require: false
end
