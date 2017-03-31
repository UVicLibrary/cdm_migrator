# Generated via
#  `rails generate curation_concerns:work GenericWork`
module Hyrax
  class GenericWorkForm < Hyrax::Forms::WorkForm
    self.model_class = ::GenericWork
    include HydraEditor::Form::Permissions
    self.terms += [:resource_type, :alternative_title, :edition, :geographic_coverage, :coordinates, :chronological_coverage, :extent, :additional_physical_characteristics, :has_format, :physical_repository, :collection, :provenance, :provider, :sponsor, :genre, :format, :archival_item_identifier, :fonds_title, :fonds_creator, :fonds_description, :fonds_identifier, :is_referenced_by, :date_digitized, :transcript, :technical_note, :year]
    self.required_fields += [:date_created, :subject, :collection, :provider, :genre, :format, :resource_type] 
    self.required_fields -= [:keyword] 
    def self.secondary_terms
        terms - required_fields -
          [:files, :visibility_during_embargo, :embargo_release_date,
           :visibility_after_embargo, :visibility_during_lease,
           :lease_expiration_date, :visibility_after_lease, :visibility,
           :thumbnail_id, :representative_id, :ordered_member_ids,
           :collection_ids, :in_works_ids, :admin_set_id]
      end
  end
end
