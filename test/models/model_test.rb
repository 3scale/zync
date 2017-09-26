# frozen_string_literal: true
require 'test_helper'

class ModelTest < ActiveSupport::TestCase
  def test_weak_lock
    locking_connection = Model.connection_pool.checkout

    fiber = Model.stub(:connection, locking_connection) do
      Fiber.new do
        locking_connection.transaction do
          Fiber.yield Model.first!.weak_lock
        end
      end
    end

    locked_model = fiber.resume
    refute_equal Model.connection, locking_connection

    connection = Model.connection_pool.checkout

    Model.stub(:connection, connection) do
      assert_raises Model::LockTimeoutError do
        Model.find(locked_model.id).weak_lock
      end
    end
  end
end
