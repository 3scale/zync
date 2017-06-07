# frozen_string_literal: true
class CreateNotifications < ActiveRecord::Migration[5.1]
  def change
    create_table :notifications do |t|
      t.references :model, foreign_key: true, null: false
      t.json :data, null: false
      t.references :tenant, foreign_key: true, null: false

      t.timestamps
    end
  end
end
