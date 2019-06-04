# frozen_string_literal: true

# Generic HTTP adapter for implementing custom integrations.
class Integration::Generic < Integration
  store_accessor :configuration, %i[ endpoint ]

  validates :endpoint, url: { allow_nil: true, no_local: true }

  def enabled?
    endpoint.present?
  end
end
