::Que.module_eval do
  mattr_accessor :worker_count, default: 0
  mattr_accessor :locker
end

unless Rails.configuration.cache_classes
  ActiveSupport::Reloader.before_class_unload do
    Que.locker&.stop
  end

  ActiveSupport::Reloader.to_complete do
    # Que.start!
  end
end

def Que.start!
  require 'que/locker'
  require 'que/db_connection_url'

  # Workaround for https://github.com/chanks/que/pull/192
  require 'active_record/base'

  # Build connection URL with SSL parameters from database config
  # Workaround for https://github.com/que-rb/que/issues/442
  db_config = ActiveRecord::Base.connection_db_config.configuration_hash
  connection_url = Que::DBConnectionURL.build_connection_url(db_config)

  Que.locker = Que::Locker.new(connection_url: connection_url, **Rails.application.config.x.que)
end

def Que.stop!
  Que.locker.stop!
end

# config.ru is going to call Que.start!
