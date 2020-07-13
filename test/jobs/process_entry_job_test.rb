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

  class ActiveRecordRelationWithFiber < ActiveRecord::Relation
    def find_by(*attributes)
      record = super
      Fiber.yield
      record
    end
  end

  class IntegrationWithFiber < ::Integration::REST
    def self.relation
      ActiveRecordRelationWithFiber.new(self)
    end
  end

  class CreateProxyIntegrationWithFiber < ProcessEntryJob::CreateOIDCProxyIntegration
    def model
      IntegrationWithFiber
    end
  end

  class ProcessEntryJobWithFiber < ProcessEntryJob
    PROXY_INTEGRATIONS = [CreateProxyIntegrationWithFiber]
  end

  test 'race condition between entry jobs to create same proxy integration' do
    entry = entries(:proxy)

    existing_integrations = Integration.where(tenant: entry.tenant)
    UpdateState.where(model: existing_integrations).delete_all
    existing_integrations.delete_all

    fiber1 = Fiber.new { ProcessEntryJobWithFiber.model_integrations_for(entry) }
    fiber2 = Fiber.new { ProcessEntryJobWithFiber.model_integrations_for(entry) }

    fiber1.resume
    fiber2.resume # right now, both jobs believe the integration must be created

    assert_difference(Integration.where(type: 'ProcessEntryJobTest::IntegrationWithFiber').method(:count)) do
      fiber2.resume # creates the integration first
    end

    old_logger = ::Integration.logger
    tmp_logger = Minitest::Mock.new(old_logger)
    ::Integration.logger = tmp_logger
    tmp_logger.expect(:warn, true) { |error| ActiveRecord::RecordNotUnique === error }

    fiber1.resume # raises ActiveRecord::RecordNotUnique
    ::Integration.logger = old_logger
  end

  test 'skips deleted proxy' do
    proxy = entries(:proxy)

    proxy.data = nil

    ProcessEntryJob.perform_now(proxy)
  end
end
