# frozen_string_literal: true
require 'test_helper'

class KeycloakTest < ActiveSupport::TestCase
  test 'new' do
    assert Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, keycloak.endpoint
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end

  test 'timeout error' do
    stub_request(:post, 'http://lvh.me:3000/auth/realm/name/protocol/openid-connect/token').to_timeout

    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')

    begin
      keycloak.test
    rescue Keycloak::AuthenticationError => error
      assert_kind_of Faraday::TimeoutError, error.cause
      assert error.bugsnag_meta_data.presence
    end
  end
end
