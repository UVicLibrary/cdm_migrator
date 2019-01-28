class CdmMigrator::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  
  def inject_dashboard_link
    file_path = "app/views/hyrax/dashboard/sidebar/_tasks.html.erb"
    if File.file?(file_path)
      gsub_file file_path,/[ \t]*(<% if can\? :review, :submissions %>)\n[ \t]*(<li class="h5"><%= t\('hyrax\.admin\.sidebar\.tasks'\) %><\/li>)\n/ do |match|
match.split("\n")[1].to_s+
"\n	<li>\n" \
"		<%= menu.collapsable_section t('CDM Migrator'),\n" \
"							 icon_class: \"fa fa-map-signs\",\n" \
"							 id: 'collapseCdmMigrator',\n" \
"							 open: menu.cdm_migrator_section? do %>\n" \
"			<%= menu.nav_link(main_app.csv_upload_path) do %>\n"\
"				<span class=\"fa fa-angle-double-up\"></span> <span class=\"sidebar-action-text\"><%= t('CSV Batch Uploader') %></span>\n" \
"			<% end %>\n" \
"			<%= menu.nav_link(main_app.cdm_start_path) do %>\n" \
"				<span class=\"fa fa-map\"></span> <span class=\"sidebar-action-text\"><%= t('CDM Mapping Tool') %></span>\n" \
"			<% end %>\n" \
"		<% end %>\n" \
"	</li>\n" + match.split("\n")[0].to_s + "\n"
      end
    else
    	copy_file "sidebar/_tasks.html.erb", "app/views/hyrax/dashboard/sidebar/_tasks.html.erb"
    end
  end
  
  def inject_menu_presenter
  	  hyku_file_path = "app/presenters/hyku/menu_presenter.rb"
  	  hyrax_file_path = "app/presenters/hyrax/menu_presenter.rb"
  	  if File.file?(hyku_file_path)
  	  	  insert_into_file hyku_file_path, :after => /def settings_section\?\n.*\(controller_name\)\n[ \t]*end/ do
  	  	  	  "\n\n" \
  	  	  	  "    def cdm_migrator_section?\n" \
  	  	  	  "      %w[cdm csv].include?(controller_name)\n" \
  	  	  	  "    end\n"
  	  	  end
  	  elsif File.file?(hyrax_file_path)
  	  	  insert_into_file hyrax_file_path, :after => /def settings_section\?\n.*\(controller_name\)\n[ \t]*end/ do
  	  	  	  "\n\n" \
  	  	  	  "    def cdm_migrator_section?\n" \
  	  	  	  "      %w[cdm csv].include?(controller_name)\n" \
  	  	  	  "    end\n"
  	  	  end
  	  elsif Hyku
  	  	  copy_file "presenters/hyku/menu_presenter.rb", "app/presenters/hyku/menu_presenter.rb"
  	  elsif Hyrax
  	  	  copy_file "presenters/hyrax/menu_presenter.rb", "app/presenters/hyrax/menu_presenter.rb"
  	  end
  end

  def inject_content_dm_yml
    copy_file "config/cdm_migrator.yml", "config/cdm_migrator.yml"
  end
  
end