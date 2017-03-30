CdmMigrater::Engine.routes.draw do
  get '/csv/upload', to: 'csv#upload'
  post '/csv/upload', to: 'csv#create'
  get '/csv/generate', to: 'csv#generate'

  get 'cdm/collection', to: 'cdm#collection'
  get 'cdm/mappings/', to: 'cdm#mappings', as: 'cdm_mappings'
  post 'cdm/generate/', to: 'cdm#generate', as: 'cdm_generate'
end
