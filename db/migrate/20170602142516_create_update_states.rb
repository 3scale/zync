# frozen_string_literal: true
class CreateUpdateStates < ActiveRecord::Migration[5.1]
  def change
    create_table :update_states do |t|
      t.timestamp :started_at
      t.timestamp :finished_at
      t.boolean :success, null: false, default: false
      t.references :model, foreign_key: true, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
