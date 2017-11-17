CdmMigrator::Engine.routes.draw do
  get '/csv/upload', to: 'csv#upload', as: 'csv_upload'
  post '/csv/upload', to: 'csv#create', as: 'csv_create'
  get '/csv/generate', to: 'csv#generate', as: 'csv_generate'

  get 'cdm/collection', to: 'cdm#collection'
  get 'cdm/mappings/', to: 'cdm#mappings', as: 'cdm_mappings'
  post 'cdm/generate/', to: 'cdm#generate', as: 'cdm_generate'
end
