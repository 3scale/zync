# Provides #timestamp method for jobs that need to get timestamp

module JobWithTimestamp
  extend ActiveSupport::Concern

  def timestamp
    zone.now
  end

  def initialize(*)
    super
    @zone = Time.zone
  end

  attr_reader :zone
end
