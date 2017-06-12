# frozen_string_literal: true

# Gathers and returns status object that determines if the app is healthy and ready.

class StatusService
  def initialize
    freeze
  end

  class << self
    delegate :call, to: :new
  end

  # Status object that handles serialization and acts as an Entity object.
  class Status
    def initialize(**status)
      @status = status.merge(ok: status.values.all?(&:itself)).freeze
      freeze
    end

    delegate :as_json, to: :@status
  end

  def call
    Status.new(database: ActiveRecord::Base.connected?)
  end
end
