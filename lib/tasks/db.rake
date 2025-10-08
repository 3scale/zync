# frozen_string_literal: true
namespace :db do
  task wait: %i(environment) do
    timeout = (ActiveRecord::Base.connection_pool.checkout_timeout || 5).seconds

    start_time = Concurrent.monotonic_time

    delay = 0.01

    begin
      ActiveRecord::Base.connection
    rescue
      raise if Concurrent.monotonic_time >= (start_time + timeout)
      sleep delay
      delay *= 2
      retry
    end
  end
end
