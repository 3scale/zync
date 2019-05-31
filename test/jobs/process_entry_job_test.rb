# frozen_string_literal: true
require 'test_helper'

class ProcessEntryJobTest < ActiveJob::TestCase
  test 'perform' do
    entry = entries(:application)

    assert_enqueued_with job: ProcessIntegrationEntryJob,
                         args: [  integrations(:one),  entry.model ] do
      ProcessEntryJob.perform_now(entry)
    end
  end

  test 'model integrations for proxy' do
    job = ProcessEntryJob.new
    proxy = entries(:proxy)

    integrations = job.model_integrations_for(proxy)

    assert_equal 0, integrations.size
  end

  test 'model integrations for client' do
    job = ProcessEntryJob.new
    proxy = entries(:client)

    integrations = job.model_integrations_for(proxy)

    assert_equal 1, integrations.size
  end

  test 'model integrations for proxy without type' do
    job = ProcessEntryJob.new

    entry = entries(:proxy)
    entry.data = entry.data.except(:oidc_issuer_type)

    Integration::Keycloak.delete_all

    assert_difference Integration::Keycloak.method(:count) do
      job.model_integrations_for(entry)
    end
  end

  test 'creates keycloak integration for Proxy' do
    proxy = entries(:proxy)

    integration = Integration::Keycloak.where(tenant: proxy.tenant, model: models(:service))
    integration.delete_all

    assert_difference integration.method(:count) do
      assert ProcessEntryJob.perform_now(proxy)
    end
  end

  test 'skips deleted proxy' do
    proxy = entries(:proxy)

    proxy.data = nil

    ProcessEntryJob.perform_now(proxy)
  end
end
