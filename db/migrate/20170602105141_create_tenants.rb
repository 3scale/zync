# frozen_string_literal: true
class CreateTenants < ActiveRecord::Migration[5.1]
  def change
    create_table :tenants do |t|
      t.string :endpoint, null: false
      t.string :access_token, null: false

      t.timestamps
    end
  end
end
