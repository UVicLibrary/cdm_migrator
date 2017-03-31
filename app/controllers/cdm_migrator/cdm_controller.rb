module CdmMigrator
	class CdmController < ApplicationController

		def initialize
			super
			@cdm_url = CdmMigrator::Engine.config["cdm_url"]
			@cdm_port = CdmMigrator::Engine.config["cdm_port"]
			@terms = Hyrax::FileSetForm.primary_terms + Hyrax::FileSetForm.secondary_terms
		end
		
		before_action :set_exclusive_fields, only: [:generate, :mappings]
		
		def set_exclusive_fields
		  work_form = "Hyrax::#{params[:work]}Form".split('::').inject(Object) {|o,c| o.const_get c}
			@work_only = work_form.required_fields + work_form.new(params[:work].constantize.new,nil,nil).secondary_terms - @terms
		end

		def generate
			@h_to_c = {}
			@c_to_h = {}
			params[:mappings].each do |key, mapping|
				if !mapping['hydra'].empty?
					@c_to_h[mapping['cdm']] = mapping['hydra']
					@h_to_c[mapping['hydra']] ||= []
					@h_to_c[mapping['hydra']] << mapping['cdm']
				elsif !mapping['hydrac'].empty?
					@c_to_h[mapping['cdm']] = mapping['hydrac']
					@h_to_c[mapping['hydrac']] ||= []
					@h_to_c[mapping['hydrac']] << mapping['cdm']
				end
			end
			json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmQuery/#{params[:collection]}/0/0/filetype/1024/0/0/0/0/0/1/0/json")).body)
			total_recs = json["pager"]["total"].to_i

			if total_recs > 1024
				start = 1
				records = []
				[0..(total_recs/1024)].each do |index|
					start = (index*1024) + 1
					json = JSON.parse(Net::HTTP.get_response(URI.parse("http://#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmQuery/#{params[:collection]}/0/0/filetype/1024/#{start}/0/0/0/0/1/0/json")).body)
					records << json["records"].map { |rec| [rec['pointer'], rec['filetype']] }
				end
			else
				records = json["records"].map { |rec| [rec['pointer'], rec['filetype']] }
			end
			headers = CSV.generate_line (['object_type','url']+@terms+@work_only)
			csv_lines = [] << headers
			records.each do |rec|
				if rec.last == "cpd"
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{rec.first}/json")).body)
					csv_lines << create_line("GenericWork","",json)
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCompoundObjectInfo/#{params[:collection]}/#{rec.first}/json")).body)
					json['page'].each do |child|
						child_json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{child['pageptr']}/json")).body)
						url = "http://#{@cdm_url}/utils/getfile/collection/#{params[:collection]}/id/#{rec.first}/filename/#{child['pageptr']}.#{child['find']}"#"file://#{file_path(rec.first)}"
						#url = "file://#{file_path(child['pageptr'])}"
						csv_lines << create_line("File",url,child_json)
					end
				else
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{rec.first}/json")).body)
					csv_lines << create_line("GenericWork","",json)
					url = "http://#{@cdm_url}/utils/getfile/collection/#{params[:collection]}/id/#{rec.first}/filename/#{rec.first}.#{rec.last}"#"file://#{file_path(rec.first)}"
					csv_lines << create_line("File",url,{})
				end
			end
			render plain: csv_lines.join, content_type: 'text/csv'

		end

		def mappings
			json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCollectionFieldInfo/"+params['collection']+'/json')).body)
			@cdm_terms = json.collect { |c| [c['name'],c['nick']] }
			#@dirs = get_dirs
		end

		def collection
			json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCollectionList/json")).body)
			@collections = json.collect { |c| [c['name'],c['secondary_alias']] }
			@available_concerns = Hyrax.config.curation_concerns.map { |c| [c.to_s, c.to_s]}
		end

		protected

			def create_line type, url, json
				line = [] << type
				line << url
				(@terms+@work_only).each do |term|
					content = []
					unless @h_to_c[term.to_s].nil?
						@h_to_c[term.to_s].each do |cdm_term|
							content << json[cdm_term] unless json[cdm_term].nil?
						end
						content.delete_if(&:empty?)
					end
					if content.nil? || content.empty? || content == [{}]
						line << ""
					else
						line << content.join('|')
					end
				end
				CSV.generate_line line
			end

			def file_path pointer
				file_types = ['tif','jpg','mp4','mp3']
				files = []
				file_types.each do |type|
					files << Dir.glob("/APP_ROOT/tmp/uploads/local_files/#{params['mappings_url']}/**/#{pointer}_*#{type}")
				end
				files.each do |file|
					return file.first if file.count > 0
				end
			end

			def get_dirs
				cat = Dir.entries('/APP_ROOT/tmp/uploads/local_files/Cataloguing').select {|entry| File.directory? File.join('/APP_ROOT/tmp/uploads/local_files/Cataloguing',entry) and !(entry =='.' || entry == '..') }
				cat = cat.map { |url| "Cataloguing/#{url}" }
				sc = Dir.entries('/APP_ROOT/tmp/uploads/local_files/Special Collections').select {|entry| File.directory? File.join('/APP_ROOT/tmp/uploads/local_files/Special Collections',entry) and !(entry =='.' || entry == '..') }
				sc = sc.map { |url| "Special Collections/#{url}" }
				cat + sc
			end
	end
end