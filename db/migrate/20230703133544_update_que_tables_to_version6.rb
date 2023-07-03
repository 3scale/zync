class UpdateQueTablesToVersion6 < ActiveRecord::Migration[7.0]
  def up
    Que.migrate!(version: 6)
  end

  def down
    Que.migrate!(version: 5)
  end
end
