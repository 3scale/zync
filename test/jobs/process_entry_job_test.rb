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

    ProcessEntryJob::CreateK8SIntegration.stub(:enabled, true) do
      integrations = job.model_integrations_for(proxy)

      integrations.each do |integration|
        assert_kind_of Integration::Kubernetes, integration
      end

      assert_equal 1, integrations.size
    end
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

  class CreateProxyIntegrationWithFiber < ProcessEntryJob::CreateOIDCProxyIntegration
    def find_integration
      Fiber.yield
      super
    end
  end

  class ProcessEntryJobWithFiber < ProcessEntryJob
    self.proxy_integration_services = [CreateProxyIntegrationWithFiber]
  end

  test 'race condition between entry jobs to create same proxy integration' do
    entry = entries(:proxy)

    existing_integrations = Integration.where(tenant: entry.tenant)
    UpdateState.where(model: existing_integrations).delete_all
    existing_integrations.destroy_all

    fiber1 = Fiber.new { ProcessEntryJobWithFiber.ensure_integrations_for(entry) }
    fiber2 = Fiber.new { ProcessEntryJobWithFiber.ensure_integrations_for(entry) }

    fiber1.resume
    fiber2.resume

    assert_difference(existing_integrations.method(:count)) do
      fiber2.resume # creates the integration first
    end

    assert_no_difference(existing_integrations.method(:count)) do
      fiber1.resume
    end
  end

  test 'skips deleted proxy' do
    proxy = entries(:proxy)

    proxy.data = nil

    ProcessEntryJob.perform_now(proxy)
  end
end
