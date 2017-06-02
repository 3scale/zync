require 'test_helper'

class DataModelTest < ActionDispatch::IntegrationTest
  test 'incoming notification creates service and model' do
    data = { tenant_id: 16, type: 'Service', id: 26 }
    notification = Notification.new(data: data, tenant: tenants(:one))

    incoming = IncomingNotificationService.new

    assert_difference Notification.method(:count) do
      assert_difference Model.method(:count) do
        assert_difference Service.method(:count) do
          assert model = incoming.call(notification)
          assert_predicate model, :persisted?

          assert record = model.record
          assert_predicate record, :persisted?
        end
      end
    end

    assert_predicate notification, :persisted?
  end
end
