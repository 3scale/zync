# frozen_string_literal: true

require 'uri'
require 'httpclient/include_client'

class Keycloak
  extend ::HTTPClient::IncludeClient
  include_http_client do |http|
    http.debug_dev = $stderr if ENV.fetch('DEBUG', '0') == '1'
  end

  attr_reader :endpoint

  def initialize(endpoint)
    @endpoint, client_id, client_secret = parse_endpoint(endpoint)
    @oauth2 = OAuth2::Client.new(client_id, client_secret,
                                   site: @endpoint.normalize,
                                   token_url: 'protocol/openid-connect/token')
    @access_token = Concurrent::IVar.new
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

  class Client
    include ActiveModel::Model
    include ActiveModel::Conversion

    attr_accessor :id, :secret, :redirect_url

    alias_attribute :clientId, :id

    def read
      { id: id, clientId: id, secret: secret, redirectUris: [ redirect_url ].compact, attributes: { '3scale' => true } }.to_json
    end

    # noinspection RubyInstanceMethodNamingConvention
    def redirectUris=(uris)
      self.redirect_url = uris&.first
    end

    def persisted?
      id.present?
    end
  end

  class InvalidResponseError < StandardError; end

  protected

  JSON_TYPE = Mime[:json]
  private_constant :JSON_TYPE

  NULL_TYPE = Mime::Type.lookup(nil)

  def parse(response)
    body = parse_response(response)

    raise InvalidResponseError, ( body || response).inspect unless response.ok?

    params = body.try(:to_h) or return # no need to create client if there are no attributes

    attributes = ActionController::Parameters.new(params)
                   .permit(:clientId, :secret, redirectUris: [])

    Client.new(attributes)
  end

  def parse_response(response)
    case mime = Mime::Type.lookup(response.content_type)
    when JSON_TYPE then JSON.parse(response.body)
    when NULL_TYPE then return response.body
    else raise "Unknown Content-Type #{mime.inspect}"
    end
  end

  def headers
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  def parse_endpoint(endpoint)
    uri = URI(endpoint)
    client_id = uri.user
    client_secret = uri.password

    uri.userinfo = ''
    [ uri.freeze, client_id, client_secret ]
  end

  attr_reader :oauth2

  NULL_TOKEN = Struct.new(:token)

  def access_token
    @access_token.try_set { oauth2.client_credentials.get_token.freeze }
    @access_token.value || NULL_TOKEN.new
  end
end
