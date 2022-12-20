module CdmMigrator
  class BatchCreateWorksJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(ingest, user)
      ingest.data.each do |w|
        ingest_work = IngestWork.new({
           work_type: w[:type],
           data: w[:metadata],
           files: w[:files],
           batch_ingest_id: ingest.id
        })
        ingest_work.save!
        # puts ingest_work.inspect
        CreateWorkJob.perform_later ingest_work, user, ingest.admin_set_id, ingest.collection_id
      end

    end
  end
end
