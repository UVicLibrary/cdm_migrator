class CreateIngestWorks < ActiveRecord::Migration[5.0]
  def up
    create_table :ingest_works do |t|
      t.string :work_type
      t.text :data
      t.text :files
      t.boolean :complete, :default => false

      t.references :batch_ingest, foreign_key: true

      t.timestamps
    end
  end

  def down
    drop_table :ingest_works
  end
end
