Rails.application.routes.draw do
  get '/cdm_migrator/upload', to: 'cdm_migrator/csv#upload', as: 'csv_upload'
  post '/cdm_migrator/upload', to: 'cdm_migrator/csv#create', as: 'csv_create'
  get '/cdm_migrator/generate', to: 'cdm_migrator/csv#generate', as: 'csv_generate'

  get '/cdm_migrator/collection', to: 'cdm_migrator/cdm#collection', as: 'cdm_start'
  post '/cdm_migrator/mappings/', to: 'cdm_migrator/cdm#mappings', as: 'cdm_mappings'
  post '/cdm_migrator/generate/', to: 'cdm_migrator/cdm#generate', as: 'cdm_generate'
  post '/cdm_migrator/template', to: 'cdm_migrator/cdm#template', as: 'cdm_template'
end
