module CdmMigrator
  class BatchIngest < ActiveRecord::Base
    serialize :data

    def initialize(works, csv, admin_set_id, collection_id, user)
      super({
        data: works,
        size: works.length,
        csv: csv,
        admin_set_id: admin_set_id,
        collection_id: collection_id,
        user_id: user.id
            })
    end

    def name
      csv.split('/').last.gsub(/[0-9]{10}/,"")
    end

    def progress
      if complete?
        "Complete"
      else
        completed = IngestWork.where(batch_ingest_id: id, complete: true ).length.to_s
        "#{completed}/#{size}"
      end
    end

    def username
      @username ||= User.find(user_id).name
    end

    def complete?
      self.complete
    end

    def message?
      not(message.nil?||message.empty?)
    end
  end
end
