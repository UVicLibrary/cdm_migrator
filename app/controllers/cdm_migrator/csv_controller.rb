module CdmMigrator
	class CsvController < ApplicationController
		helper_method :default_page_title, :admin_host?, :available_translations, :available_works
    include ActionView::Helpers::UrlHelper
		layout 'hyrax/dashboard' if Hyrax
    before_action :authenticate, except: :index

    def file_path_checker
     if params[:file]
       check_paths params[:file].path

       if @path_list.blank?
         flash[:notice] = "All file paths are valid."
       else
         flash[:error] = "Cdm Migrator couldn't find files at the following urls. Please correct the paths and try again."
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
			@admin_sets = AdminSet.all.map { |as| [as.title.first, as.id] }
			@collections = Collection.all.map { |col| [col.title.first, col.id] }
		end

		def create
			dir = Rails.root.join('public', 'uploads', 'csvs')
			FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
			time = DateTime.now.strftime('%s')
			filename = params[:csv_import][:csv_file].original_filename.gsub('.csv',"#{time}.csv")
      csv = dir.join(filename).to_s
			File.open(csv, 'wb') do |file|
			  file.write(params[:csv_import][:csv_file].read)
      end
      check_paths csv
      if @path_list.present?
        flash[:error] = "some file paths are invalid"
      end
      parse_csv(csv, params[:csv_import][:mvs])

      ingest = BatchIngest.new({
                                   data: @works,
                                   size: @works.length,
                                   csv: csv,
                                   admin_set_id: params[:admin_set],
                                   collection_id: params[:collection],
                                   user_id: current_user.id,
                                   message: @path_list.blank? ? nil : @path_list.to_s.gsub("\"","&quot;")
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
      headers = ['type','url']
      skip = ["id", "head", "tail", "depositor", "date_uploaded", "date_modified", "import_url", "thumbnail_id",
              "embargo_id", "lease_id", "access_control_id", "representative_id"]
      GenericWork.new.attributes.each do |key, val|
        headers << "work_#{key}" unless skip.include? key
      end
      FileSet.new.attributes.each do |key, val|
        headers << "file_#{key}" unless skip.include? key
      end
      fname = "template_#{DateTime.now.to_i}"
      render plain: CSV.generate { |csv| csv << headers }, content_type: 'text/csv'
    end
		
		private

      def authenticate
        authorize! :create, available_works.first
      end

      def available_works
        @available_works ||= Hyrax::QuickClassificationQuery.new(current_user).authorized_models
      end

      def parse_csv csv, mvs
        csv = CSV.parse(File.read(csv), headers: true, encoding: 'utf-8').map(&:to_hash)
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

      def check_paths csv_file
        row_number = 1 # +1 offset to account for csv headers
        @path_list = {}

        CSV.foreach(csv_file, headers: true, header_converters: :symbol) do |row|
          row_number +=1 # Tells user what CSV row the bogus file path is on
          next if row[:url].nil?
          file_path = row[:url]
          unless File.file?(file_path.gsub("file://", ""))
            @path_list[row_number] = file_path
          end
        end
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
        final_data = {}
        accepted_terms = type.required_fields + secondary_terms(type)
        data.each do |key, att|
          if(att.nil? || att.empty? || key.to_s.include?("object_type") || !accepted_terms.include?(key.to_sym) )
            next
          elsif(object.send(key).nil?)
            final_data[key] = att
          else
            final_data[key] = att.split(mvs)
          end
        end
        final_data
      end

			def create_lease visibility, status_after, date
				lease = Hydra::AccessControls::Lease.new(visibility_during_lease: visibility,
							visibility_after_lease: status_after, lease_expiration_date: @lease_date)
				lease.save
			end

			def create_embargo visibility
				embargo = Hydra::AccessControls::Embargo.new
				embargo.visibility_during_embargo = visibility
				embargo.visibility_after_embargo = @status_after
				embargo.embargo_release_date = @embargo_date
				embargo.save
			end

      def log(user)
          Hyrax::Operation.create!(user: user,
                                              operation_type: "Attach Remote File")
      end
	end
end
