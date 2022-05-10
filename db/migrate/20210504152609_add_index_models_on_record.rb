class AddIndexModelsOnRecord < ActiveRecord::Migration[6.1]
  def change
    remove_index :models, name: "index_models_on_record_type_and_record_id" , if_exists: true
    add_index :models, [:record_id, :record_type], name: "index_models_on_record", if_not_exists: true, unique: true
  end
end
