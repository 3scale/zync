class UpdateJobSchemaVersion < ActiveRecord::Migration[7.0]
  def up
    require 'que/active_record/model'
    Que::ActiveRecord::Model.update_all(job_schema_version: 2)
  end
end
