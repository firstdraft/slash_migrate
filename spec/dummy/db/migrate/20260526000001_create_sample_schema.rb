# Sample schema for exercising the engine against the dummy app. Intentionally
# uses a range of column types, defaults, an index, and a foreign key so the
# table browser (and later the migration builder) has realistic data to render.
class CreateSampleSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.boolean :admin, default: false, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.references :user, null: false, foreign_key: true
      t.integer :views_count, default: 0, null: false
      t.datetime :published_at
      t.timestamps
    end
  end
end
