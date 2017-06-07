class NotificationsController < ApplicationController
  wrap_parameters Notification, include: Notification.attribute_names + %i(type)

  def update
    respond_with IncomingNotificationService.new.call(build_notification), status: :created
  end

  protected

  def build_notification
    Notification.new(data: notification_params.except(:notification), tenant: find_tenant)
  end

  def notification_params
    params.require(:notification)
  end

  def find_tenant
    Tenant.find(notification_params.require(:tenant_id))
  end
end
