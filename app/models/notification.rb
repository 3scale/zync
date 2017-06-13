# frozen_string_literal: true
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
    retry_record_not_unique do
      data = NotificationData.new(self.data)

      type = data.type.lock.find_or_create_by!(data.to_hash.merge(tenant: tenant))

      Model.lock.find_or_create_by!(record: type, tenant: tenant)
    end
  end
end
