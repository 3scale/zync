# frozen_string_literal: true
# Returns a Service for each Integration.
# Each Integration can be using different Service.
# This class creates a mapping between Integration and Service.

class DiscoverIntegrationService
  def initialize
    freeze
  end

  class << self
    delegate :call, to: :new
  end

  def call(integration)
    klass = case integration
            when Integration::Keycloak
              Integration::KeycloakService
            when integration
              Integration::EchoService
            else # the only one for now
              raise NotImplementedError
            end

    klass.new(integration)
  end
end
