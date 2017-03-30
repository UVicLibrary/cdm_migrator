module CdmMigrater
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
