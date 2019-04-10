::Que.module_eval do
  mattr_accessor :worker_count, default: 0
  mattr_accessor :locker
end

unless Rails.configuration.cache_classes
  ActiveSupport::Reloader.before_class_unload do
    Que.locker.stop!
  end

  ActiveSupport::Reloader.to_complete do
    Que.start!
  end
end

def Que.start!
  require 'que/locker'

  # Workaround for https://github.com/chanks/que/pull/192
  require 'active_record/base'
  Que.locker = Que::Locker.new(Rails.application.config.x.que)
end

def Que.stop!
  Que.locker.stop!
end

# config.ru is going to call Que.start!
