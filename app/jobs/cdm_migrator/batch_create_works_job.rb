module CdmMigrator
  class BatchCreateWorksJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(ingest, user)
      ingest.data.each do |w|
        last_work = ingest.data.last==w
        ingest_work = IngestWork.new(w, ingest.id)
        ingest_work.save!
        CreateWorkJob.perform_later ingest_work, user, ingest.admin_set_id, ingest.collection_id, last_work
      end

    end
  end
end
