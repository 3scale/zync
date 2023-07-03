class UpdateQueTablesToVersion7 < ActiveRecord::Migration[7.0]
  def up
    Que.migrate!(version: 7)
  end

  def down
    Que.migrate!(version: 6)
  end
end
