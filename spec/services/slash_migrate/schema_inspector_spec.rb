require "rails_helper"

module SlashMigrate
  RSpec.describe SchemaInspector do
    subject(:inspector) { described_class.new }

    describe "#table_names" do
      it "lists application tables, sorted" do
        expect(inspector.table_names).to eq(%w[posts users])
      end

      it "excludes Active Record's internal tables" do
        expect(inspector.table_names).not_to include("schema_migrations", "ar_internal_metadata")
      end
    end

    describe "#exists?" do
      it "is true for a real table and false otherwise" do
        expect(inspector.exists?("posts")).to be(true)
        expect(inspector.exists?("nonexistent")).to be(false)
      end
    end

    describe "#table" do
      subject(:table) { inspector.table("posts") }

      it "exposes the primary key" do
        expect(table.primary_key).to eq("id")
      end

      it "exposes columns with type metadata" do
        title = table.columns.find { |c| c.name == "title" }
        expect(title.type).to eq(:string)
        expect(title.null).to be(false)

        # Active Record types a column's default differently across Rails
        # versions (8.0 → "0", 8.1 → 0); the browser only ever renders it as
        # text, so assert on the string form.
        views = table.columns.find { |c| c.name == "views_count" }
        expect(views.default.to_s).to eq("0")
      end

      it "exposes indexes" do
        expect(table.indexes.map(&:name)).to include("index_posts_on_user_id")
      end

      it "exposes foreign keys" do
        fk = table.foreign_keys.find { |f| f.column == "user_id" }
        expect(fk.to_table).to eq("users")
      end
    end
  end
end
