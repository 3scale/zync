# frozen_string_literal: true

require 'uri'
require 'httpclient'
require 'mutex_m'

# KeycloakAdapter adapter to create/update/delete Clients on using the KeycloakAdapter Client Registration API.
class AbstractAdapter
  def self.build_client(*)
    raise NoMethodError, __method__
  end

  attr_reader :endpoint

  def initialize(endpoint, authentication: nil)
    endpoint = EndpointConfiguration.new(endpoint)
    @http_client = build_http_client(endpoint)
    @oidc = OIDC.new(endpoint, http_client)
    @oidc.access_token = authentication if authentication
    @endpoint = endpoint.issuer
  end

  def authentication=(value)
    oidc.access_token = value
  end

  def authentication
    oidc.access_token.token
  end

  def create_client(_client)
    raise NoMethodError, __method__
  end

  def read_client(_client)
    raise NoMethodError, __method__
  end

  def update_client(_client)
    raise NoMethodError, __method__
  end

  def delete_client(_client)
    raise NoMethodError, __method__
  end

  def test
    raise NoMethodError, __method__
  end

  protected

  attr_reader :oidc

  def headers
    oidc.headers
  end

  JSON_TYPE = Mime[:json]
  private_constant :JSON_TYPE

  attr_reader :http_client

  def build_http_client(endpoint)
    HTTPClient.new do
      self.debug_dev = $stderr if ENV.fetch('DEBUG', '0') == '1'

      self.set_auth endpoint.uri.dup, *endpoint.auth

      Rails.application.config.x.http_client.deep_symbolize_keys
          .slice(:connect_timeout, :send_timeout, :receive_timeout).each do |key, value|
        self.public_send("#{key}=", value)
      end
    end
  end

  def parse(response)
    body = self.class.parse_response(response)

    raise InvalidResponseError.new response: response, message: body unless response.ok?

    params = body.try(:to_h) or return # no need to create client if there are no attributes

    parse_client(params)
  end

  def parse_client(_)
    raise NoMethodError, __method__
  end

  # TODO: Extract this into Response object to fix :reek:FeatureEnvy
  def self.parse_response(response)
    body = response.body

    content_type = response.content_type.presence or return body

    case Mime::Type.lookup(content_type)
    when JSON_TYPE then JSON.parse(body)
    else raise InvalidResponseError.new response: response, message: 'Unknown Content-Type'
    end
  end

  # Extracts credentials from the endpoint URL.
  class EndpointConfiguration
    attr_reader :uri, :client_id, :client_secret

    alias_method :issuer, :uri

    def initialize(endpoint)
      uri, client_id, client_secret = split_uri(endpoint)

      @uri = normalize_uri(uri).freeze
      @client_id = client_id.freeze
      @client_secret = client_secret.freeze
    end

    def auth
      [client_id, client_secret]
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

  # Implements OpenID connect discovery and getting access token.
  class OIDC
    include Mutex_m

    def initialize(endpoint, http_client)
      super()

      @endpoint = endpoint
      @http_client = http_client
      @config = nil

      @access_token = AccessToken.new(method(:oauth_client))
    end

    def well_known_url
      URI.join(@endpoint.issuer, '.well-known/openid-configuration')
    end

    def config
      mu_synchronize do
        @config ||= fetch_oidc_discovery
      end
    end

    # Raised when there is no Access Token to authenticate with.
    class AuthenticationError < StandardError
      include Bugsnag::MetaData

      def initialize(error: , endpoint: )
        self.bugsnag_meta_data = {
            faraday: { uri: endpoint.to_s }
        }
        super(error)
      end
    end

    def access_token=(value)
      @access_token.value = value
    end

    def token_endpoint
      config['token_endpoint']
    end

    def headers
      { 'Authorization' => "#{authentication_type} #{access_token.token}" }
    end

    def access_token
      @access_token.value!
    rescue => error
      raise AuthenticationError.new error: error, endpoint: @endpoint.issuer
    end

    protected

    def oauth_client
      OAuth2::Client.new(@endpoint.client_id, @endpoint.client_secret,
                         site: @endpoint.uri.dup, token_url: token_endpoint) do |builder|
        builder.adapter(:httpclient).instance_variable_set(:@client, http_client)
      end
    end

    attr_reader :http_client

    def fetch_oidc_discovery
      response = http_client.get(well_known_url)
      config = response.ok? && AbstractAdapter.parse_response(response)

      case config
      when ->(obj) { obj.respond_to?(:[]) } then config
      else raise InvalidOIDCDiscoveryError, response
      end
    end

    # Raised when OIDC Discovery is not correct.
    class InvalidOIDCDiscoveryError < StandardError; end

    # Handles getting and refreshing Access Token for the API access.
    class AccessToken

      # Breaking :reek:NestedIterators because that is how Faraday expects it.
      def initialize(oauth_client)
        @oauth_client = oauth_client
        @value = Concurrent::IVar.new
        freeze
      end

      def value
        ref = reference or return
        ref.try_update(&method(:fresh_token))

        ref.value
      end

      def value=(value)
        @value.try_set { Concurrent::AtomicReference.new(OAuth2::AccessToken.new(nil, value)) }
        @value.value
      end

      def value!
        value or error
      end

      def error
        raise reason
      end

      protected

      def oauth_client
        @oauth_client.call
      end

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
    end
    private_constant :AccessToken

    def authentication_type
      'Bearer'
    end
  end

  # Raised when unexpected response is returned by the KeycloakAdapter API.
  class InvalidResponseError < StandardError
    attr_reader :response
    include Bugsnag::MetaData

    def initialize(response: , message: )
      @response = response
      self.bugsnag_meta_data = {
          response: {
              status: status = response.status,
              reason: reason = response.reason,
              content_type: response.content_type,
              body: response.body,
          },
          headers: response.headers
      }
      super(message.presence || '%s %s' % [ status, reason ])
    end
  end
end
