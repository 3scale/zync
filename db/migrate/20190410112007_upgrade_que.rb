class UpgradeQue < ActiveRecord::Migration[5.2]
  def self.up
    # The current version as of this migration's creation.
    Que.migrate! version: 4
  end

  def self.down
    # Migrate back to version 3
    Que.migrate! version: 3
  end
end
