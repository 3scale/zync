# frozen_string_literal: true
# Returns a Service for each Integration.
# Each Integration can be using different Service.
# This class creates a mapping between Integration and Service.

class DiscoverIntegrationService
  def initialize
    freeze
  end

  class << self
    delegate :call, to: :new
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
