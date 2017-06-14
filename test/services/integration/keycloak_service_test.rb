require 'test_helper'

class Integration::KeycloakServiceTest < ActiveSupport::TestCase
  def setup
  end

  def test_new
    assert Integration::KeycloakService.new(integrations(:keycloak))
  end
end
