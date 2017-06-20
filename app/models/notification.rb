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

    ALLOWED_MODELS = Set.new(%w(Application Proxy Service)).freeze

    def type
      type = @data.fetch(:type)

      type.constantize if ALLOWED_MODELS.include?(type)
    end

    def to_hash
      @data.slice(*type&.attribute_names)
    end
  end
  private_constant :NotificationData

  def create_model
    retry_record_not_unique do
      data = NotificationData.new(self.data)

      type = data.type.find_or_create_by!(data.to_hash.merge(tenant: tenant))

      Model.find_or_create_by!(record: type, tenant: tenant)
    end
  end
end
