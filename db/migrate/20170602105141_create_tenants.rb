class CreateTenants < ActiveRecord::Migration[5.1]
  def change
    create_table :tenants do |t|
      t.string :domain, null: false
      t.string :access_token, null: false

      t.timestamps
    end

    add_index :tenants, :domain, unique: true
  end
end
