# frozen_string_literal: true

require 'uri'

# KeycloakAdapter adapter to create/update/delete Clients on using the KeycloakAdapter Client Registration API.
class RESTAdapter < AbstractAdapter
  def self.build_client(*attrs)
    Client.new(*attrs)
  end

  attr_reader :endpoint

  def create_client(client)
    parse http_client.put(client_url(client), body: client, header: headers)
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

  def test
    parse http_client.get(oidc.well_known_url, header: headers)
  end

  def authentication
    super
  rescue OIDC::AuthenticationError
    nil
  end

  # The Client entity. Mapping the OpenID Connect Client Metadata representation.
  # https://tools.ietf.org/html/rfc7591#section-2
  class Client
    include ActiveModel::Model
    include ActiveModel::Conversion
    include ActiveModel::Attributes

    attr_accessor :client_id, :client_secret, :client_name, :redirect_uris, :grant_types

    alias_attribute :name, :client_name
    alias_attribute :secret, :client_secret
    alias_attribute :id, :client_id

    attr_accessor :state, :enabled

    delegate :to_json, to: :to_h
    alias read to_json

    def initialize(*)
      self.redirect_uris = []
      self.grant_types = GrantTypes.new({})
      super
    end

    def to_h
      {
          client_id: client_id,
          client_secret: client_secret,
          client_name: client_name,
          redirect_uris: redirect_uris,
          grant_types: grant_types,
          **self.class.attributes,
      }
    end

    def redirect_url=(val)
      self.redirect_uris = [ val ].compact
    end

    def oidc_configuration=(config)
      self.grant_types = GrantTypes.new(config)
    end

    def persisted?
      id.present?
    end

    def enabled?
      enabled
    end

    def self.attributes
      Rails.application.config.x.generic.deep_symbolize_keys.dig(:attributes) || Hash.new
    end

    # Serialize OAuth Configuration to KeycloakAdapter format
    class GrantTypes
      def initialize(params)
        @params = params
      end

      def as_json(*args)
        params.map do |name, enabled|
          MAPPING.fetch(name.to_sym) if enabled
        end.compact.as_json(*args)
      end

      MAPPING = {
          standard_flow_enabled: :authorization_code,
          implicit_flow_enabled: :implicit,
          direct_access_grants_enabled: :password,
          service_accounts_enabled: :client_credentials,
      }.freeze
      private_constant :MAPPING

      protected

      attr_reader :params
    end
    private_constant :GrantTypes
  end

  protected

  def client_url(client_or_id)
    id = client_or_id.to_param or raise 'missing client id'
    URI.join(endpoint, "clients/#{id}").freeze
  end

  def well_known_url
    URI.join(endpoint, '.well-known/openid-configuration')
  end

  def parse_client(params)
    attributes = ActionController::Parameters.new(params)
                     .permit(:client_id, :client_secret, :client_name, redirect_uris: [], grant_types: [])

    Client.new(attributes)
  end

  def headers
    super.merge('Content-Type' => 'application/json')
  rescue OIDC::AuthenticationError => error
    Rails.logger.error(error)
    { 'Content-Type' => 'application/json' }
  end
end
