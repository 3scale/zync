require 'prometheus/active_job_subscriber'
require 'prometheus/active_record'

Yabeda.configure! if Yabeda.respond_to?(:configure!)
Prometheus::ActiveJobSubscriber.attach_to :active_job
