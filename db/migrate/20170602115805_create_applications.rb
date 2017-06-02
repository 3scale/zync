class CreateApplications < ActiveRecord::Migration[5.1]
  def change
    create_table :applications do |t|
      t.integer :account_id, size: 8, null: false
      t.references :tenant, foreign_key: true, null: false

      t.timestamps
    end
  end
end
