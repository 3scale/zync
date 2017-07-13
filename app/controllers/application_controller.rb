# frozen_string_literal: true
require 'application_responder'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  self.responder = ApplicationResponder

  before_action :authenticate
  respond_to :json

  protected

  def authenticate
    authentication = Rails.application.secrets.authentication || {}.freeze

    expected_token = authentication.fetch(:token) { return }

    authenticate_or_request_with_http_token do |token|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(expected_token)
      )
    end
  end
end
