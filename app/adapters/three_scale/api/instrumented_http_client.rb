# frozen_string_literal: true
require '3scale/api/http_client'
require 'securerandom'

# Custom HTTP Client for 3scale API client with added instrumentation.,
class ThreeScale::API::InstrumentedHttpClient < ThreeScale::API::HttpClient

  module NetHttpNotifications
    delegate :instrument, to: 'ActiveSupport::Notifications'

    def connect
      instrument('connect.net_http', {
          adapter: self
      }) do
        super
      end
    end

    def begin_transport(req)
      instrument('begin_transport.net_http', {
          adapter: self, request: req
      }) do
        super
      end
    end

    def end_transport(req, res)
      instrument('end_transport.net_http', {
          adapter: self, request: req, response: res
      }) do
        super
      end
    end

    def transport_request(req)
      payload = { adapter: self, request: req }
      instrument('transport_request.net_http', payload) do
        payload[:response] = super
      end
    end

    def ssl_socket_connect(*)
      instrument('ssl_socket_connect.net_http', {
          adapter: self
      }) do
        super
      end
    end
  end

  module NetHttpRequestNotifications
    delegate :instrument, to: 'ActiveSupport::Notifications'

    def exec(*)
      instrument('exec.net_http', {
          adapter: self, request: self
      }) do
        super
      end
    end
  end

  module NetHttpResponseNotifications
    delegate :instrument, to: 'ActiveSupport::Notifications'

    def reading_body(*)
      instrument('reading_body.net_http', {
          adapter: self, response: self
      }) do
        super
      end
    end

    module ClassMethods
      delegate :instrument, to: 'ActiveSupport::Notifications'

      def read_new(*)
        payload = { }
        instrument('read_new.net_http', payload) do
          payload[:adapter] = payload[:response] = super
        end
      end

      public :read_new
    end
  end

  Net::HTTPResponse.prepend(NetHttpResponseNotifications)
  Net::HTTPResponse.singleton_class.prepend(NetHttpResponseNotifications::ClassMethods)

  def initialize(*)
    super

    @http.extend(NetHttpNotifications)
  end

  def get(path, params: nil)
    req = build_request(Net::HTTP::Get, path, params)
    parse request(req, params: params)
  end

  def patch(path, body: , params: nil)
    req = build_request(Net::HTTP::Patch, path, params)

    parse request(req, body, params: params)
  end

  def post(path, body: , params: nil)
    req = build_request(Net::HTTP::Post, path, params)

    parse request(req, body, params: params)
  end

  def put(path, body: nil, params: nil)
    req = build_request(Net::HTTP::Put, path, params)

    parse request(req, body, params: params)
  end

  def delete(path, params: nil)
    req = build_request(Net::HTTP::Delete, path, params)

    parse request(req, params: params)
  end

  def parse(response)
    case response
      when Net::HTTPNotFound then nil
      else super
    end
  end

  protected

  def headers
    super.merge('X-Request-Id' => SecureRandom.uuid)
  end

  def build_request(type, path, params)
    uri = format_path_n_query(path, params)
    type.new(uri, headers).extend(NetHttpRequestNotifications)
  end

  def request(req, body = nil, params: )
    instrument('request.three_scale_api_client', build_payload(req)) do |payload|
      payload[:request_id] = req['X-Request-Id']
      payload[:params] = params

      response = @http.request(req, body)

      payload[:response] = response.code
      payload[:response_id] = response['X-Request-Id']

      if req.response_body_permitted?
        response.read_body
      end

      response
    end
  end

  def build_payload(req)
    {
        uri: endpoint.merge(req.path).to_s,
        path: req.path,
        ednpoint: endpoint,
        method: req.method,
        adapter: self
    }
  end

  delegate :instrument, to: 'ActiveSupport::Notifications'
end