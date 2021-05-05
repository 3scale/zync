class RemoveIndexModelsOnRecordTypeAndRecordId < ActiveRecord::Migration[6.1]
  def change
    remove_index :models, name: "index_models_on_record_type_and_record_id" , if_exists: true
  end
end
