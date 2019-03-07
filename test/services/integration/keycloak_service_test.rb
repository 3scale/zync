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

  test 'client auth flows attributes' do
    entry = entries(:client)

    stub_request(:put, "http://example.com/clients-registrations/default/two_id").
      with(
        body: {
            name: "client name", description: "client description",
            clientId: "two_id", secret: "two_secret",
            redirectUris: ["http://example.com"], attributes: {'3scale' => true},
            enabled: true,
            standardFlowEnabled: true, implicitFlowEnabled: true,
            serviceAccountsEnabled: true, directAccessGrantsEnabled: true,
        }.to_json,
      ).to_return(status: 200)

    subject.tap do |service|
      service.adapter.access_token = 'foobar'
      service.call(entry)
    end
  end

  protected

  def subject
    Integration::KeycloakService.new(integrations(:keycloak))
  end
end
