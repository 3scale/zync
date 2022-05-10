# frozen_string_literal: true
namespace :db do
  task wait: %i(environment) do
    timeout = (ActiveRecord::Base.connection_pool.checkout_timeout || 5).seconds

    start_time = Concurrent.monotonic_time

    delay = 0.01

    begin
      ActiveRecord::Base.connection
    rescue
      raise if Concurrent.monotonic_time >= (start_time + timeout)
      sleep delay
      delay *= 2
      retry
    end
  end

  task :schema_env => :load_config do
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).first
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(db_config).set_schema_file
  end
end

ActiveRecord::Tasks::PostgreSQLDatabaseTasks.prepend(Module.new do
  def set_schema_file
    clear_active_connections!
    establish_master_connection
    server_version = connection.select_value("SHOW server_version").to_i
    suffix = server_version < 11 ? '' : '-12'
    ENV['SCHEMA'] ||= "db/structure#{suffix}.sql"
    clear_active_connections!
  end
end)

%w[db:schema:dump db:schema:load db:prepare db:test:prepare].each do |taskname|
  Rake::Task[taskname].enhance(['db:schema_env'])
end
