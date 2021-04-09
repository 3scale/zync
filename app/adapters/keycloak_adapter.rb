# frozen_string_literal: true

require 'uri'

# KeycloakAdapter adapter to create/update/delete Clients on using the KeycloakAdapter Client Registration API.
class KeycloakAdapter < AbstractAdapter
  # Serialize OAuth Configuration to KeycloakAdapter format
  class OAuthConfiguration
    def initialize(params)
      @params = params
    end

    def to_hash
      {
          standardFlowEnabled: params[:standard_flow_enabled],
          implicitFlowEnabled: params[:implicit_flow_enabled],
          serviceAccountsEnabled: params[:service_accounts_enabled],
          directAccessGrantsEnabled: params[:direct_access_grants_enabled],
      }.compact
    end

    protected

    attr_reader :params
  end
  private_constant :OAuthConfiguration

  # The Client entity. Mapping the KeycloakAdapter Client Representation.
  class Client
    include ActiveModel::Model
    include ActiveModel::Conversion
    include ActiveModel::Attributes

    # noinspection RubyResolve
    # ActiveModel::AttributeAssignment needs public accessors breaking :reek:Attribute
    attr_accessor :id, :secret, :redirect_url,
                  :state, :enabled, :name, :description

    alias_attribute :clientId, :id
    alias_attribute :client_id, :id
    alias_attribute :client_secret, :secret

    delegate :to_json, to: :to_h
    alias read to_json

    attribute :oidc_configuration, default: {}.freeze

    def to_h
      {
          name: name,
          description: description,
          clientId: id,
          secret: client_secret,
          redirectUris: [ redirect_url ].compact,
          attributes: { '3scale' => true },
          enabled: enabled?,
          **oidc_configuration,
          **self.class.attributes,
      }
    end

    # This method smells of :reek:UncommunicativeMethodName but it comes from KeycloakAdapter
    def redirectUris=(uris)
      self.redirect_url = uris.first
    end

    def oidc_configuration=(params)
      _write_attribute 'oidc_configuration', OAuthConfiguration.new(params)
    end

    def persisted?
      id.present?
    end

    def enabled?
      enabled
    end

    def self.attributes
      Rails.application.config.x.keycloak.deep_symbolize_keys.dig(:attributes) || Hash.new
    end
  end

  def self.build_client(attributes)
    Client.new(attributes)
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

  def test
    parse http_client.get(oidc.well_known_url, header: headers)
  end

  protected

  def build_http_client(*)
    super.tap do |client|
      Rails.application.config.x.keycloak.deep_symbolize_keys.fetch(:http_client, {})
          .slice(:connect_timeout, :send_timeout, :receive_timeout).each do |key, value|
        client.public_send("#{key}=", value)
      end
    end
  end

  def create_client_url
    (endpoint + 'clients-registrations/default').freeze
  end

  def client_url(client_or_id)
    id = client_or_id.to_param or raise 'missing client id'
    (endpoint + "clients-registrations/default/#{id}").freeze
  end

  def headers
    super.merge('Content-Type' => 'application/json')
  end

  def parse_client(params)
    attributes = ActionController::Parameters.new(params)
                     .permit(:clientId, :secret, redirectUris: [])

    Client.new(attributes)
  end
end
