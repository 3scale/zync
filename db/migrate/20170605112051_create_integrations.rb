# frozen_string_literal: true
class CreateIntegrations < ActiveRecord::Migration[5.1]
  def change
    create_table :integrations do |t|
      t.jsonb :configuration
      t.string :type, null: false
      t.references :tenant, foreign_key: true
      t.references :model, foreign_key: true

      t.timestamps
    end

    add_index :integrations, [ :tenant_id, :type ], unique: true, where: 'model_id IS NULL'
    add_index :integrations, [ :tenant_id, :type, :model_id ], unique: true, where: 'model_id IS NOT NULL'
  end
end
