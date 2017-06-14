class Integration::KeycloakService
  attr_reader :integration

  def initialize(integration)
    @integration = integration
    @adapter = ::Keycloak.new(integration.endpoint)
    freeze
  end

  def call(entry)

  end
end
