unless Rails.configuration.cache_classes
  worker_count = ::Que.worker_count

  Que::Worker.prepend(Module.new do
    def wait_until_stopped
      return false if Thread.current == thread
      super
    end
  end)

  ActiveSupport::Reloader.before_class_unload do
    worker_count = ::Que.worker_count

    ::Que.worker_count = 0
  end

  ActiveSupport::Reloader.to_complete do
    ::Que.worker_count = worker_count
  end
end

def Que.start!
  require 'que/adapters/active_record'
  require 'que/worker'
  require 'que/job'

  # Workaround for https://github.com/chanks/que/pull/192
  require 'active_record/base'

  Rails.application.config.que.each do |k,v|
    Que.public_send("#{k}=", v)
  end
end

# config.ru is going to call Que.start!
