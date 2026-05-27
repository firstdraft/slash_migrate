require "rails_helper"

module SlashMigrate
  RSpec.describe DropIndexMigration do
    # Stands in for the Active Record index object the controller passes in.
    let(:index_class) { Struct.new(:name, :columns, :unique, keyword_init: true) }

    def build_index(**attrs)
      index_class.new(**attrs)
    end

    describe "#migration_source" do
      it "removes a single-column index by its column, which keeps it reversible" do
        index = build_index(name: "index_articles_on_user_id", columns: ["user_id"], unique: false)
        migration = described_class.new(table: "articles", index: index)

        expect(migration.migration_class_name).to eq("RemoveIndexOnUserIdFromArticles")
        expect(migration.migration_source).to include("    remove_index :articles, column: :user_id\n")
      end

      it "removes a composite index as an array of columns" do
        index = build_index(name: "index_articles_on_user_id_and_published_at", columns: %w[user_id published_at], unique: false)
        migration = described_class.new(table: "articles", index: index)

        expect(migration.migration_source).to include("remove_index :articles, column: [:user_id, :published_at]")
      end

      it "carries unique: true so a rollback re-creates the unique index" do
        index = build_index(name: "index_articles_on_slug", columns: ["slug"], unique: true)

        expect(described_class.new(table: "articles", index: index).migration_source)
          .to include("remove_index :articles, column: :slug, unique: true")
      end

      it "includes the name only when it isn't the conventional one" do
        custom = build_index(name: "by_slug", columns: ["slug"], unique: false)

        expect(described_class.new(table: "articles", index: custom).migration_source)
          .to include(%(remove_index :articles, column: :slug, name: "by_slug"))
      end
    end

    describe "#write!" do
      after do
        Dir.glob(Rails.root.join("db/migrate/*_remove_index_on_*_from_articles.rb")).each { |file| File.delete(file) }
      end

      it "writes the migration and returns its relative path" do
        index = build_index(name: "index_articles_on_user_id", columns: ["user_id"], unique: false)
        written = described_class.new(table: "articles", index: index).write!

        expect(written).to include(a_string_matching(%r{\Adb/migrate/\d{14}_remove_index_on_user_id_from_articles\.rb\z}))
      end
    end
  end
end
