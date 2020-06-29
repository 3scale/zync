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
    assert Prometheus::QueStats::WorkerStats.new.call
  end

  test 'job stats' do
    Que.stop!
    ApplicationJob.perform_later
    assert_equal 1, stats_count
    assert_equal 1, stats_count(where: ['1 > 0'])
    assert_equal 1, stats_count(where: ['1 > 0', '2 > 1'])
    assert_equal 0, stats_count(where: ['1 > 0', '2 < 1'])
  end

  test 'ready jobs stats' do
    Que.stop!
    assert_equal 0, stats_count(type: :ready)
    jobs = Array.new(3) { ApplicationJob.perform_later }
    jobs << ApplicationJob.set(wait_until: 1.day.from_now).perform_later
    assert_equal 3, stats_count(type: :ready)
    update_job(jobs[0], error_count: 1)
    assert_equal 2, stats_count(type: :ready)
    update_job(jobs[1], expired_at: 1.minute.ago)
    assert_equal 1, stats_count(type: :ready)
    update_job(jobs[2], finished_at: 1.minute.ago)
    assert_equal 0, stats_count(type: :ready)
  end

  test 'scheduled jobs stats' do
    Que.stop!
    assert_equal 0, stats_count(type: :scheduled)
    jobs = [ApplicationJob, ApplicationJob.set(wait_until: 1.day.from_now), ApplicationJob.set(wait_until: 2.days.from_now)].map(&:perform_later)
    assert_equal 2, stats_count(type: :scheduled)
    update_job(jobs[1], error_count: 16, expired_at: 1.minute.ago)
    assert_equal 1, stats_count(type: :scheduled)
    update_job(jobs.last, run_at: 1.minute.ago)
    assert_equal 0, stats_count(type: :scheduled)
  end

  test 'finished jobs stats' do
    Que.stop!
    assert_equal 0, stats_count(type: :finished)
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert_equal 0, stats_count(type: :finished)
    update_job(jobs.first, finished_at: Time.now)
    assert_equal 1, stats_count(type: :finished)
  end

  test 'failed jobs stats' do
    Que.stop!
    assert_equal 0, stats_count(type: :failed)
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert_equal 0, stats_count(type: :failed)
    update_job(jobs.first, error_count: 1)
    assert_equal 1, stats_count(type: :failed)
    update_job(jobs.first, error_count: 15)
    assert_equal 1, stats_count(type: :failed)
    update_job(jobs.first, error_count: 16, expired_at: Time.now.utc)
    assert_equal 0, stats_count(type: :failed)
  end

  test 'expired jobs stats' do
    Que.stop!
    assert_equal 0, stats_count(type: :expired)
    jobs = Array.new(2) { ApplicationJob.perform_later }
    assert_equal 0, stats_count(type: :expired)
    update_job(jobs.first, error_count: 16, expired_at: Time.now.utc)
    assert_equal 1, stats_count(type: :expired)
  end

  class WithTransaction < ActiveSupport::TestCase
    uses_transaction :test_readonly_transaction
    def test_readonly_transaction
      Prometheus::QueStats.stub(:read_only_transaction, true) do
        Prometheus::QueStats::WorkerStats.new.call
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

  def stats_count(job_class: ApplicationJob.name, type: nil, where: [])
    job_stats = Prometheus::QueStats::JobStats.new
    stats = type ? job_stats.public_send(type) : job_stats.call(*where)
    record = stats.find { |record| record['job'] == job_class }
    record['count']
  end
end
