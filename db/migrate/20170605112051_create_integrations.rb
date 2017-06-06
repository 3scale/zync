class CreateIntegrations < ActiveRecord::Migration[5.1]
  def change
    create_table :integrations do |t|
      t.json :configuration
      t.string :type, null: false
      t.references :tenant, foreign_key: true

      t.timestamps
    end

    add_index :integrations, [ :tenant_id, :type ], unique: true
  end
end
