# frozen_string_literal: true

class Integration::Keycloak < Integration
  store_accessor :configuration, %i[ endpoint ]

  belongs_to :model
  validates :endpoint, url: { allow_nil: true, no_local: true }

  def enabled?
    endpoint.present?
  end
end
