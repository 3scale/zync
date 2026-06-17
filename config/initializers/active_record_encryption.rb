# frozen_string_literal: true

encryption_config = Rails.application.config.active_record.encryption
key_gen = Rails.application.key_generator

encryption_config.primary_key = key_gen.generate_key("active_record_encryption/primary_key", 32)
encryption_config.key_derivation_salt = key_gen.generate_key("active_record_encryption/key_derivation_salt", 32)

# Allow reading plaintext data written before encryption was enabled.
encryption_config.support_unencrypted_data = true
