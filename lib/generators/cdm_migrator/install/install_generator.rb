class CdmMigrator::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  
  def inject_dashboard_link
    file_path = "app/views/hyrax/dashboard/sidebar/_tasks.html.erb"
    if File.file?(file_path)
      title = "<li class=\"h5\"><%= t('hyrax.admin.sidebar.tasks') %></li>"
      perm = "  <% if can? :review, :submissions %>"
      gsub_file file_path,/[ \t]*(<li class="h5"><%= t\('hyrax\.admin\.sidebar\.tasks'\) %><\/li>)\n[\s\S]*[ \t]*(<% if can\? :review, :submissions %>)\n/ do |match|
        ""
      end
      gsub_file file_path,/[ \t]*(<% if can\? :review, :submissions %>)\n[\s\S]*[ \t]*(<li class="h5"><%= t\('hyrax\.admin\.sidebar\.tasks'\) %><\/li>)\n/ do |match|
        ""
      end
      prepend_to_file file_path do
            title + "\n" \
            "<li>\n" \
            "		<%= menu.collapsable_section t('CDM Migrator'),\n" \
            "							 icon_class: \"fa fa-map-signs\",\n" \
            "							 id: 'collapseCdmMigrator',\n" \
            "							 open: menu.cdm_migrator_section? do %>\n" \
            "			<%= menu.nav_link(main_app.cdm_start_path) do %>\n" \
            "				<span class=\"fa fa-map\"></span> <span class=\"sidebar-action-text\"><%= t('CDM Mapping Tool') %></span>\n" \
            "			<% end %>\n" \
            "     <%= menu.nav_link(main_app.csv_checker_path) do %>\n" \
            "       <span class=\"fa fa-check-circle\"></span><span>CSV Checker</span>\n" \
            "     <% end %>\n" \
            "			<%= menu.nav_link(main_app.csv_upload_path) do %>\n"\
            "				<span class=\"fa fa-angle-double-up\"></span> <span class=\"sidebar-action-text\"><%= t('CSV Batch Uploader') %></span>\n" \
            "			<% end %>\n" \
            "			<%= menu.nav_link(main_app.csv_my_batches_path) do %>\n" \
            "				<span class=\"fa fa-database\"></span> <span class=\"sidebar-action-text\"><%= t('Batches') %></span>\n" \
            "			<% end %>\n" \
            "		<% end %>\n" \
            "	</li>\n" + perm + "\n"

      end
    else
    	copy_file "sidebar/_tasks.html.erb", "app/views/hyrax/dashboard/sidebar/_tasks.html.erb"
    end
  end
  
  def inject_menu_presenter
  	  hyku_file_path = "app/presenters/hyku/menu_presenter.rb"
  	  hyrax_file_path = "app/presenters/hyrax/menu_presenter.rb"
  	  if File.file?(hyku_file_path) && File.readlines(hyku_file_path).join.include?("cdm_migrator_section")
  	  	  insert_into_file hyku_file_path, :after => /def settings_section\?\n.*\(controller_name\)\n[ \t]*end/ do
  	  	  	  "\n\n" \
  	  	  	  "    def cdm_migrator_section?\n" \
  	  	  	  "      %w[cdm csv].include?(controller_name)\n" \
  	  	  	  "    end\n"
  	  	  end
  	  elsif File.file?(hyrax_file_path) && File.readlines(hyrax_file_path).join.include?("cdm_migrator_section")
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
    copy_file("config/cdm_migrator.yml", "config/cdm_migrator.yml") unless File.file?("config/cdm_migrator.yml")
  end

  def inject_stylesheets
    css_file_path = "app/assets/stylesheets/application.css"
    copy_file("stylesheets/csv_checker.css", "app/assets/stylesheets/csv_checker.css") unless File.file?("app/assets/styelsheets/csv_checker.css")
    insert_into_file css_file_path, :before => " *= require_self\n" do
      " *= require csv_checker\n "
    end
  end
  
end
