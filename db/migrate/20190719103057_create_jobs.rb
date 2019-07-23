class CreateJobs < ActiveRecord::Migration[5.2]
  def change
    create_table :jobs do |t|
      t.string  :state, limit: 30,       null: false, default: 'created'
      t.integer :rows,                   null: false, default: 0
      t.string  :description, limit: 255

      t.timestamps
    end
  end
end
