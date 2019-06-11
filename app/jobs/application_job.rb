# frozen_string_literal: true
# Base class for all Jobs
class ApplicationJob < ActiveJob::Base
  # Copied from ActiveJob::Exceptions, but uses debug log level.
  def self.retry_on(exception, wait: 3.seconds, attempts: 5, queue: nil, priority: nil)
    rescue_from exception do |error|
      if executions < attempts
        logger.debug "Retrying #{self.class} in #{wait} seconds, due to a #{exception}. The original exception was #{error.cause.inspect}."
        retry_job wait: determine_delay(wait), queue: queue, priority: priority
      else
        if block_given?
          yield self, error
        else
          logger.debug "Stopped retrying #{self.class} due to a #{exception}, which reoccurred on #{executions} attempts. The original exception was #{error.cause.inspect}."
          raise error
        end
      end
    end
  end
end
