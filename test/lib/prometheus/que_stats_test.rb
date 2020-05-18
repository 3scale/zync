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
    Que.stop!
    ApplicationJob.perform_later
    assert Prometheus::QueStats.job_stats.any?
    assert Prometheus::QueStats.job_stats('1 > 0').any?
    assert Prometheus::QueStats.job_stats('1 > 0', '2 > 1').any?
    assert Prometheus::QueStats.job_stats('1 > 0', '2 < 1').empty?
  end

  test 'ready jobs stats' do
    Que.stop!
    assert Prometheus::QueStats.job_stats_ready.empty?
    jobs = Array.new(3) { ApplicationJob.perform_later }
    jobs << ApplicationJob.set(wait_until: 1.day.from_now).perform_later
    assert_equal 3, Prometheus::QueStats.job_stats_ready.first['count']
    update_job(jobs[0], error_count: 1)
    assert_equal 2, Prometheus::QueStats.job_stats_ready.first['count']
    update_job(jobs[1], expired_at: 1.minute.ago)
    assert_equal 1, Prometheus::QueStats.job_stats_ready.first['count']
    update_job(jobs[2], finished_at: 1.minute.ago)
    assert Prometheus::QueStats.job_stats_ready.empty?
  end

  test 'scheduled jobs stats' do
    Que.stop!
    assert Prometheus::QueStats.job_stats_scheduled.empty?
    jobs = [ApplicationJob, ApplicationJob.set(wait_until: 1.day.from_now)].map(&:perform_later)
    assert_equal 1, Prometheus::QueStats.job_stats_scheduled.first['count']
    update_job(jobs.last, run_at: 1.minute.ago)
    assert Prometheus::QueStats.job_stats_scheduled.empty?
  end

  test 'finished jobs stats' do
    Que.stop!
    assert Prometheus::QueStats.job_stats_finished.empty?
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert Prometheus::QueStats.job_stats_finished.empty?
    update_job(jobs.first, finished_at: Time.now)
    assert_equal 1, Prometheus::QueStats.job_stats_finished.first['count']
  end

  test 'retried jobs stats' do
    Que.stop!
    assert Prometheus::QueStats.job_stats_retried.empty?
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert Prometheus::QueStats.job_stats_retried.empty?

    job = jobs.first
    job_model = ApplicationJob.model.where("args->0->>'job_id' = ?", job.job_id).first
    job_model.args = [job_model.args.first.merge('retries' => 1)]
    job_model.save!

    assert_equal 1, Prometheus::QueStats.job_stats_retried.first['count']
  end

  test 'failed jobs stats' do
    Que.stop!
    assert Prometheus::QueStats.job_stats_failed.empty?
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert Prometheus::QueStats.job_stats_failed.empty?
    update_job(jobs.first, error_count: 1)
    assert_equal 1, Prometheus::QueStats.job_stats_failed.first['count']
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

  protected

  def update_job(job, attributes = {})
    ApplicationJob.model.where("args->0->>'job_id' = ?", job.job_id).update_all(attributes)
  end
end
