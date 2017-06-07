# frozen_string_literal: true
# Example Integration that just prints what it is doing the log.

class Integration::EchoService
  def initialize
    freeze
  end

  def call(integration, entry)
    logger.debug "Integrating #{entry} to #{integration}"
  end

  delegate :logger, to: :Rails
end
