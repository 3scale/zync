# frozen_string_literal: true
require 'test_helper'

class KeycloakAdapterTest < ActiveSupport::TestCase
  test 'new' do
    assert KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    keycloak = KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, keycloak.endpoint
  end

  test 'setting access token' do
    subject = KeycloakAdapter.new('http://lvh.me:3000')

    subject.authentication = 'sometoken'

    assert_equal 'sometoken', subject.authentication
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end

  test 'timeout error' do
    stub_request(:get, 'http://lvh.me:3000/auth/realm/name/.well-known/openid-configuration').
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                  body: { token_endpoint: 'protocol/openid-connect/token' }.to_json)

    stub_request(:post, 'http://lvh.me:3000/auth/realm/name/protocol/openid-connect/token').to_timeout

    keycloak = KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')

    begin
      keycloak.test
    rescue KeycloakAdapter::OIDC::AuthenticationError => error
      assert_kind_of Faraday::TimeoutError, error.cause
      assert error.bugsnag_meta_data.presence
    end
  end

  test 'test' do
    keycloak = KeycloakAdapter.new('http://id:secret@example.com/auth/realm/name')

    form_urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' }
    token = stub_request(:post, 'http://example.com/auth/realm/name/get-token').
        with(
            body: {'client_id' => 'id', 'client_secret' => 'secret', 'grant_type' => 'client_credentials'},
            headers: form_urlencoded).
        to_return(status: 200, body: 'access_token=foo', headers: form_urlencoded)
    well_known = stub_request(:get, "http://example.com/auth/realm/name/.well-known/openid-configuration").
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: { token_endpoint: 'get-token' }.to_json)

    keycloak.test

    assert_requested token
    assert_requested well_known, times: 2 # first to get the discovery and then the actual test call
  end

  test 'invalid response error' do
    stub_request(:get, 'http://lvh.me:3000/auth/realm/name/.well-known/openid-configuration').
        to_return(status: 200, body: 'somebody', headers: {'Content-Type' => 'text/plain'} )

    keycloak = KeycloakAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name', authentication: 'something')

    assert_raises KeycloakAdapter::InvalidResponseError do
      keycloak.test
    end
  end

  test 'using configuration' do
    config = {
        attributes: {
            serviceAccountsEnabled: true
        }
    }.deep_stringify_keys

    Rails.application.config.x.stub(:keycloak, config) do
      client = KeycloakAdapter::Client.new(name: 'foo')

      assert_includes client.to_h, :serviceAccountsEnabled
    end
  end

  test 'client hash' do
    client = KeycloakAdapter::Client.new(name: 'name')

    assert_includes client.to_h, :name
  end

  test 'client serialization' do
    client = KeycloakAdapter::Client.new(name: 'name')

    assert_equal client.to_h.to_json, client.to_json
  end

  test 'oauth flows' do
    keycloak = { clientId: "client_id", implicitFlowEnabled: true, serviceAccountsEnabled: true }

    assert_equal keycloak, KeycloakAdapter::Client.new({
                                                    id: 'client_id',
                                                    oidc_configuration: {
                                                        implicit_flow_enabled: true,
                                                        service_accounts_enabled: true,
                                                    }
                                                }).to_h.slice(*keycloak.keys)
  end
end
