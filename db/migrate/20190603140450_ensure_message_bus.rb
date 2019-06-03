class EnsureMessageBus < ActiveRecord::Migration[5.2]
  def down
    drop_table :message_bus
  end

  def up
    MessageBus.reset!
  end
end
