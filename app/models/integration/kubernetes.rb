# frozen_string_literal: true

# Generic HTTP adapter for implementing custom integrations.
class Integration::Kubernetes < Integration
  store_accessor :configuration, %i[ server ]

  validates :server, url: { allow_nil: true, no_local: true }

  def enabled?
    super && K8s::Client === K8s::Client.autoconfig
  rescue K8s::Error::Configuration
    false
  rescue => error
    Bugsnag.notify(error)
    false
  end
end
