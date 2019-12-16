module CdmMigrator
  class Engine < ::Rails::Engine

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    #isolate_namespace CdmMigrator
    class << self

      def config
        file    = File.open(File.join(::Rails.root, "/config/cdm_migrator.yml"))
        @config ||= YAML.safe_load(file)
      end

      # loads a yml file with the configuration options
      #
      # @param file [String] path to the yml file
      #
      def load_config(file)
        @config = YAML.load_file(file)
      end
    end
  end
end
