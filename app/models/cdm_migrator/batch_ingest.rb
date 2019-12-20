module CdmMigrator
  class BatchIngest < ActiveRecord::Base
    serialize :data

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
