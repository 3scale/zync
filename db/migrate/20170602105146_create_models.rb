# frozen_string_literal: true
class CreateModels < ActiveRecord::Migration[5.1]
  def change
    create_table :models do |t|
      t.references :tenant, foreign_key: true, null: false
      t.references :record,  polymorphic: true, type: :bigint, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
