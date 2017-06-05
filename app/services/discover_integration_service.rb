class DiscoverIntegrationService
  def initialize
    freeze
  end

  def call(integration)
    case integration
    when integration
      Integration::EchoService.new
    else # the only one for now
      raise NotImplementedError
    end
  end
end
