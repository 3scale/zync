class RemoveMessageBus < ActiveRecord::Migration[5.2]
  def up
    drop_table :message_bus
  end

  def down
    create_table "message_bus", force: :cascade do |t|
      t.text "channel", null: false
      t.text "value", null: false
      t.datetime "added_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.index ["added_at"], name: "table_added_at_index"
      t.index ["channel", "id"], name: "table_channel_id_index"
      t.check_constraint "octet_length(value) >= 2", name: "message_bus_value_check"
    end
  end
end
