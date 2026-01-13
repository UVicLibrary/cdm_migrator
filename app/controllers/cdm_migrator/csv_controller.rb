module CdmMigrator
  class CsvController < ::ApplicationController

    layout 'hyrax/dashboard' if Hyrax

    before_action :authenticate, except: :index
    before_action :load_config, only: :csv_checker

    def csv_checker
      if params[:file]
        check_csv params[:file].path
        if @error_list.blank?
          redirect_to csv_checker_path, notice: "All data are valid."
        else
          flash[:error] = "The CSV Checker found some errors in the CSV. Please correct them and check again."
          render :csv_checker
        end
      end
    end

    def index
      if current_page?(main_app.csv_my_batches_path(locale: nil))
        @batches = BatchIngest.where(user_id: current_user.id).reverse_order
      elsif current_page?(main_app.csv_all_batches_path(locale: nil))
        @batches = BatchIngest.all.reverse_order
      else
        @batches = []
      end
    end

    def upload
      @admin_sets  = AdminSet.all.map { |as| [as.title.first, as.id] }
    end

    def create
      csv_upload_params
      dir = Rails.root.join('public', 'uploads', 'csvs')
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      time     = DateTime.now.strftime('%s')
      filename = params[:csv_import][:csv_file].original_filename.gsub('.csv', "#{time}.csv")
      csv      = dir.join(filename).to_s
      File.open(csv, 'wb') do |file|
        file.write(params[:csv_import][:csv_file].read)
      end
      check_csv csv
      if @error_list.present?
        flash[:error] = "Cdm Migrator found some problems with the CSV. Use the CSV Checker for more details."
      end
      parse_csv(csv, params[:csv_import][:mvs])

      ingest = BatchIngest.new({
                                 data:          @works,
                                 size:          @works.length,
                                 csv:           csv,
                                 admin_set_id:  params[:csv_import][:admin_set],
                                 collection_id: params[:csv_import][:collection],
                                 user_id:       current_user.id,
                                 message:       @path_list.blank? ? nil : @path_list.to_s.gsub("\"", "&quot;")
                               })
      if ingest.save! && @path_list.blank?
        BatchCreateWorksJob.perform_later(ingest, current_user)
        flash[:notice] = "csv successfully uploaded, check this page to see the status while the batch is running"
        redirect_to csv_my_batches_path
      else
        flash[:error] ||= "csv could not be parsed, please check and re-upload"
        redirect_to csv_upload_path
      end
    end

    def rerun
      ingest = BatchIngest.find(params[:id]).deep_dup
      ingest.save
      BatchCreateWorksJob.perform_later(ingest, current_user)
      flash[:notice] = "csv successfully uploaded, check this page to see the status while the batch is running"
      redirect_to csv_my_batches_path
    end

    def generate
      headers = %w(type url)
      skip    = %w(id head tail depositor date_uploaded date_modified import_url thumbnail_id embargo_id lease_id access_control_id representative_id)
      GenericWork.new.attributes.each do |key, val|
        headers << "work_#{key}" unless skip.include? key
      end
      FileSet.new.attributes.each do |key, val|
        headers << "file_#{key}" unless skip.include? key
      end
      fname = "template_#{DateTime.now.to_i}"
      render plain: CSV.generate { |csv| csv << headers }, content_type: 'text/csv'
    end

    def edit
      @collections = Hyrax.config.collection_class.all.map { |c| [c.title.first, c.id] }
    end

    def update
      mvs = params[:csv_update][:mvs]
      csv = CSV.parse(params[:csv_update][:csv_file].read.force_encoding("UTF-8"), headers: true, encoding: 'utf-8').map(&:to_hash)
      csv.each do |row|
        obj = ActiveFedora::Base.find row['id']
        type = row.first.last
        if type.nil?
          next
        elsif type.include? "Work"
          metadata = create_data(row.except('id', 'type'), work_form(type), obj, mvs)
        elsif type.include? "File"
          metadata = create_data(row.except('id', 'type'), file_form, obj, mvs)
        end
        unless metadata.nil?
          obj.attributes = metadata
          obj.try(:to_controlled_vocab)
          obj.save
        end
      end
      flash[:notice] = "csv successfully uploaded"
      redirect_to csv_edit_path
    end

    def export
      # Get a collection's member works from Solr
      solr = RSolr.connect url: Blacklight.connection_config[:url]
      response = solr.get 'select', params: {
        q: "member_of_collection_ids_ssim:#{params[:collection_id]}",
        fq: ["has_model_ssim:FileSet OR has_model_ssim:*Work"],
        rows: 3400,
        fl: "id"
      }
      unless response['response']['docs'].empty? || response['response']['docs'][0].empty?
        work_ids = response['response']['docs'].map { |doc| doc['id'] }
      end

      send_data CsvExportService.new(available_works).csv_for(work_ids),
                :type => 'text/csv; charset=iso-8859-5; header=present',
                :disposition => "attachment; filename=export.csv"
    end

    private

    def authenticate
      authorize! :create, available_works.first
    end

    def csv_upload_params
      params.require(:csv_import).permit(:csv_file, :mvs, :admin_set, :collection)
    end

    def available_works
      @available_works ||= Hyrax::QuickClassificationQuery.new(current_user).authorized_models
    end

    def parse_csv csv, mvs
      csv    = CSV.parse(File.read(csv), headers: true, encoding: 'utf-8').map(&:to_hash)
      @works = []
      csv.each do |row|
        type = row.first.last
        if type.nil?
          next
        elsif type.include? "Work"
          metadata = create_data(row, work_form(type), Object.const_get(type).new, mvs)
          @works << {type: type, metadata: metadata, files: []}
        elsif type.include? "File"
          metadata = create_data(row, file_form, FileSet.new, mvs)
          @works.last[:files] << {url: row.delete('url'), title: row.delete('title'), metadata: metadata}
        end
      end
    end

    def load_config
      # multitenant? defined in ApplicationController
      if multitenant?
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

    def check_csv csv_file
      row_number = 1
      @error_list = {}
      check_mounted_drive if @path_to_drive.present?

      CSV.foreach(csv_file, headers: true, header_converters: :symbol) do |row|
        row_number +=1 # Tells user what CSV row the error is on
        if row[:object_type].try(:include?, "Work")
          check_dates(row_number, row) if @date_fields.present?
          check_uris(row_number, row) if @uri_fields.present?
          if params[:multi_value_separator].present? and @separator_fields.present?
            check_multi_val_fields(row_number, row, params[:multi_value_separator])
          else
            alert_message = "No multi-value separator character was selected or no fields were configured. CSV Checker didn't check for valid separators."
            if flash[:alert] and flash[:alert].exclude?(alert_message) # Only add this message once, rather than per line
              flash[:alert] << alert_message
            elsif flash[:alert].blank?
              flash[:alert] = Array.wrap(alert_message)
            end
          end
        elsif row[:object_type] == "File"
          check_file_path(row_number, row[:url])
          check_transcript_length(row_number, row[:transcript]) if row[:transcript].present?
          check_file_size(row_number, row[:url])
        else
          @error_list[row_number] = { "object_type" => "No or unknown object type. Please give a valid type (e.g. GenericWork, File)." }
        end
        @error_list.delete_if { |key, value| value.blank? } # Data are valid, no need to print the row
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

    def check_file_size(row_number, file_path)
      if file_path.present? && File.file?(file_path) && @max_file_size
        if File.size(file_path.gsub("file://", "")) > @max_file_size
          @error_list[row_number] = { "file size" => "The file at #{file_path} is too large to be uploaded. Please compress the file or split it into parts.
                                                  Each part should be under #{helpers.number_to_human_size(@max_file_size)}." }
        end
      end
    end

    def check_mounted_drive
      drive_address = @path_to_drive
      unless Dir.exist?(drive_address) and !Dir[drive_address].empty?
        flash[:alert] = "CSV Checker can't find the mounted drive to check file paths, so some paths may be mislabelled as incorrect. Please contact the administrator or try again later."
      end
    end

    def check_file_path(row_number, file_path)
      if file_path.nil?
        @error_list[row_number] = { "url" => "url is blank." }
      elsif File.file?(file_path.gsub("file://", "")) == false
        @error_list[row_number] = { "url" => "No file found at #{file_path}" }
      end
    end

    def check_dates(row_number, row)
      date_fields = @date_fields
      unless @date_indexing_service
        flash[:alert] = "No date indexing service was configured so CSV Checker didn't validate dates."
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
            if val.match(URI::DEFAULT_PARSER.make_regexp) # Val should be URI
              remainder = val.gsub(val.match(URI::DEFAULT_PARSER.make_regexp)[0],'')
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

    def default_page_title
      'CSV Batch Uploader'
    end

    def admin_host?
      # multitenant? defined in ApplicationController
      false unless multitenant?
    end

    def available_translations
      {
        'en' => 'English',
        'fr' => 'French'
      }
    end

    def work_form(worktype = "GenericWork")
      Module.const_get("Hyrax::#{worktype}Form") rescue nil || Module.const_get("Hyrax::Forms::WorkForm")
    end

    def file_form
      Module.const_get("Hyrax::FileSetForm") rescue nil || Module.const_get("Hyrax::Forms::FileSetEditForm")
    end

    def secondary_terms form_name
      form_name.terms - form_name.required_fields -
        [:visibility_during_embargo, :embargo_release_date,
         :visibility_after_embargo, :visibility_during_lease,
         :lease_expiration_date, :visibility_after_lease, :visibility,
         :thumbnail_id, :representative_id, :ordered_member_ids,
         :collection_ids, :in_works_ids, :admin_set_id, :files, :source, :member_of_collection_ids]
    end

    def create_data data, type, object, mvs
      final_data     = {}
      accepted_terms = type.required_fields + secondary_terms(type)
      data.each do |key, att|
        if (att.nil? || att.empty? || key.to_s.include?("object_type") || !accepted_terms.include?(key.to_sym))
          next
        elsif object.send(key).nil?
          final_data[key] = att
        else
          if object.class.properties[key.to_s].multiple?
            final_data[key] = att.split(mvs)
          else
            final_data[key] = att
          end
        end
      end
      final_data
    end

    def create_lease visibility, status_after, date
      lease = Hydra::AccessControls::Lease.new(visibility_during_lease: visibility,
                                               visibility_after_lease:  status_after, lease_expiration_date: @lease_date)
      lease.save
    end

    def create_embargo visibility
      embargo                           = Hydra::AccessControls::Embargo.new
      embargo.visibility_during_embargo = visibility
      embargo.visibility_after_embargo  = @status_after
      embargo.embargo_release_date      = @embargo_date
      embargo.save
    end

    def log(user)
      Hyrax::Operation.create!(user:           user,
                               operation_type: "Attach Remote File")
    end
  end
end
