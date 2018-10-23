class CreateClients < ActiveRecord::Migration[5.2]
  def change
    create_table :clients do |t|
      t.references :service, foreign_key: true, null: false
      t.references :tenant, foreign_key: true, null: false

      t.string :client_id, null: false
      t.timestamps
    end

    add_index :clients, [ :client_id, :service_id ], unique: true
  end
end
