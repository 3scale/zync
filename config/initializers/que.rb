worker_count = nil

reloader = ActiveSupport::Reloader
que = ::Que

reloader.before_class_unload do
  worker_count = ::Que.worker_count
  que.worker_count = 0 # Disable all workers before reloading code.
end

reloader.to_complete do
  que.worker_count = worker_count
end

def que.start!
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
