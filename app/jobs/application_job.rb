# frozen_string_literal: true

require 'que/active_record/model'

# Base class for all Jobs
class ApplicationJob < ActiveJob::Base
  # Copied from ActiveJob::Exceptions, but uses debug log level.
  # rubocop:disable Metrics/ParameterLists
  def self.retry_on(exception, wait: 3.seconds, attempts: 5, queue: nil, priority: nil, jitter: ActiveJob::Exceptions.const_get(:JITTER_DEFAULT))
    # rubocop:enable Metrics/ParameterLists
    rescue_from exception do |error|
      if executions < attempts
        logger.debug "Retrying #{self.class} in #{wait} seconds, due to a #{exception}. The original exception was #{error.cause.inspect}."
        retry_job wait: determine_delay(seconds_or_duration_or_algorithm: wait, executions: executions, jitter: jitter), queue: queue, priority: priority, error: error
      else
        if block_given?
          instrument :retry_stopped, error: error do
            yield self, error
          end
        else
          instrument :retry_stopped, error: error
          logger.debug "Stopped retrying #{self.class} due to a #{exception}, which reoccurred on #{executions} attempts. The original exception was #{error.cause.inspect}."
          raise error
        end
      end
    end
  end

  class_attribute :deduplicate

  before_enqueue :delete_duplicates, if: :deduplicate?
  around_enqueue if: :deduplicate? do |job, block|
    job.class.model.transaction(&block)
  end

  def relation
    record = self.class.model
    arguments = serialize.slice('arguments')
    record.where('args @> ?', [arguments].to_json)
  end

  def delete_duplicates
    relation.delete_all
  end

  def self.model
    Que::ActiveRecord::Model.by_job_class(to_s)
  end
end
