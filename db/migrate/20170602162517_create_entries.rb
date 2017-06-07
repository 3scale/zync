# frozen_string_literal: true
class CreateEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :entries do |t|
      t.json :data
      t.references :tenant, foreign_key: true, null: false
      t.references :model, foreign_key: true, null: false

      t.timestamps
    end
  end
end
