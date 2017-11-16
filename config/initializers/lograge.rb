if Rails.application.config.lograge.enabled
  ActiveSupport.on_load :active_job do
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
      when ActiveJob::Logging::LogSubscriber
        Lograge.unsubscribe(:active_job, subscriber)
      end
    end

    require 'lograge/job_log_subscriber'
    Lograge::JobLogSubscriber.attach_to :active_job

    # do not try to tag log entries
    ActiveJob::Base.prepend(Lograge::JobLogSubscriber::Logging)
  end

  require 'lograge/oidc_subscriber'
  Lograge::OIDCSubscriber.attach_to :oidc

  require 'lograge/http_subscriber'
  Lograge::HTTPSubscriber.attach_to :three_scale_api_client

  require 'lograge/net_http_subscriber'
  Lograge::NetHttpSubscriber.attach_to :net_http
end
