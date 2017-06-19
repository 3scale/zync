# frozen_string_literal: true

class Integration::Keycloak < Integration
  store_accessor :configuration, %i[ endpoint ]
end
