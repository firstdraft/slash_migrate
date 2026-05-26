require "rails_helper"

module SlashMigrate
  RSpec.describe EditColumnMigration do
    def col(name:, type: "string", null: true, default: nil)
      Column.new(name: name, type: type, null: null, default: default)
    end

    it "reports no change when nothing differs" do
      migration = described_class.new(table: "posts", original: col(name: "title"), desired: col(name: "title"))
      expect(migration.changed?).to be(false)
    end

    describe "a pure rename" do
      subject(:migration) { described_class.new(table: "posts", original: col(name: "body"), desired: col(name: "content")) }

      it "is a reversible def change" do
        expect(migration.reversible_as_change?).to be(true)
        expect(migration.migration_class_name).to eq("RenameBodyInPosts")
        source = migration.migration_source
        expect(source).to include("  def change")
        expect(source).to include("    rename_column :posts, :body, :content")
        expect(source).not_to include("def up")
      end
    end

    describe "a type change" do
      subject(:migration) do
        described_class.new(table: "posts", original: col(name: "views", type: "integer"), desired: col(name: "views", type: "bigint"))
      end

      it "is written as explicit up/down" do
        expect(migration.reversible_as_change?).to be(false)
        source = migration.migration_source
        expect(source).to include("  def up")
        expect(source).to include("    change_column :posts, :views, :bigint")
        expect(source).to include("  def down")
        expect(source).to include("    change_column :posts, :views, :integer")
      end
    end

    describe "a default change" do
      subject(:migration) do
        described_class.new(table: "posts",
          original: col(name: "state", type: "string", default: nil),
          desired: col(name: "state", type: "string", default: "draft"))
      end

      it "emits change_column_default with from/to and reverses it" do
        source = migration.migration_source
        expect(source).to include('change_column_default :posts, :state, from: nil, to: "draft"')
        expect(source).to include('change_column_default :posts, :state, from: "draft", to: nil')
      end
    end

    describe "a rename combined with a type change" do
      subject(:migration) do
        described_class.new(table: "posts",
          original: col(name: "views", type: "integer"),
          desired: col(name: "view_count", type: "bigint"))
      end

      it "renames first in up, then reverses order in down using the new name" do
        source = migration.migration_source
        expect(source).to include("  def up\n    rename_column :posts, :views, :view_count\n    change_column :posts, :view_count, :bigint\n  end")
        expect(source).to include("  def down\n    change_column :posts, :view_count, :integer\n    rename_column :posts, :view_count, :views\n  end")
      end
    end

    describe "#write!" do
      after { Dir.glob(Rails.root.join("db/migrate/*_rename_body_in_posts.rb")).each { |f| File.delete(f) } }

      it "writes the migration file" do
        migration = described_class.new(table: "posts", original: col(name: "body"), desired: col(name: "content"))
        written = migration.write!

        expect(written.first).to match(%r{\Adb/migrate/\d{14}_rename_body_in_posts\.rb\z})
      end
    end
  end
end
