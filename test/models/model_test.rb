# frozen_string_literal: true
require 'test_helper'

class ModelTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def test_weak_lock
    model = Model.first!


    # The events in the two threads must happen in a particular order:
    # 1. The new thread must lock the record and wait. This way the lock
    #    and the transaction are kept open.
    # 2. The main thread must wait until the lock is taken, only then it can
    #    try to take the lock
    # We use queues to signal threads
    locked_signal = Queue.new
    release_signal = Queue.new

    # Take the lock and keep it taken
    thread = Thread.new do
      Model.transaction do
        model.weak_lock
        locked_signal.push(true)
        release_signal.pop
      end
    end

    # Wait till the lock is taken
    locked_signal.pop

    # Try to take the lock, we expect it to fail
    assert_raises Model::LockTimeoutError do
      model.weak_lock
    end

    # Release the thread
    release_signal.push(true)
    thread.join
  end
end
