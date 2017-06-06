class CreateMetrics < ActiveRecord::Migration[5.1]
  def change
    create_table :metrics do |t|
      t.references :service, foreign_key: true, null: false
      t.references :tenant, foreign_key: true, null: false

      t.timestamps
    end
  end
end
