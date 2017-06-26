# frozen_string_literal: true
# Example Integration that just prints what it is doing the log.

class Integration::EchoService
  attr_reader :integration

  def initialize(integration)
    @integration = integration
    freeze
  end

  def call(entry)
    logger.debug "Integrating #{entry} to #{integration}"
  end

  delegate :logger, to: :Rails
end
