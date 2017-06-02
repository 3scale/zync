class CreateUsageLimits < ActiveRecord::Migration[5.1]
  def change
    create_table :usage_limits do |t|
      t.references :metric, foreign_key: true, null: false
      t.integer :plan_id, size: 8, null: false
      t.references :tenant, foreign_key: true, null: false

      t.timestamps
    end
  end
end
