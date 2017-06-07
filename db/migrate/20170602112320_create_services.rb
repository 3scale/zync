# frozen_string_literal: true
class CreateServices < ActiveRecord::Migration[5.1]
  def change
    create_table :services do |t|
      t.references :tenant, foreign_key: true, null: false
      t.timestamps
    end
  end
end
