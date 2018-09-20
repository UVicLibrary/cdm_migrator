CdmMigrator::Engine.routes.draw do
  get '/csv/upload', to: 'csv#upload', as: 'csv_upload'
  post '/csv/upload', to: 'csv#create', as: 'csv_create'
  get '/csv/generate', to: 'csv#generate', as: 'csv_generate'

  get 'cdm/collection', to: 'cdm#collection'
  post 'cdm/mappings/', to: 'cdm#mappings', as: 'cdm_mappings'
  post 'cdm/generate/', to: 'cdm#generate', as: 'cdm_generate'
  post 'cdm/template', to: 'cdm#template', as: 'cdm_template'
end
