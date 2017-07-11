# -*- encoding: utf-8 -*-
# stub: cdm_migrator 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "cdm_migrator"
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["sephirothkod"]
  s.date = "2017-07-04"
  s.description = "Pulls ContentDM metadata and object links into a CSV. Then allows you to upload that CSV into Hyrax for automatic ingest. The CSV intermediate step is to allow for data refining or upload to another system."
  s.email = ["bjustice@uvic.ca"]
  s.files = ["MIT-LICENSE", "README.md", "Rakefile", "app/assets", "app/assets/config", "app/assets/config/cdm_migrator_manifest.js", "app/assets/images", "app/assets/images/cdm_migrator", "app/assets/javascripts", "app/assets/javascripts/cdm_migrator", "app/assets/javascripts/cdm_migrator/application.js", "app/assets/stylesheets", "app/assets/stylesheets/cdm_migrator", "app/assets/stylesheets/cdm_migrator/application.css", "app/controllers", "app/controllers/cdm_migrator", "app/controllers/cdm_migrator/application_controller.rb", "app/controllers/cdm_migrator/cdm_controller.rb", "app/controllers/cdm_migrator/csv_controller.rb", "app/helpers", "app/helpers/cdm_migrator", "app/helpers/cdm_migrator/application_helper.rb", "app/jobs", "app/jobs/cdm_migrator", "app/jobs/cdm_migrator/application_job.rb", "app/jobs/csv_upload_job.rb", "app/mailers", "app/mailers/cdm_migrator", "app/mailers/cdm_migrator/application_mailer.rb", "app/models", "app/models/cdm_migrator", "app/models/cdm_migrator/application_record.rb", "app/views", "app/views/cdm_migrator", "app/views/cdm_migrator/cdm", "app/views/cdm_migrator/cdm/collection.html.erb", "app/views/cdm_migrator/cdm/mappings.html.erb", "app/views/cdm_migrator/csv", "app/views/cdm_migrator/csv/upload.html.erb", "app/views/layouts", "app/views/layouts/cdm_migrator", "app/views/layouts/cdm_migrator/application.html.erb", "config/routes.rb", "lib/cdm_migrator", "lib/cdm_migrator.rb", "lib/cdm_migrator/engine.rb", "lib/cdm_migrator/version.rb", "lib/generators", "lib/generators/cdm_migrator", "lib/generators/cdm_migrator/install", "lib/generators/cdm_migrator/install/install_generator.rb", "lib/generators/cdm_migrator/install/templates", "lib/generators/cdm_migrator/install/templates/config", "lib/generators/cdm_migrator/install/templates/config/cdm_migrator.yml", "lib/tasks", "lib/tasks/cdm_migrator_tasks.rake"]
  s.homepage = "https://github.com/UVicLibrary/cdm_migrator"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.5.1"
  s.summary = "ContentDM to Hyrax migrator."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, ["~> 5.0"])
      s.add_runtime_dependency(%q<hyrax>, ["> 1.0.0.rc1"])
      s.add_development_dependency(%q<engine_cart>, ["~> 1.1"])
      s.add_development_dependency(%q<therubyracer>, [">= 0"])
      s.add_development_dependency(%q<rspec-rails>, [">= 0"])
    else
      s.add_dependency(%q<rails>, ["~> 5.0"])
      s.add_dependency(%q<hyrax>, ["> 1.0.0.rc1"])
      s.add_dependency(%q<engine_cart>, ["~> 1.1"])
      s.add_dependency(%q<therubyracer>, [">= 0"])
      s.add_dependency(%q<rspec-rails>, [">= 0"])
    end
  else
    s.add_dependency(%q<rails>, ["~> 5.0"])
    s.add_dependency(%q<hyrax>, ["> 1.0.0.rc1"])
    s.add_dependency(%q<engine_cart>, ["~> 1.1"])
    s.add_dependency(%q<therubyracer>, [">= 0"])
    s.add_dependency(%q<rspec-rails>, [">= 0"])
  end
end
