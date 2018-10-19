# frozen_string_literal: true
class Model < ApplicationRecord
  belongs_to :tenant
  belongs_to :record, polymorphic: true

  has_many :entries

  def for_integration
    record.try(:integration_model) || self
  end

  # Error raised when weak lock can't be acquired.
  class LockTimeoutError < StandardError; end

  def self.create_record!(tenant)
    retry_record_not_unique do
      record = yield

      self.find_or_create_by!(record: record, tenant: tenant)
    end
  end

  def weak_lock
    lock!('FOR NO KEY UPDATE NOWAIT')
  rescue ActiveRecord::StatementInvalid => error
    case error.cause
      when ::PG::QueryCanceled, ::PG::LockNotAvailable
        raise LockTimeoutError
      else
        raise error
    end
  end
end
