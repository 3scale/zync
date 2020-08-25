# frozen_string_literal: true
require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
# require "action_mailer/railtie"
require "action_view/railtie"
# require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Zync
  class Application < Rails::Application
    # Que needs :sql because of advanced PostgreSQL features
    config.active_record.schema_format = :sql

    config.active_job.queue_adapter = :que

    begin
      que = config_for(:que)&.deep_symbolize_keys

      config.x.que = que
      config.x.que[:worker_priorities] ||= Array.new(que.delete(:worker_count).to_i)
    end

    # Use the responders controller from the responders gem
    config.app_generators.scaffold_controller :responders_controller

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    config.integrations = config_for(:integrations)

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    initializer 'lograge.defaults' do
      require 'lograge/custom_options'
      config.lograge.base_controller_class = 'ActionController::API'
      config.lograge.ignore_actions = %w[Status/LiveController#show Status/ReadyController#show]
      config.lograge.formatter = Lograge::Formatters::Json.new
      config.lograge.custom_options = Lograge::CustomOptions
    end

    initializer 'message_bus.middleware', before: 'message_bus.configure_init' do
      config.middleware.use(ActionDispatch::Flash) # to fix loading message bus
    end

    initializer 'message_bus.middleware', after: 'message_bus.configure_init' do
      config.middleware.delete(ActionDispatch::Flash) # remove it after message bus loaded
    end

    initializer 'k8s-client.logger' do
      case config.log_level
      when :debug
        K8s::Logging.debug!
        K8s::Transport.debug!
      when :info
        K8s::Logging.verbose!
        K8s::Transport.verbose!
      when :error
        K8s::Logging.quiet!
        K8s::Transport.quiet!
      else
        K8s::Logging.log_level = K8s::Transport.log_level = Rails.logger.level
      end
    end

    config.x.keycloak = config_for(:keycloak) || Hash.new
    config.x.openshift = ActiveSupport::InheritableOptions.new(config_for(:openshift)&.deep_symbolize_keys)
  end
end
