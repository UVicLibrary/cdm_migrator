module CdmMigrator
  class BatchCreateFilesJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform work, ingest_work, user
      ingest_work.files.each do |file|
        url = file[:url]
        last_file = ingest_work.files.last==file
        ::FileSet.new(import_url: url, label: file[:title]) do |fs|
          fs.save
          actor = Hyrax::Actors::FileSetActor.new(fs, user)
          actor.create_metadata#(work, visibility: work.visibility)
          actor.attach_file_to_work(work)
          fs.attributes = file[:metadata]
          fs.save!
          CdmIngestFilesJob.perform_later(fs, url, user, ingest_work, last_file)
        end
      end
    end
  end
end