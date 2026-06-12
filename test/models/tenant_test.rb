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

  test "key rotation allows decrypting with old key and encrypting with new key" do
    original_key = ENV["ZYNC_DATABASE_ENCRYPT_KEY"]

    tenant = Tenant.create!(endpoint: "http://rotation.example.com", access_token: "old-key-secret")
    assert_equal "old-key-secret", tenant.reload.access_token

    new_key = "new-key-for-rotation-test-value"
    ActiveRecord::Encryption.configure(
      primary_key: [original_key, new_key],
      key_derivation_salt: ENV["ZYNC_DATABASE_ENCRYPT_SALT"],
      support_unencrypted_data: true
    )

    assert_equal "old-key-secret", tenant.reload.access_token

    tenant.update!(access_token: "new-key-secret")
    tenant.reload

    assert_equal "new-key-secret", tenant.access_token
    assert_not_equal "new-key-secret", tenant.access_token_before_type_cast
  ensure
    ActiveRecord::Encryption.configure(
      primary_key: original_key,
      key_derivation_salt: ENV["ZYNC_DATABASE_ENCRYPT_SALT"],
      support_unencrypted_data: true
    )
  end
end