module CdmMigrator
  class CreateWorkJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(ingest_work, user, admin_set_id, collection_id, last_work=false)
      admin_set = ::AdminSet.find(admin_set_id) rescue nil
      collection = ::Collection.find(collection_id) rescue nil
      work = Object.const_get(ingest_work.work_type).new
      #status_after, embargo_date, lease_date = nil, nil, nil
      work.apply_depositor_metadata(user)
      work.attributes = ingest_work.data
      work.member_of_collections = [collection] if collection
      work.admin_set = admin_set if admin_set
      work.date_uploaded = DateTime.now
      work.save
      BatchCreateFilesJob.perform_later work, ingest_work, user, last_work

    end
  end
end