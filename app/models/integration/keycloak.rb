class Integration::Keycloak < Integration
  store :configuration, accessors: %i[ endpoint ]
end
