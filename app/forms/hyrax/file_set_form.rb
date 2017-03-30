module Hyrax
  class FileSetForm < Hyrax::Forms::FileSetEditForm
    self.model_class = ::GenericWork
    include HydraEditor::Form::Permissions
    self.terms += [:resource_type, :alternative_title, :geographic_coverage, :coordinates, :chronological_coverage, :extent, :additional_physical_characteristics, :has_format, :physical_repository, :provenance, :provider, :sponsor, :genre, :format, :is_referenced_by, :date_digitized, :transcript, :technical_note, :year]
    self.required_fields += [:date_created, :subject, :provider, :genre, :format, :resource_type] 
    self.required_fields -= [:keyword] 
    
    # Fields that are automatically drawn on the page above the fold
      def self.primary_terms
        required_fields
      end

      # Fields that are automatically drawn on the page below the fold
      def self.secondary_terms
        terms - primary_terms -
          [:visibility_during_embargo, :embargo_release_date,
           :visibility_after_embargo, :visibility_during_lease,
           :lease_expiration_date, :visibility_after_lease, :visibility,
           :thumbnail_id, :representative_id, :ordered_member_ids,
           :collection_ids, :in_works_ids, :admin_set_id]
      end
  end
end