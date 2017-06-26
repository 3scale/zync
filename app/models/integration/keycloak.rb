# frozen_string_literal: true

class Integration::Keycloak < Integration
  store_accessor :configuration, %i[ endpoint ]

  belongs_to :model
  validates :endpoint, presence: true
end
