require "rails_helper"

module SlashMigrate
  RSpec.describe AddIndexMigration do
    describe "#migration_source" do
      it "indexes a single column as a bare symbol" do
        migration = described_class.new(table: "articles", columns: ["user_id"])

        expect(migration.migration_source).to include("class AddIndexOnUserIdToArticles < ActiveRecord::Migration[")
        expect(migration.migration_source).to include("    add_index :articles, :user_id\n")
      end

      it "indexes two or more columns as a composite array" do
        migration = described_class.new(table: "articles", columns: %w[user_id published_at])

        expect(migration.migration_class_name).to eq("AddIndexOnUserIdAndPublishedAtToArticles")
        expect(migration.migration_source).to include("add_index :articles, [:user_id, :published_at]")
      end

      it "adds unique: true for a unique index" do
        migration = described_class.new(table: "articles", columns: ["slug"], unique: true)

        expect(migration.migration_source).to include("add_index :articles, :slug, unique: true")
      end

      it "adds an explicit name when one is given" do
        migration = described_class.new(table: "articles", columns: ["slug"], unique: true, name: "by_slug")

        expect(migration.migration_source).to include(%(add_index :articles, :slug, unique: true, name: "by_slug"))
      end
    end

    describe ".from_params" do
      it "reads the unique flag from the form's select value" do
        expect(described_class.from_params(table: "articles", columns: ["slug"], unique: "unique")).to be_unique
        expect(described_class.from_params(table: "articles", columns: ["slug"], unique: "")).not_to be_unique
      end

      it "ignores blank column entries" do
        migration = described_class.from_params(table: "articles", columns: ["user_id", "", nil])

        expect(migration.columns).to eq(["user_id"])
        expect(migration).to be_any
      end
    end

    describe "#write!" do
      after do
        Dir.glob(Rails.root.join("db/migrate/*_add_index_on_*_to_articles.rb")).each { |file| File.delete(file) }
      end

      it "writes the migration and returns its relative path" do
        written = described_class.new(table: "articles", columns: ["user_id"]).write!

        expect(written).to include(a_string_matching(%r{\Adb/migrate/\d{14}_add_index_on_user_id_to_articles\.rb\z}))
      end
    end
  end
end
