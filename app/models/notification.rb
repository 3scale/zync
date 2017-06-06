# Incoming notification from 3scale. Has data about what model was modified.

class Notification < ApplicationRecord
  belongs_to :model
  belongs_to :tenant

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

  def create_model
    data = NotificationData.new(self.data)

    type = data.type.find_or_create_by!(data.to_hash.merge(tenant: tenant))

    Model.find_or_create_by!(record: type, tenant: tenant)
  end

end
