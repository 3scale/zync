# frozen_string_literal: true
require 'test_helper'

class RESTAdapterTest < ActiveSupport::TestCase
  class_attribute :subject, default: RESTAdapter

  test 'oidc discovery' do
    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    assert_nil subject.new('https://example.com').authentication
  end

  test 'create client with OAuth auth' do
    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 200, body: { token_endpoint: 'http://auth.example.com/oauth/token' }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "http://auth.example.com/oauth/token").
      with(
        body: { client_id: "id", client_secret: 'secret', grant_type: "client_credentials" },
        headers: { 'Content-Type'=>'application/x-www-form-urlencoded' }).
      to_return(status: 200, body: "access_token=token-value", headers: { 'Content-Type'=>'application/x-www-form-urlencoded' })

    client = RESTAdapter::Client.new(id: 'foo')
    stub_request(:put, "https://example.com/clients/foo").
      with(
        body: client.to_json,
        headers: { 'Content-Type'=>'application/json', 'Authorization' => 'Bearer token-value' }).
      to_return(status: 200, body: { status: 'ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    assert subject.new('https://id:secret@example.com').create_client(client)
  end

  test 'create client without auth' do
    client = RESTAdapter::Client.new(id: 'foo')

    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    stub_request(:put, "https://example.com/clients/foo").
      with(
        body: client.to_json,
        headers: { 'Content-Type'=>'application/json' }).
      to_return(status: 200, body: { status: 'ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    assert subject.new('https://example.com').create_client(client)
  end

  test 'oauth flows with token exchange' do
    client = RESTAdapter::Client.new(
      id: 'foo',
      oidc_configuration: {
        standard_flow_enabled: true,
        token_exchange_enabled: true,
      }
    )
    grant_types = JSON.parse(client.to_json).fetch('grant_types')
    assert_includes grant_types, 'authorization_code'
    assert_includes grant_types, 'urn:ietf:params:oauth:grant-type:token-exchange'
  end

  test 'oauth flows without token exchange' do
    client = RESTAdapter::Client.new(
      id: 'foo',
      oidc_configuration: {
        standard_flow_enabled: true,
        token_exchange_enabled: false,
      }
    )
    grant_types = JSON.parse(client.to_json).fetch('grant_types')
    assert_includes grant_types, 'authorization_code'
    refute_includes grant_types, 'urn:ietf:params:oauth:grant-type:token-exchange'
  end

  test 'create client with basic auth' do
    client = RESTAdapter::Client.new(id: 'foo')
    adapter = subject.new('https://user:pass@example.com')
    # WebMock does not support request retries on 401 status
    adapter.send(:http_client).force_basic_auth = true

    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    stub_request(:put, 'https://example.com/clients/foo').
      with(
        basic_auth: %w[user pass],
        body: client.to_json,
        headers: { 'Content-Type'=>'application/json' }).
      to_return(status: 200, body: { status: 'ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

    assert adapter.create_client(client)
  end
end
