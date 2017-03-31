class CdmMigrator::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)

  def inject_routes
    insert_into_file "config/routes.rb", after: ".draw do" do
      %(\n  mount CdmMigrator::Engine => '/cdm_migrator'\n)
    end
  end

  def inject_content_dm_yml
    copy_file "config/cdm_migrator.yml", "config/cdm_migrator.yml"
  end
end