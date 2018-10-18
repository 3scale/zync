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
    NULL_TYPE = Object.new.tap do |object|
      def object.find_or_create_by!(*); end
      def object.attribute_names; end

      object.freeze
    end

    def type
      type = @data.fetch(:type)

      ALLOWED_MODELS.include?(type) ? type.constantize : NULL_TYPE
    end

    def to_hash
      @data.slice(*type.attribute_names)
    end
  end
  private_constant :NotificationData

  def create_model
    data = NotificationData.new(self.data)
    type = data.type
    attributes = data.to_hash.merge(tenant: tenant)

    retry_record_not_unique do
      record = type.find_or_create_by!(attributes)

      Model.find_or_create_by!(record: record, tenant: tenant)
    end
  end
end
