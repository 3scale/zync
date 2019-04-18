# frozen_string_literal: true

require 'prometheus/que_stats'
require 'prometheus/active_job_subscriber'

Yabeda::Prometheus::Exporter.start_metrics_server!
