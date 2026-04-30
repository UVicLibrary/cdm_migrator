module CdmMigrator
  class IngestWork < ApplicationRecord

    serialize :data, coder: YAML
    serialize :files, coder: YAML
  end
end
