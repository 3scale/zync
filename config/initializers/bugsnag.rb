Bugsnag.configure do |config|
  config.api_key = Rails.configuration.x.tools.bugsnag[:api_key]
  config.release_stage = Rails.configuration.x.tools.bugsnag[:release_stage].presence || Rails.env
end
