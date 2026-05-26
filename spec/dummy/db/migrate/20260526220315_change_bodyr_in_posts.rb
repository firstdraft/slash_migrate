class ChangeBodyrInPosts < ActiveRecord::Migration[8.1]
  def up
    rename_column :posts, :body, :bodyr
    change_column :posts, :bodyr, :integer
  end

  def down
    change_column :posts, :bodyr, :text
    rename_column :posts, :bodyr, :body
  end
end
