module CdmMigrator
  class UpdateObjectJob < ActiveJob::Base


    def perform(attributes)
      obj = ActiveFedora::Base.find

    end
  end
end
