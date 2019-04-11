require 'prometheus/job_stats'
require 'prometheus/worker_stats'

prometheus = Prometheus::Client.registry

scheduled_job_stats = Prometheus::JobStats.new(:zync_scheduled_jobs, 'Que Jobs to be executed')
scheduled_job_stats
prometheus.register(scheduled_job_stats)

retried_job_stats = Prometheus::JobStats.new(:zync_retried_jobs, 'Que Jobs to retried')
retried_job_stats.filter('retries > 0')
prometheus.register(retried_job_stats)

pending_job_stats = Prometheus::JobStats.new(:zync_pending_jobs, 'Que Jobs that should be already running')
pending_job_stats.filter('run_at < now()')
prometheus.register(pending_job_stats)

worker_stats = Prometheus::WorkerStats.new(:zync_workers, 'Que Workers running')
prometheus.register(worker_stats)

require 'prometheus/active_job_subscriber'
