# frozen_string_literal: true
class CreateApplications < ActiveRecord::Migration[5.1]
  def change
    create_table :applications do |t|
      t.references :tenant, foreign_key: true, null: false
      t.references :service, foreign_key: true, null: false

      t.timestamps
    end
  end
end
