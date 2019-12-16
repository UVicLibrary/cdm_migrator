class CreateBatchIngests < ActiveRecord::Migration[5.0]
  def up
    create_table :batch_ingests do |t|
      t.text :data
      t.string :admin_set_id
      t.string :collection_id
      t.text :message
      t.integer :size
      t.string :csv
      t.references :user, foreign_key: true
      t.boolean :complete, default: false

      t.timestamps
    end
  end

  def down
    drop_table :batch_ingests
  end
end