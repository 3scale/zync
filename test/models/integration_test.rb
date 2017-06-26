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
end
