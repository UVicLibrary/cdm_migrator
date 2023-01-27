module CdmMigrator
  class CreateWorkJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(ingest_work, user, admin_set_id, collection_id)
      admin_set = ::AdminSet.find(admin_set_id) rescue nil
      collection = ::Collection.find(collection_id) rescue nil
      work = Object.const_get(ingest_work.work_type).new
      #status_after, embargo_date, lease_date = nil, nil, nil
      work.apply_depositor_metadata(user)
      work.attributes = ingest_work.data
      if ingest_work.data.has_key? 'downloadable'
        # Convert string to boolean
        work.downloadable = ActiveModel::Type::Boolean.new.cast(ingest_work.data['downloadable'])
      elsif work.attributes.include? 'downloadable' # Set work to downloadable by default
        work.downloadable = true
      end
      work.member_of_collections = [collection] if collection
      work.admin_set = admin_set if admin_set
      work.date_uploaded = DateTime.now
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
      BatchCreateFilesJob.perform_later(work, ingest_work, user)
    end
  end
end