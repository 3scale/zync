# frozen_string_literal: true
require 'test_helper'

class IntegrationTest < ActiveSupport::TestCase
  test 'tenant_or_model' do
    tenant = tenants(:one)
    model = models(:service)

    one = integrations(:one)
    keycloak = integrations(:keycloak)

    assert_equal [ one, keycloak], Integration.tenant_or_model(tenant, model)
    assert_equal [ keycloak ], Integration.tenant_or_model(nil, model)
    assert_equal [ one ], Integration.tenant_or_model(tenant, nil)
  end

  test 'enabled is by integration' do
    with_integration keycloak: false, rest: true, kubernetes: true do
      assert Integration.new.enabled?
      refute Integration::Keycloak.new.enabled?
    end
  end

  test 'rest enabled?' do
    integration = Integration::REST.new
    integration.endpoint = 'https://rest.example.com/endpoint'
    assert integration.enabled?

    integration.endpoint = nil
    refute integration.enabled?

    with_integration rest: false do
      integration = Integration::REST.new
      integration.endpoint = 'https://rest.example.com/endpoint'
      refute integration.enabled?
  
      integration.endpoint = nil
      refute integration.enabled?
    end
  end

  test 'kubernetes enabled?' do
    client = K8s::Client.new(nil)
    integration = Integration::Kubernetes.new

    K8s::Client.stub(:autoconfig, client) do
      assert integration.enabled?

      with_integration kubernetes: false do
        refute integration.enabled?
      end
    end

    K8s::Client.stub(:autoconfig, nil) do
      refute integration.enabled?
    end

    with_integration kubernetes: false do
      refute integration.enabled?
    end
  end

  protected

  def with_integration(opts = {}, &block)
    Rails.application.config.stub(:integrations, opts.with_indifferent_access, &block)
  end
end
