# Rails Generator to generate Service objects

class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)
  check_class_collision suffix: 'Service'

  def copy_service_file
    template 'service.rb.erb', "app/services/#{file_name}_service.rb"
  end

  def copy_service_test_file
    template 'service_test.rb.erb', "test/services/#{file_name}_service_test.rb"
  end
end
