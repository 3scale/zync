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
    integration = FakeIntegration.new
    assert_kind_of Integration::EchoService, @service.call(integration)
  end

  def test_disabled
    assert_equal DiscoverIntegrationService::DISABLED,
                 @service.call(Integration::Keycloak.new)
  end
end
