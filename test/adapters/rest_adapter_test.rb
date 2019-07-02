# frozen_string_literal: true
require 'test_helper'

class RESTAdapterTest < ActiveSupport::TestCase
  class_attribute :subject, default: RESTAdapter

  test 'oidc discovery' do
    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    assert_nil subject.new('https://example.com').authentication
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
