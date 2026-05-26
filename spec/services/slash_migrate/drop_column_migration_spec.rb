require "rails_helper"

module SlashMigrate
  RSpec.describe DropColumnMigration do
    it "renders a reversible drop migration that includes the column type" do
      column = Column.new(name: "title", type: "string", null: false)
      migration = described_class.new(table: "posts", column: column)

      expect(migration.migration_class_name).to eq("RemoveTitleFromPosts")
      source = migration.migration_source
      expect(source).to include("class RemoveTitleFromPosts < ActiveRecord::Migration[")
      expect(source).to include("  def change")
      expect(source).to include("    remove_column :posts, :title, :string, null: false")
    end

    describe "Column.from_schema" do
      it "reads a column's current definition from the live schema" do
        ar_column = ActiveRecord::Base.connection.columns("posts").find { |c| c.name == "title" }
        column = Column.from_schema(ar_column)

        expect(column.name).to eq("title")
        expect(column.type).to eq("string")
        expect(column.allow_null?).to be(false)
        expect(column.remove_statement("posts")).to include("remove_column :posts, :title, :string")
      end
    end
  end
end
