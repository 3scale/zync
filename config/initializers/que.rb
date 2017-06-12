ActiveSupport::Reloader.before_class_unload do
  ::Que.worker_count = 0 # Disable all workers before reloading code.
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
