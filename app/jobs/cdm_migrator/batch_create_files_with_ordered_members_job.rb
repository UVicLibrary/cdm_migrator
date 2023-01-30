module CdmMigrator
  class BatchCreateFilesWithOrderedMembersJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    # From documentation at https://tinyurl.com/nh4c5e9j:
    #     When adding member {FileSetBehavior}s to a {WorkBehavior}, {Hyrax} saves
    #     and reloads the work for each new member FileSet. This can significantly
    #     slow down ingest for Works with many member FileSets. The saving and
    #     reloading happens in {FileSetActor#attach_to_work}.
    #     See the url for more details.

    #     With this job, the member association is saved once
    #     at the very end instead, which can speed up the upload process. This job takes
    #     advantage of the same strategy as Hyrax::Actors::FileSetOrderedMembersActor
    #     but you don't need the OrderedMembersActor constant initialized.

    # This rescue is a safeguard against creating lots of orphan file sets if there
    # are recurring errors (see https://tinyurl.com/nh4c5e9j). Instead, CdmMigrator
    # will fall back to creating file sets one-by-one if this job fails once.
    rescue_from(StandardError) do |exception|
      Rails.logger.error "BatchCreateFilesWithOrderedMembersJob error: #{exception.to_s}"
      RestartUploadFromMiddleJob.perform_later(arguments[0], arguments[1], arguments[2])
    end

    def perform work, ingest_work, user
        ordered_members = []
        ingest_work.files.each do |file|
          url = file[:url]
          last_file = ingest_work.files.last==file
          ::FileSet.new(import_url: url, label: file[:title]) do |fs|
            fs.attributes = file[:metadata]
            fs.save!
            ordered_members << fs
          end
        end
        actor = Hyrax::Actors::OrderedMembersActor.new(ordered_members, user)
        actor.attach_ordered_members_to_work(work)
        work.representative = work.ordered_members.to_a.first
        work.thumbnail_id = work.ordered_member_ids.first
        work.save!
        work.file_sets.each { |fs| CdmIngestFilesJob.perform_later(fs, fs.import_url, user, ingest_work) }
    end
    
  end
end