module CdmMigrator
  class IngestWork < ApplicationRecord

    serialize :data
    serialize :files
  end
end
