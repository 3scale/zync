# frozen_string_literal: true
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.retry_record_not_unique
    retried = false

    begin
      transaction(requires_new: true) do
        yield
      end
    rescue ActiveRecord::RecordNotUnique => error
      logger.warn(error) { "[#{self}][#``{error.class}] Retrying after #{error}" }

      unless retried
        retried = true
        retry
      end
    end
  end

  delegate :retry_record_not_unique, to: :class
end
