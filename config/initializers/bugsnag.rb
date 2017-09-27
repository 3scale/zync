Bugsnag.configure do |config|
  config.api_key = Rails.application.secrets.bugsnag_api_key
  config.debug = ENV['BUGSNAG_DEBUG'].presence
end
