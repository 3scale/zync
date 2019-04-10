class UpgradeQue < ActiveRecord::Migration[5.2]
  def self.up
    Que.transaction do
      Que.execute 'SET LOCAL statement_timeout TO DEFAULT;'
      # The current version as of this migration's creation.
      Que.migrate! version: 4
    end
  end

  def self.down
    Que.transaction do
      Que.execute 'SET LOCAL statement_timeout TO DEFAULT;'
      # Migrate back to version 3
      Que.migrate! version: 3
    end
  end
end
