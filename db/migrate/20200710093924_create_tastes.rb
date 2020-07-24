class CreateTastes < ActiveRecord::Migration[6.0]
  def change
    create_table :tastes do |t|
      t.float :apple
      t.float :banana
      t.float :orange
      t.float :strawberry
      t.float :peach
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
