class AddIntegrationState < ActiveRecord::Migration[5.2]
  def up
    create_enum :integration_state, 'active', 'disabled'
    add_column :integrations, :state, :integration_state
    default = 'active'
    Integration.in_batches.update_all(state: default)
    change_column_default :integrations, :state, default
    change_column_null :integrations, :state, false
  end

  def down
    remove_column :integrations, :state
    drop_enum :integration_state
  end
end
