class Integration::Keycloak < Integration
  store_accessor :configuration, %i[ endpoint ]
end
