$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cdm_migrator/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cdm_migrator"
  s.version     = CdmMigrator::VERSION
  s.authors     = ["sephirothkod"]
  s.email       = ["bjustice@uvic.ca"]
  s.homepage    = "https://github.com/UVicLibrary/cdm_migrator"
  s.summary     = "ContentDM to Hyrax migrator."
  s.description = "Pulls ContentDM metadata and object links into a CSV. Then allows you to upload that CSV into Hyrax for automatic ingest. The CSV intermediate step is to allow for data refining or upload to another system."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.0.0"
  s.add_dependency "hyrax", "~> 1.0.0.rc1"

  s.add_development_dependency "engine_cart", '~> 1.1'
  s.add_development_dependency "therubyracer"
  s.add_development_dependency "rspec-rails"
end
