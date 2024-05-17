module CdmMigrator
  class CsvExportService

    # A service for exporting work and file set metadata to a csv. You can customize headers/fields by
    # overriding the included_fields method below. You can also specify different work types by changing/overriding
    # the available_work_types method.

    # @param [Array <Class>] - the available work types, passed in from the controller, such as GenericWork
    def initialize(work_types)
      @work_types = work_types
    end

    # @param [Array <String>] - the work ids (for GenericWork or other work type) to export metadata for
    # @param [String] - where to save the csv file to (filepath)
    def write_to_csv(work_ids, filepath)
      File.open(filepath, 'w') { |file| file.write(rows_for(work_ids).map(&:to_csv).join) }
    end

    def csv_for(work_ids)
      rows_for(work_ids).map(&:to_csv).join
    end

    # @param [Array <String>] - the work ids (for GenericWork or other work type) to export metadata for
    # @return [Array <Array>] - An array of arrays where each nested array contains the metadata
    # for a work or file set and corresponds to a csv row.
    def rows_for(work_ids)
      csv_array = [csv_headers]
      work_ids.each_with_object(csv_array).each do |work_id|
        doc = ::SolrDocument.find work_id
        csv_array << row_for(doc)
        doc._source[:file_set_ids_ssim].each do |file_id|
          file_doc = ::SolrDocument.find file_id
          csv_array << row_for(file_doc)
        end
      end
    end

    # @param [SolrDocument] - Any model that has the properties listed in #included_fields (e.g. GenericWork, FileSet)
    # @return [Array <String>] - the csv row for the given document
    def row_for(document)
      line_hash = {}
      line_hash['type'] = document._source[:has_model_ssim].first
      included_fields.each do |field|
        line_hash[field] = create_cell document, field
      end
      line_hash.values_at(*csv_headers).map { |cell| cell.blank? ? '' : cell }
    end

    private

    # @return [Array <String>]
    def included_fields
      @work_types.map { |work| work.new.attributes.keys }.flatten.uniq - excluded_fields
    end

    def excluded_fields
      %w[date_uploaded date_modified head tail state proxy_depositor on_behalf_of arkivo_checksum label
       relative_path import_url part_of resource_type access_control_id
       representative_id thumbnail_id rendering_ids admin_set_id embargo_id
       lease_id]
    end

    # @param [SolrDocument] - the document to create a cell for
    # @param [String or Symbol] - the name of the field
    # NOTE: any fields you want to include must also be added to the SolrDocument model as methods
    # because of the check for respond_to?
    def create_cell document, field
      properties = document.hydra_model.properties
      if document.respond_to?(field.to_sym)
        if properties.keys.include?(field) && properties[field].multiple?
          document.send(field).join('|')
        else
          document.send(field)
        end
      end
    end

    # @return [Array <String>] - the heaaders for the csv
    def csv_headers
      ['type'] + included_fields
    end

  end
end