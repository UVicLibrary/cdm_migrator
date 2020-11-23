module CdmMigrator
  class CsvController < ApplicationController
    helper_method :default_page_title, :admin_host?, :available_translations, :available_works
    include ActionView::Helpers::UrlHelper
    layout 'hyrax/dashboard' if Hyrax
    before_action :authenticate, except: :index
    before_action :load_config, only: :csv_checker

    def csv_checker
      if params[:file]
        check_csv params[:file].path
        if @error_list.blank?
          flash[:notice] = "All data are valid."
        else
          flash[:error] = "The CSV Checker found some errors in the CSV. Please correct them and check again."
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
      @collections = Collection.all.map { |col| [col.title.first, col.id] }
    end

    def create
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
                                   admin_set_id:  params[:admin_set],
                                   collection_id: params[:collection],
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
      @collections = ::Collection.all.map { |c| [c.title.first, c.id] }
    end

    def update
      mvs = params[:csv_update][:mvs]
      csv = CSV.parse(params[:csv_update][:csv_file].read, headers: true, encoding: 'utf-8').map(&:to_hash)
      csv.each do |row|
        obj = ActiveFedora::Base.find row['id']
        type = row.first.last
        if type.nil?
          next
        elsif type.include? "Work"
          metadata = create_data(row.except('id', 'type'), work_form(type), obj, mvs)
        elsif type.include? "File"
          metadata = create_data(row.except('id', 'type'), work_form(type), obj, mvs)
        end
        unless metadata.nil?
          obj.attributes = metadata
          obj.save
        end
      end
      flash[:notice] = "csv successfully uploaded"
      redirect_to csv_edit_path
    end

    def export
      solr = RSolr.connect url: Account.find_by(tenant: Apartment::Tenant.current).solr_endpoint.url
      response = solr.get 'select', params: {
          q: "member_of_collection_ids_ssim:#{params[:collection_id]}",
          rows: 3400,
          fl: "id"
      }
      unless response['response']['docs'].empty? || response['response']['docs'][0].empty?
        work_ids = response['response']['docs'].map { |doc| doc['id'] }
      end
      #works    = ::ActiveFedora::Base.where member_of_collection_ids_ssim: params[:collection_id]
      @csv_headers = ['type'] + work_fields
      @csv_array   = [@csv_headers.join(',')]
      work_ids.each do |work_id|
        doc = ::SolrDocument.find work_id
        add_line doc
        doc._source[:file_set_ids_ssim].each do |file_id|
          file_doc = ::SolrDocument.find file_id
          add_line file_doc
        end
      end

      send_data @csv_array.join("\n"),
                :type => 'text/csv; charset=iso-8859-5; header=present',
                :disposition => "attachment; filename=export.csv"
    end

    private

      def authenticate
        authorize! :create, available_works.first
      end

      def add_line doc
        line_hash = {}
        line_hash['type'] = doc._source[:has_model_ssim].first
        work_fields.each do |field|
          line_hash[field] = create_cell doc, field
        end
        @csv_array << line_hash.values_at(*@csv_headers).map { |cell| cell = '' if cell.nil?; "\"#{cell.gsub("\"", "\"\"")}\"" }.join(',')

      end

      def work_fields
        @fields ||=  available_works.map { |work| work.new.attributes.keys }.flatten.uniq - excluded_fields
      end

      def excluded_fields
        %w[date_uploaded date_modified head tail state proxy_depositor on_behalf_of arkivo_checksum label
       relative_path import_url part_of resource_type access_control_id
       representative_id thumbnail_id rendering_ids admin_set_id embargo_id
       lease_id]
      end

      def create_cell w, field
        if field.include? 'date'
          if w._source[field+'_tesim'].is_a?(Array)
            w._source[field+'_tesim'].join('|')
          else
            w._source[field+'_tesim']
          end
        elsif w.respond_to?(field.to_sym)
          if w.send(field).is_a?(Array)
            w.send(field).join('|')
          else
            w.send(field)
          end
        end
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
      tenant = Account.find_by(tenant: Apartment::Tenant.current).cname
      if CdmMigrator::Engine.config['tenant_settings'].has_key?(tenant)
        settings = CdmMigrator::Engine.config['tenant_settings'][tenant]['csv_checker']
        if settings.present?
          # .map will throw an error if settings[key] has no value
          @edtf_fields = settings['edtf_fields'].map(&:to_sym) if settings['edtf_fields']
          @uri_fields = settings['valid_uri_fields'].map(&:to_sym) if settings['valid_uri_fields']
          @separator = settings['multi_value_separator']
          @separator_fields = settings['separator_fields'].map(&:to_sym) if settings['separator_fields']
          @path_to_drive = settings['path_to_drive']
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
        if row[:object_type].include? "Work"
          check_edtf(row_number, row) if @edtf_fields.present?
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
        else
          @error_list[row_number] = { "object_type" => "No or unknown object type. Please give a valid type (e.g. GenericWork, File)." }
        end
        @error_list.delete_if { |key, value| value.blank? } # Data are valid, no need to print the row
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

    def check_edtf(row_number, row)
      edtf_fields = @edtf_fields
      edtf_errors = edtf_fields.each_with_object({}) do |field, hash|
        temp_date = row[field]
        if temp_date
          # modify date so that the interval encompasses the years on the last interval date
          temp_date = temp_date.gsub('/..','').gsub('%','?~').gsub(/\/$/,'')
          date = temp_date.include?("/") ? temp_date.gsub(/([0-9]+X+\/)([0-9]+)(X+)/){"#{$1}"+"#{$2.to_i+1}"+"#{$3}"}.gsub("X","u") : temp_date
          date = date.gsub("XX-","uu-").gsub("X-", "u-").gsub('XX?','uu').gsub('X?', 'u').gsub('u?','u').gsub('?','')
          # edtf has trouble with year-month (e.g. "19uu-12") or year-season strings (e.g. "190u-23")
          # that contain unspecified years, or intervals containing the above ("19uu-22/19uu-23", etc.).
          # So we check for/create exceptions.
          # Check for season interval
          if Date.edtf(date) == nil and date != "unknown" # Accept season intervals
            unless is_season?(date.split("/").first) and is_season?(date.split("/").second)
              # If an interval then, check each date individually
              if date.include?("/")
                dates = date.split("/")
              else
                dates = [date]
              end
              dates.each do |d|
                # Dates with 'u' in the last digit of the year return invalid when in format YYYY-MM
                # So we flub day specifity before checking again if the date is valid
                unless Date.edtf(d + '-01') # Date.edtf('193u-03-01') returns valid
                  if match = d[/\d{3}u/] or match = d[/\d{2}u{2}-[2][1-4]/] # edtf can't parse single u in year (e.g. 192u) or uu in YYYY-SS (e.g. 19uu-21), so we replace it
                    d.gsub!(match, match.gsub("u","0"))
                    unless Date.edtf(d)
                      hash[field.to_s] = "Blank or not a valid EDTF date."
                    end
                  else
                    hash[field.to_s] = "Blank or not a valid EDTF date."
                  end
                end
              end
            end
          end
        end
      end
      @error_list[row_number] = edtf_errors
    end

    def is_season?(date)
      Date.edtf(date).class == EDTF::Season
    end

    # <Example: should be http://rightsstatements.org/vocab/etc. NOT https://rightsstatements.org/page/etc.
    def check_uris(row_number, row)
      uri_fields = @uri_fields
      uri_errors = uri_fields.each_with_object({}) do |field, hash|
        if row[field].include? "page"
          hash[field.to_s] = "Links to page instead of URI. (e.g. https://rightsstatements.org/page/etc. instead of http://rightsstatements.org/vocab/etc.)"
        end
      end
      @error_list[row_number].merge!(uri_errors)
    end

    # Check multi-value separators
    def check_multi_val_fields(row_number, row, character)
      uri_fields = @separator_fields
      separator_errors = uri_fields.each_with_object({}) do |field, hash|
        value = row[field]
        # Check for leading or trailing spaces
        if value.match %r{ #{Regexp.escape(character)}|#{Regexp.escape(character)} }
          hash[field.to_s] = "Contains leading or trailing whitespace around multi-value separator."
        end
        values.each do |val|
          if val.match(URI.regexp) # Val should be URI
            remainder = val.gsub(val.match(URI.regexp)[0],'')
            unless remainder.blank?
              hash[field.to_s] = "May contain the wrong multi-value separator or a typo in the URI."
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
      @error_list[row_number].merge!(separator_errors)
    end

      def default_page_title
        'CSV Batch Uploader'
      end

      def admin_host?
        false unless Settings.multitenancy.enabled
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
          elsif (object.send(key).nil?)
            final_data[key] = att
          else
            final_data[key] = att.split(mvs)
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
