class CdmMigrater::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)

  def inject_routes
    insert_into_file "config/routes.rb", after: ".draw do" do
      %(\n  mount CdmMigrater::Engine => '/cdm_migrater'\n)
    end
  end
end