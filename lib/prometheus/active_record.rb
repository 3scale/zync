# frozen_string_literal: true

RAILS_CONNECTION_PROMETHEUS_TAGS = %i[state].freeze

Yabeda.configure do
  group :rails_connection_pool do
    # Empty label values SHOULD be treated as if the label was not present.
    # @see https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#label
    no_labels = { state: nil }.freeze
    busy = { state: :busy }.freeze
    dead = { state: :dead }.freeze
    idle = { state: :idle }.freeze
    tags = RAILS_CONNECTION_PROMETHEUS_TAGS

    size = gauge :size, comment: 'Size of the connection pool', tags: tags
    connections = gauge :connections, comment: 'Number of connections in the connection pool', tags: tags
    waiting = gauge :waiting, comment: 'Number of waiting in the queue of the connection pool', tags: tags

    collect do
      stat = ActiveRecord::Base.connection_pool.stat
      size.set(no_labels, stat.fetch(:size))
      connections.set(no_labels, stat.fetch(:connections))
      connections.set(busy, stat.fetch(:busy))
      connections.set(dead, stat.fetch(:dead))
      connections.set(idle, stat.fetch(:idle))
      waiting.set(no_labels, stat.fetch(:waiting))
    end
  end
end
