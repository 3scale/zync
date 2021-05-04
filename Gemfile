# frozen_string_literal: true
source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.2'
gem 'pg', '>= 0.20'
# Use Puma as the app server

gem 'puma', '~> 5.2'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

gem 'activerecord-pg_enum'

gem 'responders', '~> 3.0.1'
gem '3scale-api'

gem 'bootsnap', '>= 1.4.4'

gem 'que', '>= 1.0.0.beta3'
gem 'que-web'

gem 'bugsnag'
# bugsnag-capistrano 2.x does not have a rake task to report deploys
# https://github.com/bugsnag/bugsnag-capistrano/blob/8bcfb27cf6eaff312eef086cce729d553a431460/UPGRADING.md
gem 'bugsnag-capistrano', '< 2', require: false

# This fork allows setting SSL_CERT_FILE and SSL_CERT_DIR
# https://github.com/nahi/httpclient/issues/369
gem 'httpclient', github: '3scale/httpclient', branch: 'ssl-env-cert'
gem 'oauth2'
gem 'k8s-client', '>= 0.10'

gem 'lograge'

gem 'message_bus' # for publishing notifications about integration status

gem 'validate_url'

gem 'prometheus-client', '~> 2.1.0', require: %w[prometheus/client]
gem 'yabeda-rails'
gem 'yabeda-prometheus', '~> 0.6.1'
gem 'yabeda-puma-plugin'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'

  gem 'license_finder', '~> 6.10'
  gem 'license_finder_xml_reporter', git: 'https://github.com/3scale/license_finder_xml_reporter.git', tag: '1.0.0'
  # rubyzip is a transitive depencency from license_finder with vulnerability on < 1.3.0
  gem 'rubyzip', '>= 1.3.0'

  # gem 'httplog'
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
