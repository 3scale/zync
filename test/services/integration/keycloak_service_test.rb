# frozen_string_literal: true

require 'test_helper'

class Integration::KeycloakServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
  end

  def test_new
    assert Integration::KeycloakService.new(integrations(:keycloak))
  end

  test 'creating client' do
    Client.delete_all

    assert_difference Client.method(:count) do
      subject.call(entries(:application))
    end
  end

  test 'using existing client' do
    assert_no_difference Client.method(:count) do
      subject.call(entries(:application))
    end
  end

  test 'schedules UpdateJob when creating Client' do
    entry = entries(:application)
    model = subject.call(entry)

    assert_enqueued_with job: UpdateJob,
                         args: [ model ] do
      subject.call(entry)
    end
  end

  test 'client create sends audience mapper' do
    entry = entries(:client)

    audience_mapper = [{ name: 'audience-mapper', protocol: 'openid-connect', protocolMapper: 'oidc-audience-mapper', config: { 'included.client.audience' => 'two_id', 'id.token.claim' => 'false', 'access.token.claim' => 'true' } }]

    stub_request(:put, "http://example.com/clients-registrations/default/two_id").
      to_return(status: 404)

    create_stub = stub_request(:post, "http://example.com/clients-registrations/default").
      with(
        body: {
            name: "client name", description: "client description",
            clientId: "two_id", secret: "two_secret",
            redirectUris: ["http://example.com"], attributes: {'3scale' => true},
            enabled: true,
            protocolMappers: audience_mapper,
            standardFlowEnabled: true, implicitFlowEnabled: true,
            serviceAccountsEnabled: true, directAccessGrantsEnabled: true,
        }.to_json,
      ).to_return(status: 200, body: { clientId: 'two_id' }.to_json,
                  headers: { 'Content-Type' => 'application/json' })

    subject.tap do |service|
      service.adapter.authentication = 'foobar'
      service.call(entry)
    end

    assert_requested create_stub
  end

  test 'client update sends audience mapper' do
    entry = entries(:client)

    audience_mapper = [{ name: 'audience-mapper', protocol: 'openid-connect', protocolMapper: 'oidc-audience-mapper', config: { 'included.client.audience' => 'two_id', 'id.token.claim' => 'false', 'access.token.claim' => 'true' } }]

    update_stub = stub_request(:put, "http://example.com/clients-registrations/default/two_id").
      with(
        body: {
            name: "client name", description: "client description",
            clientId: "two_id", secret: "two_secret",
            redirectUris: ["http://example.com"], attributes: {'3scale' => true},
            enabled: true,
            protocolMappers: audience_mapper,
            standardFlowEnabled: true, implicitFlowEnabled: true,
            serviceAccountsEnabled: true, directAccessGrantsEnabled: true,
        }.to_json,
      ).to_return(status: 200)

    subject.tap do |service|
      service.adapter.authentication = 'foobar'
      service.call(entry)
    end

    assert_requested update_stub
  end

  protected

  def subject
    Integration::KeycloakService.new(integrations(:keycloak))
  end
end
