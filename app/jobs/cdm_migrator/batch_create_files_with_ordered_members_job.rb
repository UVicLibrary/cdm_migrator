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

    def perform work, ingest_work, user
      # Reload the work to get the most recent and accurate member associations
      work.reload
      if work.ordered_members.to_a.empty? && work.file_sets.empty?
        attach_files(work, ingest_work.files, user)
      else
        delete_excess_file_sets(work)
        ordered_count = work.reload.ordered_members.to_a.count
        unless ordered_count == ingest_work.files.count
          # Attach any files that might be missing
          files = ingest_work[ordered_count..]
          attach_files(work, files, user)
        end
      end
      first_file_set = work.ordered_members.to_a.first
      work.representative = first_file_set
      work.thumbnail = first_file_set
      work.save!
      work.file_sets.each { |fs| CdmIngestFilesJob.perform_later(fs, fs.import_url, user, ingest_work) }
    end

    private

    def attach_files(work, ingest_work_files, user)
      ingest_work_files.each do |file|
        url = file[:url]
        ordered_members = work.ordered_members
        # last_file = ingest_work.files.last==file
        ::FileSet.new(import_url: url, label: file[:title]) do |fs|
          fs.attributes = file[:metadata]
          fs.save!
          ordered_members << fs
        end
      end
      work.save!
      work.reload.ordered_members.to_a.each do |file_set|
        Hyrax.config.callback.run(:after_create_fileset, file_set, user, warn: false)
      end
    end

    # Sometimes when this job fails, file sets are attached to the work
    # without attaching them as ordered members. This creates "ghost files"
    # that don't show up in the interface but are still linked to the work as members
    def delete_excess_file_sets(work)
      ordered_members = work.ordered_members.to_a
      ghost_members = work.file_sets.select { |fs| ordered_members.exclude? fs }
      if ghost_members.any?
        # Unlink the file sets from the parent work first because it makes deleting them faster
        work.members = ordered_members
        work.save!
        ghost_members.each(&:destroy!)
      end
    end

  end
end