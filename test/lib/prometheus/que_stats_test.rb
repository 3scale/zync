# frozen_string_literal: true
require 'test_helper'
require 'prometheus/que_stats'

class Prometheus::QueStatsTest < ActiveSupport::TestCase
  setup do
    @_readonly_transaction = Prometheus::QueStats.read_only_transaction
    Prometheus::QueStats.read_only_transaction = false
  end

  teardown do
    Prometheus::QueStats.read_only_transaction = @_readonly_transaction
  end

  test 'worker stats' do
    assert Prometheus::QueStats.worker_stats
  end

  test 'job stats' do
    assert Prometheus::QueStats.job_stats
    assert Prometheus::QueStats.job_stats('1 > 0')
  end

  class WithTransaction < ActiveSupport::TestCase
    uses_transaction :test_readonly_transaction
    def test_readonly_transaction
      Prometheus::QueStats.stub(:read_only_transaction, true) do
        Prometheus::QueStats.worker_stats
      end
    end
  end

  test 'serialize metrics' do
    Que.stop!

    job = ApplicationJob.new
    job.enqueue

    job.scheduled_at = 1.day.ago
    job.enqueue

    job.executions = 1
    job.enqueue

    Yabeda.collectors.each(&:call)

    assert Prometheus::Client::Formats::Text.marshal(Yabeda::Prometheus.registry)
  end
end
