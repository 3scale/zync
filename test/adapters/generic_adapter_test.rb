# frozen_string_literal: true
require 'test_helper'

class GenericAdapterTest < ActiveSupport::TestCase
  test 'new' do
    assert GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    adapter = GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, adapter.endpoint
  end

  test 'setting access token' do
    subject = GenericAdapter.new('http://lvh.me:3000')

    subject.authentication = 'sometoken'

    assert_equal 'sometoken', subject.authentication
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end

  test 'timeout error' do
    stub_request(:get, 'http://lvh.me:3000/auth/realm/name/.well-known/openid-configuration').
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                  body: { token_endpoint: 'protocol/openid-connect/token' }.to_json)

    get_token = stub_request(:post, 'http://lvh.me:3000/auth/realm/name/protocol/openid-connect/token').to_timeout

    adapter = GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name')

    log = Object.new
    class << log
      def error_object
        @error
      end

      def error(object)
        @error = object
      end
    end

    Rails.logger.stub :error, log.method(:error) do
      adapter.test
    end

    error = log.error_object
    assert_kind_of Faraday::TimeoutError, error.cause
    assert error.bugsnag_meta_data.presence
    assert_requested get_token
  end

  test 'create client' do
    adapter = GenericAdapter.new('http://example.com/adapter', authentication: 'token')
    client = GenericAdapter::Client.new(name: 'Foo', id: 'foo', secret: 'bar')

    create = stub_request(:put, "http://example.com/adapter/clients/foo").
        with(
            body: '{"client_id":"foo","client_secret":"bar","client_name":"Foo","redirect_uris":[],"grant_types":[]}'
        ).to_return(status: 200)

    adapter.create_client(client)

    assert_requested create
  end

  test 'update client' do
    adapter = GenericAdapter.new('http://example.com/adapter', authentication: 'token')
    client = GenericAdapter::Client.new(name: 'Foo', id: 'foo', secret: 'bar')

    update = stub_request(:put, "http://example.com/adapter/clients/foo").
        with(
            body: '{"client_id":"foo","client_secret":"bar","client_name":"Foo","redirect_uris":[],"grant_types":[]}'
        ).to_return(status: 200)

    adapter.update_client(client)

    assert_requested update
  end

  test 'delete client' do
    adapter = GenericAdapter.new('http://example.com/adapter', authentication: 'token')
    client = GenericAdapter::Client.new(id: 'foo')

    delete = stub_request(:delete, "http://example.com/adapter/clients/foo").to_return(status: 200)

    adapter.delete_client(client)

    assert_requested delete
  end

  test 'read client' do
    adapter = GenericAdapter.new('http://example.com/adapter', authentication: 'token')
    client = GenericAdapter::Client.new(id: 'foo')

    body = { client_id: 'foo', client_name: 'Foo'}
    read = stub_request(:get, "http://example.com/adapter/clients/foo")
               .to_return(status: 200, body: body.to_json,
                          headers: { 'Content-Type' => 'application/json' })

    client = adapter.read_client(client)

    assert_kind_of GenericAdapter::Client, client
    assert_equal 'Foo', client.name
    assert_equal 'foo', client.id

    assert_requested read
  end

  test 'test' do
    adapter = GenericAdapter.new('http://id:secret@example.com/auth/realm/name')

    form_urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' }
    token = stub_request(:post, 'http://example.com/auth/realm/name/get-token').
        with(
            body: {'client_id' => 'id', 'client_secret' => 'secret', 'grant_type' => 'client_credentials'},
            headers: form_urlencoded).
        to_return(status: 200, body: 'access_token=foo', headers: form_urlencoded)
    well_known = stub_request(:get, "http://example.com/auth/realm/name/.well-known/openid-configuration").
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: { token_endpoint: 'get-token' }.to_json)

    adapter.test

    assert_requested token
    assert_requested well_known, times: 2 # first to get the discovery and then the actual test call
  end

  test 'invalid response error' do
    stub_request(:get, 'http://lvh.me:3000/auth/realm/name/.well-known/openid-configuration').
        to_return(status: 200, body: 'somebody', headers: {'Content-Type' => 'text/plain'} )

    adapter = GenericAdapter.new('http://id:secret@lvh.me:3000/auth/realm/name', authentication: 'something')

    assert_raises GenericAdapter::InvalidResponseError do
      adapter.test
    end
  end

  test 'using configuration' do
    config = {
        attributes: {
            grant_types: %i[client_credentials]
        }
    }.deep_stringify_keys

    Rails.application.config.x.stub(:generic, config) do
      client = GenericAdapter::Client.new(name: 'foo')

      assert_includes client.to_h.fetch(:grant_types), :client_credentials
    end
  end

  test 'client hash' do
    client = GenericAdapter::Client.new(name: 'name')

    assert_includes client.to_h, :client_name
  end

  test 'client serialization' do
    client = GenericAdapter::Client.new(name: 'name')

    assert_equal client.to_h.to_json, client.to_json
  end

  test 'oauth flows' do
    client = GenericAdapter::Client.new({
                                            id: 'client_id',
                                            oidc_configuration: {
                                                implicit_flow_enabled: true,
                                                service_accounts_enabled: true,
                                            }
                                        })
    assert_equal %w[implicit client_credentials], client.as_json.fetch('grant_types')
  end
end
