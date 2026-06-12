# frozen_string_literal: true

encryption_config = Rails.application.config.active_record.encryption

# Supports key rotation via comma-separated keys: the last key encrypts,
# all keys decrypt. To rotate: set "oldkey,newkey", re-encrypt rows, then
# remove the old key.
encryption_config.primary_key = ENV["ZYNC_DATABASE_ENCRYPT_KEY"]&.split(",")
encryption_config.key_derivation_salt = ENV["ZYNC_DATABASE_ENCRYPT_SALT"]

# Allow reading plaintext data written before encryption was enabled.
encryption_config.support_unencrypted_data = true
