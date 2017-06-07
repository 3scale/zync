# frozen_string_literal: true
require 'test_helper'

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test 'update' do
    stub_request(:get, "#{tenants(:one).endpoint}/admin/api/applications/find.json?application_id=980190963").
      to_return(status: 200, body: '{}', headers: {})

    perform_enqueued_jobs do
      put notification_url(format: :json), params: { notification: { type: 'Application', tenant_id: tenants(:one).id } }
    end

    assert_response :success
  end
end
