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
end
