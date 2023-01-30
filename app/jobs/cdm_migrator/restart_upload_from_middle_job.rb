module CdmMigrator
  class RestartUploadFromMiddleJob < ActiveJob::Base

    # For restarting failed CdmMigrator::BatchCreateFilesJobs
    # from the middle instead of from the beginning (default
    # behaviour in Sidekiq). This prevents duplicating file
    # sets within a work.
    #
    retry_on Net::OpenTimeout, attempts: 20
    retry_on Errno::ECONNRESET, attempts: 20

    def perform(work, ingest_work, user)
      ordered_members = work.ordered_members.to_a
      last_file_set = ordered_members.last
      # If the last file set's file was never ingested, do that now
      if last_file_set.present? and last_file_set.files.none?
        CdmMigrator::CdmIngestFilesJob.perform_later(last_file_set, last_file_set.import_url, user)
      end
      files = ingest_work.files[ordered_members.length..-1]
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
          CdmMigrator::CdmIngestFilesJob.perform_later(fs, url, user, ingest_work, last_file)
        end
      end

    end
  end
end