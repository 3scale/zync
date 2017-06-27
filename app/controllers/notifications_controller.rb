# frozen_string_literal: true
class NotificationsController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  def update
    respond_with IncomingNotificationService.new.call(build_notification), status: :created
  end

  protected

  def invalid_record(error)
    respond_with error.record
  end

  def build_notification
    Notification.new(data: params, tenant: find_tenant)
  end

  def find_tenant
    Tenant.find(params.require(:tenant_id))
  end
end
