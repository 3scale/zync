# frozen_string_literal: true

# REST HTTP adapter for implementing custom integrations.
class Integration::REST < Integration
  store_accessor :configuration, %i[ endpoint ]

  validates :endpoint, url: { allow_nil: true, no_local: true }

  def enabled?
    super && endpoint.present?
  end
end
