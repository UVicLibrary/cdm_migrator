module CdmMigrater
  class Engine < ::Rails::Engine

    isolate_namespace CdmMigrater
    class << self
      attr_accessor :config

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
