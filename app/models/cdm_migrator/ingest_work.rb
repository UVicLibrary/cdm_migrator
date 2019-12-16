module CdmMigrator
  class IngestWork < ActiveRecord::Base

    def initialize(work, ingest_id)
      super({
        work_type: work[:type],
        data: work[:metadata],
        files: work[:files],
        batch_ingest_id: ingest_id
            })
    end

    serialize :data
    serialize :files
  end
end
