# frozen_string_literal: true
require 'test_helper'

class IncomingNotificationServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @service = IncomingNotificationService.new
  end

  test 'call with new notification' do
    notification = notifications(:one).clone

    assert_enqueued_jobs 1, only: UpdateJob do
      assert @service.call(notification)
    end
  end

  test 'call with existing notification' do
    notification = notifications(:one)

    assert_enqueued_with(job: UpdateJob, args: [ notification.model ]) do
      assert @service.call(notification)
    end
  end

  test 'call twice with the same model' do
    n1 = Notification.new(data: { id: 1, type: 'Application', service_id: services(:one).id }, tenant: tenants(:one))
    n2 = n1.dup

    assert @service.call(n1)
    assert @service.call(n2)
  end

  class LockingTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    teardown do
      ::Que.clear!
      ActiveRecord::Base.connection_pool.disconnect!
    end

    def test_process_locked_model
      notification = notifications(:two)

      fiber = Fiber.new do
        first = Model.connection_pool.checkout
        first.transaction(requires_new: true) do
          first.execute('SET SESSION statement_timeout TO 100;')

          second = Model.connection_pool.checkout
          second.transaction(requires_new: true) do
            second.execute('SET SESSION statement_timeout TO 100;')
            model = Model.find(notification.model_id)

            UpdateState.acquire_lock(model) do |state|
              model.touch
              Fiber.yield state
            end
          end
        end
      end

      assert_kind_of UpdateState, fiber.resume

      UpdateJob.stub(:perform_later, nil) do
        assert IncomingNotificationService.call(notification.dup)
      end
    ensure
      assert_nil fiber.resume
    end
  end
end
