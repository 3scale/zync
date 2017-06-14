require 'uri'

class Keycloak
  attr_reader :endpoint

  def initialize(endpoint)
    @endpoint = URI(endpoint).freeze
  end
end
