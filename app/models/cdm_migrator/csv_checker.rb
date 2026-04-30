module CdmMigrator
  class CsvChecker
    
    def initialize
      load_config
    end
    
    # @param[String] - the path to the CSV
    # @return [Hash] - where hash['errors'] is a list of errors found in the csv,
    #                  and hash['alerts'] are warnings to display to the user
    def check_csv(csv, multi_value_separator = "|")
      @csv = csv
      row_number = 1

      results = {}
      @error_list = {}
      @alerts = []

      check_mounted_drive if @path_to_drive.present?
      
      CSV.foreach(csv, headers: true, header_converters: :symbol) do |row|
        row_number +=1 # Tells user what CSV row the error is on
        if row[:object_type].try(:include?, "Work")
          check_dates(row_number, row) if @date_fields.present?
          check_uris(row_number, row) if @uri_fields.present?
          if @separator_fields.present?
            check_multi_val_fields(row_number, row, multi_value_separator)
          else
            alert_message = "No multi-value separator character was selected or no fields were configured. CSV Checker didn't check for valid separators."
            if @alerts.exclude?(alert_message) # Only add this message once, rather than per line
             @alerts << alert_message
            end
          end
        elsif row[:object_type] == "File"
          check_file_path(row_number, row[:url])
          check_transcript_length(row_number, row[:transcript]) if row[:transcript].present?
          check_file_size(row_number, row[:url])
        else
          @error_list[row_number] = { "object_type" => "No or unknown object type. Please give a valid type (e.g. GenericWork, File)." }
          @error_list = @error_list.delete_if { |_, value| value.blank? } # Data are valid, no need to print the row
        end
      end
      results['errors'] = @error_list
      results['alerts'] = @alerts
      results
    end
    
    private

    def work_form(worktype = "GenericWork")
      Module.const_get("Hyrax::#{worktype}Form") rescue nil || Module.const_get("Hyrax::Forms::WorkForm")
    end

    def file_form
      Module.const_get("Hyrax::FileSetForm") rescue nil || Module.const_get("Hyrax::Forms::FileSetEditForm")
    end
    
    def check_file_path(row_number, file_path)
      if file_path.nil?
        @error_list[row_number] = { "url" => "url is blank." }
      elsif File.file?(file_path.gsub("file://", "")) == false
        @error_list[row_number] = { "url" => "No file found at #{file_path}" }
      end
    end
    
    def check_mounted_drive
      drive_address = @path_to_drive
      unless Dir.exist?(drive_address) and !Dir[drive_address].empty?
        @alerts << "CSV Checker can't find the mounted drive to check file paths, so some paths may be mislabelled as incorrect. Please contact the administrator or try again later."
      end
    end

    def check_dates(row_number, row)
      date_fields = @date_fields
      unless @date_indexing_service
        @alerts << "No date indexing service was configured so CSV Checker didn't validate dates."
        return
      end
      edtf_errors = date_fields.each_with_object({}) do |field, hash|
        next unless row[field]
        begin
          @date_indexing_service.new(row[field])
        rescue *@date_indexing_service.error_classes => error
          hash[field.to_s] = "#{error.message}"
        end
      end
      @error_list[row_number] = edtf_errors
    end

    # <Example: should be http://rightsstatements.org/vocab/etc. NOT https://rightsstatements.org/page/etc.
    def check_uris(row_number, row)
      uri_fields = @uri_fields
      uri_errors = uri_fields.each_with_object({}) do |field, hash|
        if row[field] and row[field].include? "page"
          hash[field.to_s] = "Links to page instead of URI. (e.g. https://rightsstatements.org/page/etc. instead of http://rightsstatements.org/vocab/etc.)"
        elsif row[field] and row[field].match?("https://vocab.getty")
          hash[field.to_s] = "Getty AAT URIs should use http instead of https"
        elsif field == :language
          unless row[field].match?("http://id.loc.gov/vocabulary/iso639-3")
            hash[field.to_s] = "Value doesn't look like a Library of Congress ISO639-3 URI. Is it a URI that starts with http://id.loc.gov/vocabulary/iso639-3?"
          end
        end
      end
      if @error_list[row_number].present?
        @error_list[row_number].merge!(uri_errors)
      else
        @error_list[row_number] = uri_errors
      end
    end

    # Check multi-value separators
    def check_multi_val_fields(row_number, row, character)
      uri_fields = @separator_fields
      separator_errors = uri_fields.each_with_object({}) do |field, hash|
        if value = row[field]
          # Check for leading or trailing spaces
          if value.match %r{ #{Regexp.escape(character)}|#{Regexp.escape(character)} }
            hash[field.to_s] = "Contains leading or trailing whitespace around multi-value separator."
          end
          values = value.split(character).map(&:strip)
          values.each do |val|
            if val.match(URI::RFC2396_PARSER.make_regexp) # Val should be URI
              remainder = val.gsub(val.match(URI::RFC2396_PARSER.make_regexp)[0],'')
              unless remainder.blank?
                hash[field.to_s] = "May contain the wrong multi-value separator or a typo in the URI."
              end
              if field != :genre && field != :resource_type
                unless val.match(/\bhttps?:\/\/id.worldcat.org\/fast\/\d+\b/)
                  hash[field.to_s] = "Field may contain an invalid URI or is missing a separator between URIs."
                end
              end
            else # Or val should be string
              invalid_chars = ["\\"]
              # Make exceptions for backslashes that are part of whitespace characters
              # by deleting them before checking for stray \s
              if val.delete("\t\r\n\s\n").match Regexp.union(invalid_chars)
                hash[field.to_s] = "May contain an invalid character such as #{invalid_chars.to_sentence(last_word_connector: ", or ")}."
              end
            end
          end
        end
      end
      @error_list[row_number].merge!(separator_errors)
    end
    
    def check_file_size(row_number, file_path)
      if file_path.present? && File.file?(file_path) && @max_file_size
        if File.size(file_path.gsub("file://", "")) > @max_file_size
          @error_list[row_number] = { "file size" => "The file at #{file_path} is too large to be uploaded. Please compress the file or split it into parts.
                                                  Each part should be under #{helpers.number_to_human_size(@max_file_size)}." }
        end
      end
    end

    def check_transcript_length(row_number, transcript)
      if transcript.is_a? String
        if transcript.length > 9000
          @error_list[row_number] = { "transcript" => "Transcript is too long (over 9000 characters)." }
        end
      elsif transcript.is_a? Array
        if transcript.any? { |tr| tr.length > 9000 }
          @error_list[row_number] = { "transcript" => "Transcript is too long (over 9000 characters)." }
        end
      end
    end
    
    def load_config
      if ENV['HYKU_MULTITENANT']
        tenant = Account.find_by(tenant: Apartment::Tenant.current).cname
      else
        tenant = "default"
      end
      
      if CdmMigrator::Engine.config['tenant_settings'].has_key?(tenant)
        settings = CdmMigrator::Engine.config['tenant_settings'][tenant]['csv_checker']
        if settings.present?
          @date_indexing_service = settings['date_indexing_service'].first.constantize if settings['date_indexing_service']
          @date_fields = settings['date_fields'].map(&:to_sym) if settings['date_fields']
          @uri_fields = settings['valid_uri_fields'].map(&:to_sym) if settings['valid_uri_fields']
          @separator = settings['multi_value_separator']
          @separator_fields = settings['separator_fields'].map(&:to_sym) if settings['separator_fields']
          @path_to_drive = settings['path_to_drive']
          # If you would like to change this to match the uploader's max file size,
          # change this to Hyrax.config.uploader[:maxFileSize]
          @max_file_size = settings['max_file_size']
        else
          raise "Cdm Migrator couldn't find any configured settings. Are they in cdm_migrator.yml?"
        end
      else
        raise "Cdm Migrator couldn't find this tenant. Is it configured?"
      end
    end
    
  end
end