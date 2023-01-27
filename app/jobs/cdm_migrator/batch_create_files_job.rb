module CdmMigrator
  class BatchCreateFilesJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform work, ingest_work, user
      unless work.ordered_members.to_a.empty?
        # This only executes if the job failed before adding any file sets and is now retrying
        ordered_members = work.ordered_members.to_a
        # If the last file set's file was never ingested, do that now
        last_file_set = ordered_members.last
        if last_file_set.present? and last_file_set.files.none?
          CdmMigrator::CdmIngestFilesJob.perform_later(last_file_set, last_file_set.import_url, user)
        end
        files = ingest_work.files[ordered_members.length..-1]
      else
        files = ingest_work.files
      end
      files.each do |file|
        url = file[:url]
        last_file = ingest_work.files.last==file
        ::FileSet.new(import_url: url, label: file[:title]) do |fs|
          fs.save
          actor = Hyrax::Actors::FileSetActor.new(fs, user)
          actor.create_metadata
          actor.attach_file_to_work(work)
          fs.attributes = file[:metadata]
          fs.save!
          CdmIngestFilesJob.perform_later(fs, url, user, ingest_work, last_file)
        end
      end
    end
  end
end