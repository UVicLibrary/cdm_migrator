module CdmMigrator
  class CdmIngestFilesJob < ActiveJob::Base
    queue_as Hyrax.config.ingest_queue_name

    def perform(fs, url, user, ingest_work = nil, last_file = false, last_work = false)
      if url.include?("http") && File.extname(url).include?("pdf")
        download = open(url)
        dir = Rails.root.join('public', 'uploads', 'csv_pdfs')
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
        filename = download.base_uri.to_s.split('/').last
        url = dir.join(filename)
        if fs.title.empty?
          fs.title << filename.split('.').first
          fs.save
        end
        IO.copy_stream(download, url)
        url = "file://"+url.to_s
      end
      uri = URI.parse(url.gsub(' ','%20'))
      if uri.scheme == 'file'
        IngestLocalFileJob.perform_now(fs, uri.path.gsub('%20',' '), user)
      else
        ImportUrlJob.perform_now(fs, log(user))
      end
      ingest_work.update_attribute('complete', true) if last_file
      BatchIngest.find(ingest_work.id).update_attribute('complete', true) if last_work
    end

    def log(user)
      Hyrax::Operation.create!(user: user,
                               operation_type: "Attach Remote File")
    end

  end
end
