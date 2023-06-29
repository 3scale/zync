# frozen_string_literal: true
require 'test_helper'

class TenantsControllerTest < ActionDispatch::IntegrationTest
  test 'creating tenant' do
    assert_difference Tenant.method(:count) do
      put tenant_url, params: { id: 16, endpoint: 'http://example.com:3000', access_token: 'sometoken' }, as: :json
      assert_response :created
    end

    assert tenant = Tenant.find(16)
    assert_equal 'http://example.com:3000', tenant.endpoint
    assert_equal 'sometoken', tenant.access_token
  end

  test 'updating tenant' do
    tenant = tenants(:one)

    assert_no_difference Tenant.method(:count) do
      put tenant_url, params: { id: tenant.id, endpoint: 'http://example.com:3000', access_token: 'sometoken' }, as: :json
      assert_response :no_content
    end

    assert tenant.reload
    assert_equal 'http://example.com:3000', tenant.endpoint
    assert_equal 'sometoken', tenant.access_token
  end

  test 'conflict' do
    Tenant.stub(:upsert, ->(_f) { raise ActiveRecord::RecordNotUnique }) do
      put tenant_url, params: { id: tenants(:one).id }, as: :json
      assert_response :conflict
    end
  end
end
