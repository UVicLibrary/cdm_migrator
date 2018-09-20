

module CdmMigrator
  class Engine < ::Rails::Engine

    isolate_namespace CdmMigrator
    class << self
      
      def config
        file = File.open(File.join(::Rails.root, "/config/cdm_migrator.yml"))
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
