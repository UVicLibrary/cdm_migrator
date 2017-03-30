class CsvUploadJob < ActiveJob::Base
  queue_as Hyrax.config.ingest_queue_name
  
  
	def perform(csv, mvs, current_user)
		@csv = CSV.parse(File.read(csv), headers: true, encoding: 'utf-8').map(&:to_hash)
		@mvs = mvs
		@current_user = current_user
		@works = []
		@files = {}
		@csv.each do |row|
			type = row.first.last
			if type.nil?
			  next
			elsif(type.include? "Work")
				@works << row
				@files[@works.length] = []
			elsif(type.include? "File")
				row.delete("object_type")
				@files[@works.length] << row
			end
		end
		create_works
	end
	
	private
	
		def create_file_from_url(url, file_name, work, file_data)
			::FileSet.new(import_url: url, label: file_name) do |fs|
			  fs.save
				actor = Hyrax::Actors::FileSetActor.new(fs, @current_user)
				actor.create_metadata#(work, visibility: work.visibility)
				actor.attach_file_to_work(work)
				#byebug
				fs.attributes = file_data
				fs.save!
				uri = URI.parse(url.gsub(' ','%20'))
				if uri.scheme == 'file'
					IngestLocalFileJob.perform_later(fs, uri.path.gsub('%20',' '), @current_user)
				else
					ImportUrlJob.perform_later(fs, log(actor.user))
				end
			end
		end
		#
		def load_metadata(fs, file_array)
			file_array.each do |line|
				fileset = fs
				index = -1
				line.each do |data|
					index = index + 1
					next if index==0
					if @csv.headers[index] == "visibility"
						fileset.visibility = data
					elsif @csv.headers[index] == "depositor"
						fileset.depositor = data
					else
						data_arr = data.split @mvs
						fileset[@csv.headers[index]] = data_arr
					end
				end
				fileset.save
			end
		end

		def create_works
			index = 1
			@works.each do |work_data|
				work = Object.const_get(work_data.first.last).new#delete("object_type")).new
				status_after, embargo_date, lease_date = nil, nil, nil
				final_work_data = create_data work_data, "Hyrax::GenericWorkForm", work
				work.apply_depositor_metadata(@current_user)
				work.attributes = final_work_data
				work.save
				create_files(work, index)
				index+=1
			end
		end
	  
		def create_data data, type, object
		  final_data = {}
		  accepted_terms = Object.const_get(type).required_fields + Object.const_get(type).secondary_terms
      data.each do |key, att|
        if(att.nil? || att.empty? || key.to_s.include?("object_type") || !accepted_terms.include?(key.to_sym) )
          next
        elsif(object.send(key).nil?)
          final_data[key] = att
        else
          final_data[key] = att.split @mvs
        end
      end
      final_data
		end
		
		def create_lease visibility, status_after, date
		  lease = Hydra::AccessControls::Lease.new(visibility_during_lease: visibility,
						visibility_after_lease: @status_after, lease_expiration_date: @lease_date)
			lease.save
		end
		
		def create_embargo visibility
		  embargo = Hydra::AccessControls::Embargo.new
      embargo.visibility_during_embargo = visibility
      embargo.visibility_after_embargo = @status_after
      embargo.embargo_release_date = @embargo_date
      embargo.save
		end
		
		def create_files(work, index)
		  file = FileSet.new
			@files[index].each do |file_data|
				url = file_data.delete('url')
				title = file_data.delete('title')
				final_file_data = create_data file_data, "Hyrax::FileSetForm", file
				create_file_from_url(url, title, work, final_file_data)
			end
		end

    def log(user)
        Hyrax::Operation.create!(user: user,
                                            operation_type: "Attach Remote File")
    end 
end