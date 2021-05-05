class AddIndexModelsOnRecord < ActiveRecord::Migration[6.1]
  def change
    add_index :models, [:record_id, :record_type], name: "index_models_on_record", if_not_exists: true
  end
end
