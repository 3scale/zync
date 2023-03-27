Bugsnag.configure do |config|
  config.api_key = Rails.application.secrets.bugsnag_api_key
  config.release_stage = ENV['BUGSNAG_RELEASE_STAGE'].presence || Rails.env
end
