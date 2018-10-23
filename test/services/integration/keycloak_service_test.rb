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

  protected

  def subject
    Integration::KeycloakService.new(integrations(:keycloak))
  end
end
