# frozen_string_literal: true
class CreateIntegrationStates < ActiveRecord::Migration[5.1]
  def change
    create_table :integration_states do |t|
      t.timestamp :started_at
      t.timestamp :finished_at
      t.boolean :success
      t.references :model, foreign_key: true, null: false
      t.references :entry, foreign_key: true
      t.references :integration, foreign_key: true, null: false

      t.timestamps
    end

    add_index :integration_states, [ :model_id, :integration_id ], unique: true
  end
end
