require "rails_helper"

module SlashMigrate
  RSpec.describe AddColumnsMigration do
    it "adds a single column in a reversible def change" do
      migration = described_class.new(table: "articles", columns: [
        Column.new(name: "body", type: "text", null: false, default: "draft")
      ])

      expect(migration.migration_class_name).to eq("AddBodyToArticles")
      source = migration.migration_source
      expect(source).to include("class AddBodyToArticles < ActiveRecord::Migration[")
      expect(source).to include("  def change")
      expect(source).to include('    add_column :articles, :body, :text, default: "draft", null: false')
    end

    it "adds a reference with add_reference, honoring to_table" do
      migration = described_class.new(table: "comments", columns: [
        Column.new(name: "author", type: "references", null: false, to_table: "users")
      ])

      expect(migration.migration_class_name).to eq("AddAuthorToComments")
      expect(migration.migration_source)
        .to include("add_reference :comments, :author, null: false, foreign_key: { to_table: :users }")
    end

    it "emits a separate add_index for an indexed column" do
      migration = described_class.new(table: "articles", columns: [
        Column.new(name: "slug", type: "string", index: "uniq")
      ])

      source = migration.migration_source
      expect(source).to include("add_column :articles, :slug, :string")
      expect(source).to include("add_index :articles, :slug, unique: true")
    end

    it "names a multi-column migration generically" do
      migration = described_class.new(table: "articles", columns: [
        Column.new(name: "a", type: "string"),
        Column.new(name: "b", type: "string")
      ])

      expect(migration.migration_class_name).to eq("AddColumnsToArticles")
    end

    describe ".from_params" do
      it "resolves the self-table sentinel to the table being modified" do
        migration = described_class.from_params(table: "employees", rows: [
          {name: "manager", type: "references", null: "not_null", to_table: MigrationBuilder::SELF_TABLE}
        ])

        expect(migration.migration_source)
          .to include("add_reference :employees, :manager, null: false, foreign_key: { to_table: :employees }")
      end
    end

    describe "#write!" do
      after { Dir.glob(Rails.root.join("db/migrate/*_add_nickname_to_users.rb")).each { |f| File.delete(f) } }

      it "writes the migration file" do
        migration = described_class.new(table: "users", columns: [Column.new(name: "nickname", type: "string")])
        written = migration.write!

        expect(written.first).to match(%r{\Adb/migrate/\d{14}_add_nickname_to_users\.rb\z})
        expect(Dir.glob(Rails.root.join("db/migrate/*_add_nickname_to_users.rb"))).not_to be_empty
      end
    end
  end
end
