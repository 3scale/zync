require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Zync
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # config.autoload_lib(ignore: %w(tasks puma generators prometheus que))

    # Que needs :sql because of advanced PostgreSQL features
    config.active_record.schema_format = :sql

    # Calls `Rails.application.executor.wrap` around test cases.
    # This makes test cases behave closer to an actual request or job.
    # Several features that are normally disabled in test, such as Active Record query cache
    # and asynchronous queries will then be enabled.
    # Some Zync tests use assert_difference for model count, which breaks with the default 'true' value
    # due to using Active Record cache
    config.active_support.executor_around_test_case = false

    config.active_job.queue_adapter = :que

    begin
      que = config_for(:que)&.deep_symbolize_keys

      config.x.que = que
      config.x.que[:worker_priorities] ||= Array.new(que.delete(:worker_count).to_i)
    end

    # Use the responders controller from the responders gem
    config.app_generators.scaffold_controller :responders_controller

    config.integrations = config_for(:integrations)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

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
    config.x.zync = config_for(:zync)
    config.x.tools = config_for(:tools) || Hash.new
  end
end
