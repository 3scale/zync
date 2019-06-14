# frozen_string_literal: true

# Example Integration that just prints what it is doing the log.

class Integration::EchoService < Integration::ServiceBase
  def call(entry)
    logger.debug "Integrating #{entry.to_gid} to #{integration.to_gid}"
  end

  delegate :logger, to: :Rails
end
