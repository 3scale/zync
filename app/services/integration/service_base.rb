# frozen_string_literal: true

# Base class for custom integrations.
class Integration::ServiceBase
  attr_reader :integration

  def initialize(integration)
    @integration = integration
  end

  def call(_entry)
    raise NoMethodError, __method__
  end
end
