# frozen_string_literal: true
source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.3'
gem 'pg', '>= 0.20'
# Use Puma as the app server
gem 'puma', '~> 3.12'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

gem 'responders', '~> 2.4.1'
gem '3scale-api', '~> 0.1.9'

gem 'bootsnap'

gem 'que', '>= 1.0.0.beta3'

gem 'bugsnag'
# bugsnag-capistrano 2.x does not have a rake task to report deploys
# https://github.com/bugsnag/bugsnag-capistrano/blob/8bcfb27cf6eaff312eef086cce729d553a431460/UPGRADING.md
gem 'bugsnag-capistrano', '< 2', require: false

# This fork allows setting SSL_CERT_FILE and SSL_CERT_DIR
# https://github.com/nahi/httpclient/issues/369
gem 'httpclient', github: 'mikz/httpclient', branch: 'ssl-env-cert'
gem 'oauth2'

gem 'lograge'

gem 'message_bus' # for publishing notifications about integration status

gem 'validate_url'

gem 'prometheus-client', require: %w[prometheus/client prometheus/middleware/exporter]

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'

  gem 'license_finder', '~> 5.7'
  gem 'license_finder_xml_reporter', git: 'https://github.com/3scale/license_finder_xml_reporter.git', tag: '1.0.0'
end

group :development do
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

group :test do
  gem 'minitest-reporters'
  gem 'webmock', '~>3.5'
  gem 'codecov', require: false
end
