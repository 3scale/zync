# frozen_string_literal: true
require 'test_helper'

class DataModelTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def teardown
    assert_not_outstanding_requests
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
          to_return(body: { oidc_issuer_endpoint: oidc_issuer_endpoint }.to_json)

      oidc_issuer_endpoint.userinfo = ''
      stub_request(:post, "#{oidc_issuer_endpoint}/protocol/openid-connect/token").
          with(
              body: {"client_id"=>"foo", "client_secret"=>"bar", "grant_type"=>"client_credentials"},
              headers: (urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' })).
          to_return(status: 200, body: "access_token=token", headers: urlencoded)

      stub_request(:get, "#{oidc_issuer_endpoint}/.well-known/openid-configuration").
          to_return(status: 200)

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
        to_return(body: client.to_json).then.
        to_return(body: client.merge(name: 'new-name').to_json).then.
        to_return(status: 404)

    perform_enqueued_jobs do
      stub_request(:put, "http://example.com/auth/realm/master/clients-registrations/default/foo").
          with(
              body: '{"name":null,"description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}',
              headers: {
                  'Authorization'=>'Bearer token',
                  'Content-Type'=>'application/json',
              }).
          to_return(status: 200)

      stub_request(:put, "http://example.com/auth/realm/master/clients-registrations/default/foo").
          with(
              body: '{"name":"new-name","description":null,"clientId":"foo","secret":"bar","redirectUris":[],"attributes":{"3scale":true},"enabled":null}',
              headers: {
                  'Authorization'=>'Bearer token',
                  'Content-Type'=>'application/json',
              }).
          to_return(status: 200)

      stub_request(:delete, "http://example.com/auth/realm/master/clients-registrations/default/foo").
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

  protected

  # Backported https://github.com/rails/rails/commit/ec1630148853c46a1e3b35cd48bf85aa0e049d81
  # Can be removed on Rails 6.0

  def flush_enqueued_jobs(only: nil, except: nil)
    enqueued_jobs_with(only: only, except: except) do |payload|
      args = ActiveJob::Arguments.deserialize(payload[:args])
      instantiate_job(payload.merge(args: args)).perform_now
      queue_adapter.performed_jobs << payload
    end
  end

  def enqueued_jobs_with(only: nil, except: nil, queue: nil)
    validate_option(only: only, except: except)

    enqueued_jobs.count do |job|
      job_class = job.fetch(:job)

      if only
        next false unless Array(only).include?(job_class)
      elsif except
        next false if Array(except).include?(job_class)
      end
      if queue
        next false unless queue.to_s == job.fetch(:queue, job_class.queue_name)
      end

      yield job if block_given?
      true
    end
  end
end
