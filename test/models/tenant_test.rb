# frozen_string_literal: true

require 'test_helper'

class TenantTest < ActiveSupport::TestCase
  test "access_token is encrypted at rest" do
    tenant = Tenant.create!(endpoint: "http://test.example.com", access_token: "my-secret-token")
    tenant.reload

    assert_equal "my-secret-token", tenant.access_token
    assert_not_equal "my-secret-token", tenant.access_token_before_type_cast
    assert tenant.encrypted_attribute?(:access_token)
  end

  test "existing plaintext access_token is readable" do
    # Fixtures bypass AR Encryption (encrypt_fixtures defaults to false),
    # so fixture values are stored as plaintext in the database.
    tenant = tenants(:one)
    assert_equal "one-token", tenant.access_token
    assert_not tenant.encrypted_attribute?(:access_token)
  end
end
