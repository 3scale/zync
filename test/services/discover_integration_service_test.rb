# frozen_string_literal: true
require 'test_helper'

class DiscoverIntegrationServiceTest < ActiveSupport::TestCase
  def setup
    @service = DiscoverIntegrationService.new
  end

  class FakeIntegration
    def enabled?
      true
    end
  end

  def test_call
    assert_kind_of Integration::EchoService, @service.call(FakeIntegration.new)
    assert_kind_of Integration::KeycloakService, @service.call(integrations(:keycloak))
    assert_kind_of Integration::GenericService, @service.call(integrations(:generic))
  end

  def test_disabled
    assert_equal DiscoverIntegrationService::DISABLED,
                 @service.call(Integration::Keycloak.new)
  end
end
