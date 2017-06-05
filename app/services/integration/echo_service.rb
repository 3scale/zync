class Integration::EchoService
  def initialize
    freeze
  end

  def call(integration, entry)
    logger.debug "Integrating #{entry} to #{integration}"
  end

  delegate :logger, to: :Rails
end
