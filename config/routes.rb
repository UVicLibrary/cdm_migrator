Rails.application.routes.draw do
  get '/cdm_migrator/upload', to: 'cdm_migrator/csv#upload', as: 'csv_upload'
  post '/cdm_migrator/upload', to: 'cdm_migrator/csv#create', as: 'csv_create'
  get '/cdm_migrator/generate', to: 'cdm_migrator/csv#generate', as: 'csv_generate'
  get '/cdm_migrator/my/batches', to: 'cdm_migrator/csv#index', as: 'csv_my_batches'
  get '/cdm_migrator/batches', to: 'cdm_migrator/csv#index', as: 'csv_all_batches'
  get '/cdm_migrator/rerun/:id', to: 'cdm_migrator/csv#rerun', as: 'csv_rerun'
  get '/cdm_migrator/edit', to: 'cdm_migrator/csv#edit', as: 'csv_edit'
  post '/cdm_migrator/export', to: 'cdm_migrator/csv#export', as: 'csv_export'
  post '/cdm_migrator/update', to: 'cdm_migrator/csv#update', as: 'csv_update'

  get '/cdm_migrator/csv_checker', to: 'cdm_migrator/csv#csv_checker', as: 'csv_checker'
  post '/cdm_migrator/csv_checker', to: 'cdm_migrator/csv#csv_checker', as: 'check_csv'

  get '/cdm_migrator/collection', to: 'cdm_migrator/cdm#collection', as: 'cdm_start'
  post '/cdm_migrator/mappings/', to: 'cdm_migrator/cdm#mappings', as: 'cdm_mappings'
  post '/cdm_migrator/generate/', to: 'cdm_migrator/cdm#generate', as: 'cdm_generate'
  post '/cdm_migrator/template', to: 'cdm_migrator/cdm#template', as: 'cdm_template'
end
