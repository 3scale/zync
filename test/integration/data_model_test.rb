# frozen_string_literal: true
require 'test_helper'

class DataModelTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def teardown
    assert_not_outstanding_requests
  ensure
    super
  end

  test 'incoming notification creates service and model' do
    data = { type: 'Service', id: 26 }
    notification = Notification.new(data: data, tenant: tenants(:one))

    incoming = IncomingNotificationService.new

    assert_difference Notification.method(:count) do
      assert_difference Model.method(:count) do
        assert_difference Service.method(:count) do
          perform_enqueued_jobs do
            assert model = incoming.call(notification)
            assert_predicate model, :persisted?

            assert record = model.record
            assert_predicate record, :persisted?
          end
        end
      end
    end

    assert_predicate notification, :persisted?
  end

  test 'the whole integration' do
    tenant = { id: 1, access_token: 'foobar', endpoint: 'http://example.com' }
    put tenant_url(format: :json), params: { tenant: tenant }
    assert_response :success

    http_fetch_headers = {
        'Accept'=>'application/json',
        'Authorization'=>'Basic OmZvb2Jhcg==',
        'Content-Type'=>'application/json',
    }

    oidc_issuer_endpoint = URI('http://foo:bar@example.com/auth/realm/master')

    perform_enqueued_jobs do
      assert_difference Service.method(:count) do
        put notification_url(format: :json),
            params: { type: 'Service', id: 1, tenant_id: 1 }
        assert_response :success
      end

      stub_request(:get, "#{tenant[:endpoint]}/admin/api/services/1/proxy.json").
          with(headers: http_fetch_headers).
          to_return(body: { oidc_issuer_endpoint: oidc_issuer_endpoint, oidc_issuer_type: 'keycloak' }.to_json)

      oidc_issuer_endpoint.userinfo = ''
      stub_request(:post, "#{oidc_issuer_endpoint}/protocol/oidc/token").
          with(
              body: {'client_id' => 'foo', 'client_secret' => 'bar', 'grant_type' => 'client_credentials'},
              headers: (urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' })).
          to_return(status: 200, body: 'access_token=token', headers: urlencoded)

      stub_request(:get, "#{oidc_issuer_endpoint}/.well-known/openid-configuration").
          to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                    body: { token_endpoint: 'protocol/oidc/token' }.to_json)

      assert_difference Integration.method(:count) do
        put notification_url(format: :json),
            params: { type: 'Proxy', id: 1, service_id: 1, tenant_id: 1 }
        assert_response :success
      end
    end

    put notification_url(format: :json),
        params: { type: 'Application', id: 1, service_id: 1, tenant_id: 1 }
    assert_response :success

    client = { client_id: 'foo', client_secret: 'bar' }
    find_application = stub_request(:get, "#{tenant[:endpoint]}/admin/api/applications/find.json?application_id=1").
        with(headers: http_fetch_headers).
        to_return(body: client.to_json)

    stub_request(:get, "http://example.com/admin/api/applications/find.json?app_id=foo").
        with(basic_auth: ['', tenant[:access_token]], headers: http_fetch_headers).
        to_return(body: client.to_json).then.
        to_return(body: client.merge(name: 'new-name').to_json).then.
        to_return(status: 404)

    perform_enqueued_jobs do
      stub_request(:put, 'http://example.com/auth/realm/master/clients-registrations/default/foo').
          with(
              body: '{"name":null,"description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}',
              headers: {
                  'Authorization'=>'Bearer token',
                  'Content-Type'=>'application/json',
              }).
          to_return(status: 200)

      stub_request(:put, 'http://example.com/auth/realm/master/clients-registrations/default/foo').
          with(
              body: '{"name":"new-name","description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}',
              headers: {
                  'Authorization'=>'Bearer token',
                  'Content-Type'=>'application/json',
              }).
          to_return(status: 200)

      stub_request(:delete, 'http://example.com/auth/realm/master/clients-registrations/default/foo').
          with(headers: { 'Authorization'=>'Bearer token' }).
          to_return(status: 200)

      3.times do
        put notification_url(format: :json),
            params: { type: 'Application', id: 1, service_id: 1, tenant_id: 1 }
        assert_response :success
      end

      assert_requested find_application, times: 3
    end
  end

  test 'recreating application in KeycloakAdapter with the same client id' do
    keycloak = integrations(:keycloak)
    service = keycloak.model.record
    tenant = keycloak.tenant

    json_request_headers = {
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
    }

    perform_enqueued_jobs do
      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?application_id=1").
          with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
          to_return(status: 200, body: { client_id: 'foo', client_secret: 'bar' }.to_json).
          then.to_return(status: 404)

      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?app_id=foo").
          with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
          to_return(status: 200, body: { client_id: 'foo', client_secret: 'bar' }.to_json)

      stub_oauth_access_token(keycloak)

      stub_request(:put, "http://example.com/clients-registrations/default/foo").
        with(body: '{"name":null,"description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}').
        to_return(status: 200)

      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?application_id=2").
          with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
          to_return(status: 200, body: { client_id: 'foo', client_secret: 'bar' }.to_json)

      put_notification(type: 'Application', id: 1, service_id: service.to_param, tenant_id: tenant.to_param)
      put_notification(type: 'Application', id: 2, service_id: service.to_param, tenant_id: tenant.to_param)
      put_notification(type: 'Application', id: 1, service_id: service.to_param, tenant_id: tenant.to_param)
    end
  end

  test 'deleting application integration' do
    keycloak = integrations(:keycloak)
    service = keycloak.model.record
    tenant = keycloak.tenant

    json_request_headers = {
      'Accept'=>'application/json',
      'Authorization'=>'Basic OmZvb2Jhcg==',
      'Content-Type'=>'application/json',
    }

    perform_enqueued_jobs do
      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?application_id=1").
        with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
        to_return(status: 200, body: { client_id: 'foo', client_secret: 'bar' }.to_json)

      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?app_id=foo").
        with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
        to_return(status: 200, body: { client_id: 'foo', client_secret: 'bar' }.to_json)

      stub_oauth_access_token(keycloak)

      stub_request(:put, "http://example.com/clients-registrations/default/foo").
        with(body: '{"name":null,"description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}').
        to_return(status: 200)

      put_notification(type: 'Application', id: 1, service_id: service.to_param, tenant_id: tenant.to_param)
      assert_response :success
    end

    perform_enqueued_jobs do
      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?application_id=1").
        with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
        to_return(status: 404)

      stub_request(:get, "#{tenant.endpoint}/admin/api/applications/find.json?app_id=foo").
        with(basic_auth: ['', tenant.access_token], headers: json_request_headers).
        to_return(status: 404)

      stub_request(:delete, "http://example.com/clients-registrations/default/foo").
        to_return(status: 200)

      put_notification(type: 'Application', id: 1, service_id: service.to_param, tenant_id: tenant.to_param)
      assert_response :success
    end
  end

  protected

  def put_notification(payload)
    put notification_url(format: :json), params: payload
    assert_response :success
  end

  def stub_oauth_access_token(integration, value: SecureRandom.hex)
    endpoint = URI(integration.endpoint)

    user = endpoint.user
    password = endpoint.password

    endpoint.userinfo = ''

    urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' }

    stub_request(:get, "#{endpoint}/.well-known/openid-configuration").
        to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                  body: { token_endpoint: 'protocol/oidc/token' }.to_json)


    stub_request(:post, "#{endpoint}/protocol/oidc/token").
        with(
            body: {'client_id' =>user, 'client_secret' =>password, 'grant_type' => 'client_credentials'},
            headers: urlencoded).
        to_return(status: 200, body: { access_token: value }.to_query, headers: urlencoded)
  end
end
