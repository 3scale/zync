# frozen_string_literal: true
# This is action that is performed on incoming notificaiton.
# Its purpose is to wrap the persistence and triggering update logic.

class IncomingNotificationService
  def initialize
    freeze
  end

  def call(notification)
    notification.transaction do
      model = notification.model ||= notification.create_model

      notification.save!

      UpdateJob.perform_later(model)

      model
    end
  end
end
