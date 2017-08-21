# frozen_string_literal: true

require 'uri'
require 'httpclient/include_client'

# Keycloak adapter to create/update/delete Clients on using the Keycloak Client Registration API.
class Keycloak
  extend ::HTTPClient::IncludeClient
  include_http_client do |http|
    http.debug_dev = $stderr if ENV.fetch('DEBUG', '0') == '1'
  end

  attr_reader :endpoint

  def initialize(endpoint)
    endpoint = EndpointConfiguration.new(endpoint)
    @endpoint = endpoint.uri
    @access_token = AccessToken.new(endpoint.client_id, endpoint.client_secret,
                                    @endpoint.normalize, http_client)
  end

  def create_client(client)
    parse http_client.post(create_client_url, body: client, header: headers)
  end

  def read_client(client)
    parse http_client.get(client_url(client), header: headers)
  end

  def update_client(client)
    parse http_client.put(client_url(client), body: client, header: headers)
  end

  def delete_client(client)
    parse http_client.delete(client_url(client), header: headers)
    client.freeze
  end

  def create_client_url
    (@endpoint + 'clients-registrations/default').freeze
  end

  def client_url(client_or_id)
    id = client_or_id.to_param or raise 'missing client id'
    (@endpoint + "clients-registrations/default/#{id}").freeze
  end

  def well_known_url
    URI.join(@endpoint, '.well-known/openid-configuration')
  end

  def test
    parse http_client.get(well_known_url, header: headers)
  end

  # The Client entity. Mapping the Keycloak Client Representation.
  class Client
    include ActiveModel::Model
    include ActiveModel::Conversion

    # noinspection RubyResolve
    # ActiveModel::AttributeAssignment needs public accessors breaking :reek:Attribute
    attr_accessor :id, :secret, :redirect_url, :state, :enabled, :name, :description

    alias_attribute :clientId, :id
    alias_attribute :client_id, :id
    alias_attribute :client_secret, :secret

    def read
      {
        name: name,
        description: description,
        clientId: id,
        secret: client_secret,
        redirectUris: [ redirect_url ].compact,
        attributes: { '3scale' => true },
        enabled: enabled?,
      }.to_json
    end

    # This method smells of :reek:UncommunicativeMethodName but it comes from Keycloak
    def redirectUris=(uris)
      self.redirect_url = uris.first
    end

    def persisted?
      id.present?
    end

    def enabled?
      state ? state == 'live' : enabled
    end
  end

  # Raised when unexpected response is returned by the Keycloak API.
  class InvalidResponseError < StandardError
    attr_reader :response

    def initialize(response: , message: )
      @response = response
      super(message.presence || '%s %s' % [response.status, response.reason ])
    end
  end

  # Raised when there is no Access Token to authenticate with.
  class AuthenticationError < StandardError; end

  protected

  JSON_TYPE = Mime[:json]
  private_constant :JSON_TYPE

  NULL_TYPE = Mime::Type.lookup(nil)

  def parse(response)
    body = parse_response(response)

    raise InvalidResponseError, { response: response, message: body } unless response.ok?

    params = body.try(:to_h) or return # no need to create client if there are no attributes

    attributes = ActionController::Parameters.new(params)
                   .permit(:clientId, :secret, redirectUris: [])

    Client.new(attributes)
  end

  # TODO: Extract this into Response object to fix :reek:FeatureEnvy
  def parse_response(response)
    body = response.body

    case Mime::Type.lookup(response.content_type)
    when JSON_TYPE then JSON.parse(body)
    when NULL_TYPE then return body
    else raise InvalidResponseError, { response: response, message: 'Unknown Content-Type' }
    end
  end

  def headers
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  # Extracts credentials from the endpoint URL.
  class EndpointConfiguration
    attr_reader :uri, :client_id, :client_secret

    def initialize(endpoint)
      uri, client_id, client_secret = split_uri(endpoint)

      @uri = normalize_uri(uri).freeze
      @client_id = client_id.freeze
      @client_secret = client_secret.freeze
    end

    delegate :normalize_uri, :split_uri, to: :class

    def self.normalize_uri(uri)
      uri.normalize.merge("#{uri.path}/".tr_s('/', '/'))
    end

    def self.split_uri(endpoint)
      uri = URI(endpoint)
      client_id = uri.user
      client_secret = uri.password

      uri.userinfo = ''

      [ uri, client_id, client_secret ]
    end
  end

  # Handles getting and refreshing Access Token for the API access.
  class AccessToken
    # Breaking :reek:NestedIterators because that is how Faraday expects it.
    def initialize(client_id, client_secret, site, http_client)
      @oauth_client = OAuth2::Client.new(client_id, client_secret,
                                   site: site,
                                         token_url: 'protocol/openid-connect/token') do |builder|
        builder.adapter :httpclient do |client|
          client.debug_dev = http_client.debug_dev
        end
      end
      @value = Concurrent::IVar.new
      freeze
    end

    def value
      ref = reference or return
      ref.try_update(&method(:fresh_token))

      ref.value
    end

    def value!
      value or error
    end

    def error
      raise reason
    end

    protected

    delegate :reason, to: :@value

    def reference
      @value.try_set { Concurrent::AtomicReference.new(get_token) }
      @value.value
    end

    def get_token
      oauth_client.client_credentials.get_token.freeze
    end

    def fresh_token(access_token)
      access_token && !access_token.expired? ? access_token : get_token
    end

    attr_reader :oauth_client
  end
  private_constant :AccessToken

  def access_token
    @access_token.value!
  rescue => error
    raise AuthenticationError, error
  end
end
