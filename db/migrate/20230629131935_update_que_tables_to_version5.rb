class UpdateQueTablesToVersion5 < ActiveRecord::Migration[7.0]
  def up
    Que.migrate!(version: 5)
  end
  def down
    Que.migrate!(version: 4)
  end
end
