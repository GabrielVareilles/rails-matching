class CreateCriteria < ActiveRecord::Migration[6.0]
  def change
    create_table :tastes do |t|
      t.integer :apple
      t.integer :banana
      t.integer :orange
      t.integer :strawberry
      t.integer :peach
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
