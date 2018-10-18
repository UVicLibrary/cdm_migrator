module CdmMigrator
	class CdmController < ApplicationController

		require 'csv'

		before_action :load_yaml
		before_action :set_exclusive_fields, only: [:generate, :mappings]
		skip_before_action :verify_authenticity_token

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
			total_recs = json['pager']['total'].to_i
			if total_recs > 1024
				start = 1
				records = []
				[0..(total_recs/1024)].each do |index|
					start = (index*1024) + 1
					json = JSON.parse(Net::HTTP.get_response(URI.parse("http://#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmQuery/#{params[:collection]}/0/0/filetype/1024/#{start}/0/0/0/0/1/0/json")).body)
					records << json['records'].map { |rec| [rec['pointer'], rec['filetype']] }
				end
			else
				records = json['records'].map { |rec| [rec['pointer'], rec['filetype']] }
			end
			headers = ::CSV.generate_line (['object_type','url']+@terms+@work_only)
			csv_lines = [] << headers
			records.each do |rec|
				if rec.last == 'cpd'
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{rec.first}/json")).body)
					csv_lines << create_line(params[:work],'',json)
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCompoundObjectInfo/#{params[:collection]}/#{rec.first}/json")).body)
					rec_pages = json['page'] || json['node']['page']
					rec_pages.each do |child|
						child_json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{child['pageptr']}/json")).body)
						url = api_check rec
						csv_lines << create_line('File',url,child_json)
					end
				else
					json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetItemInfo/#{params[:collection]}/#{rec.first}/json")).body)
					csv_lines << create_line(params[:work],'',json)
					url = api_check rec
					csv_lines << create_line('File',url,{})
				end
			end
			render plain: csv_lines.join, content_type: 'text/csv'

		end

		def mappings
			json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCollectionFieldInfo/"+params['collection']+'/json')).body)
			@cdm_terms = json.collect { |c| [c['name'],c['nick']] }
			get_dirs if @cdm_dirs
			@yaml = YAML.load_file(params['template'].tempfile) if params.has_key? 'template'
		end

		def collection
			json = JSON.parse(Net::HTTP.get_response(URI.parse("#{@cdm_url}:#{@cdm_port}/dmwebservices/index.php?q=dmGetCollectionList/json")).body)
			@collections = json.collect { |c| [c['name'],c['secondary_alias']] }
			load_concerns
		end

		def template
			hashed = params[:mappings].permit!.to_h
			template = {}
			hashed.each do |k,v|
				template[v['cdm']] = {'hydra' => v['hydra'], 'hydrac' => v['hydrac']}
			end
			render plain: template.to_yaml, content_type: 'text/yaml'
		end

		protected

		def load_yaml
			stripped_url = request.base_url.dup.gsub(/https?:\/\//, '').gsub(/:[0-9]*/,'')
			if CdmMigrator::Engine.config['cdm_api'].key? stripped_url
				tenant = CdmMigrator::Engine.config['cdm_api'][stripped_url]
			else
				tenant = CdmMigrator::Engine.config['cdm_api']['default']
			end
			@cdm_url = tenant['url']
			@cdm_port = tenant['port']
			@cdm_dirs = tenant['dirs'] || false
			@cdm_api = tenant['type']
			@default_fields = CdmMigrator::Engine.config['default_fields']
		end

		def api_check rec
			if params[:file_system]=='true'
				"file://#{file_path(rec.first)}"
			elsif @cdm_api == 'server'
				"#{@cdm_url}:#{@cdm_port}/cgi-bin/showfile.exe?CISOROOT=/#{params[:collection]}&CISOPTR=#{rec.first}"
			else
				"#{@cdm_url}/utils/getfile/collection/#{params[:collection]}/id/#{rec.first}/filename/#{rec.first}.#{rec.last}"
			end
		end

		def standalone
			Hyrax rescue nil
		end

		def load_concerns
			@available_concerns = []
			unless @default_fields.nil?
				@available_concerns += [['DefaultWork', 'DefaultWork']]
			end
			unless standalone.nil?
				@available_concerns += Hyrax.config.curation_concerns.map { |c| [c.to_s, c.to_s]}
			end
		end

		def work_form
			Module.const_get("Hyrax::#{params[:work]}Form") rescue nil || Module.const_get('Hyrax::Forms::WorkForm')
		end

		def file_form
			Module.const_get('Hyrax::FileSetForm') rescue nil || Module.const_get('Hyrax::Forms::FileSetEditForm')
		end

		def secondary_terms form_name
			form_name.terms - form_name.required_fields -
					[:visibility_during_embargo, :embargo_release_date,
					 :visibility_after_embargo, :visibility_during_lease,
					 :lease_expiration_date, :visibility_after_lease, :visibility,
					 :thumbnail_id, :representative_id, :ordered_member_ids,
					 :collection_ids, :in_works_ids, :admin_set_id, :files, :source, :member_of_collection_ids]
		end

		def set_exclusive_fields
			if params[:work] != 'DefaultWork'
				@terms = file_form.required_fields + secondary_terms(file_form)
				@work_only = (secondary_terms work_form) - @terms
			else
				@terms = @default_fields
				@work_only = []
			end
		end

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
					line << ''
				else
					line << content.join('|')
				end
			end
			::CSV.generate_line line
		end

		def file_path pointer
			file_types = ['tif','jpg','mp4','mp3']
			files = []
			file_types.each do |type|
				files << Dir.glob("#{params['mappings_url']}/**/#{pointer}_*#{type}")
			end
			files.each do |file|
				return file.first if file.count > 0
			end
		end

		def get_dirs
			@dirs = []
			@cdm_dirs.each do |name, dir|
				ent = Dir.entries(dir).select {|entry| File.directory? File.join(dir,entry) and !(entry =='.' || entry == '..') }
				ent = ent.map { |url| ["#{name}/#{url}", "#{dir}/#{url}"] }
				@dirs += ent
			end
		end
	end
end
