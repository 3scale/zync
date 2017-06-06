# This is action that is performed on incoming notificaiton.
# Its purpose is to wrap the persistence and triggering update logic.

class IncomingNotificationService
  def initialize
    freeze
  end

  # Wrapper extracting information from incoming notification.
  class NotificationData
    def initialize(data)
      @data = ActiveSupport::HashWithIndifferentAccess.new(data)
    end

    def type
      # FIXME: do this safely
      @data.fetch(:type).constantize
    end

    def to_hash
      @data.except(:type, :tenant_id)
    end
  end
  private_constant :NotificationData

  def extract_model(notification)
    data = NotificationData.new(notification.try(:data))

    tenant = notification.tenant

    type = data.type.find_or_create_by!(data.to_hash.merge(tenant: tenant))

    Model.find_or_create_by!(record: type, tenant: tenant)
  end

  def call(notification)
    notification.transaction do
      model = notification.model ||= extract_model(notification)

      notification.save!

      UpdateJob.perform_later(model)

      model
    end
  end
end
