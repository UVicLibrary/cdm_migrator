module CdmMigrator
  class BatchIngest < ActiveRecord::Base
    serialize :data

    def name
      csv.split('/').last.gsub(/[0-9]{10}/,"")
    end

    def progress
      return "Complete" if complete?
      completed = IngestWork.where(batch_ingest_id: id, complete: true ).length
      if completed==data.length
        complete=true
        save
        "Complete"
      else
        "#{completed.to_s}/#{size}"
      end
    end

    def username
      @username ||= User.find(user_id).name
    end

    def complete?
      complete
    end

    def message?
      not(message.nil?||message.empty?)
    end
  end
end
