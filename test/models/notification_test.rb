# frozen_string_literal: true
require 'test_helper'

class NotificationTest < ActiveSupport::TestCase
  test 'create model Service' do
    notification = Notification.new(tenant: tenants(:one),
                                    data: { type: 'Service' })

    notification.create_model
  end

  test 'create model Unknown' do
    notification = Notification.new(tenant: tenants(:one),
                                    data: { type: 'Unknown' })

    assert_raises ActiveRecord::RecordInvalid do
      notification.create_model
    end
  end
end
