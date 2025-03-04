module CdmMigrator
  class CreateWorkJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(ingest_work, user, admin_set_id, collection_id)
      admin_set = ::AdminSet.find(admin_set_id) rescue nil
      collection = Hyrax.config.collection_class.find(collection_id) rescue nil
      work = Object.const_get(ingest_work.work_type).new
      work.apply_depositor_metadata(user)
      work.attributes = ingest_work.data
      work.member_of_collections = [collection] if collection
      work.admin_set = admin_set if admin_set
      work.date_uploaded = DateTime.now
      add_configured_permissions(work)
      work.try(:to_controlled_vocab)
      begin
        work.save!
      # Weird error where descriptions with whitespace chars \n or \r don't save the 1st time
      # but do on the second
      rescue Ldp::BadRequest
        old_descr = work.description.clone.to_a
        work.description = work.description.map { |w| w.gsub("\n","").gsub("\r","") }
        work.save!
        work.description = old_descr
        work.save!
      end
      # Creating file (sets) with Hyrax::Actors::OrderedMembersActor is now the default.
      # To use the original Hyrax::Actors::FileSetActor, replace the line below with
      # BatchCreateFilesJob.perform_later(work, ingest_work, user)
      BatchCreateFilesWithOrderedMembersJob.perform_later(work, ingest_work, user)
    end

    private

    def add_configured_permissions(work)
      work_type = work.class
      return if configured_permissions.nil? # Nothing configured at all

      permissions_config = configured_permissions.dig(work_type.to_s)

      return if permissions_config.nil? # Nothing configured for this work type

      permissions = permissions_config.map do |permission_level, group_name|
        # Check if the permission level is configured in Hyrax
        raise "#{permission_level} permission is not configured in this repo. Is it set in Hyrax.config.permission_levels?" unless Hyrax.config.permission_levels.has_value?(permission_level)
        # Construct each permission as a hash
        group_name.map do |group|
          { name: group, type: "group", access: permission_level }
        end.flatten
      end.flatten

      # Finally, set the work's permissions_attributes
      work.permissions_attributes = permissions
    end

    # @return[Hash] - A hash like { "GenericWork"=> { "edit" => ["admin"], "download" => ["public"] } }
    def configured_permissions
      CdmMigrator::Engine.config.dig('default_work_permissions')
    end

  end
end