require "rails_helper"
require "rails/generators"
require "tmpdir"

module SlashMigrate
  RSpec.describe MigrationBuilder do
    describe "#migration_source" do
      it "emits a create_table migration with the rich options the CLI can't" do
        builder = described_class.new(name: "Article", columns: [
          Column.new(name: "title", type: "string", null: false),
          Column.new(name: "views_count", type: "integer", default: "0", null: false),
          Column.new(name: "user", type: "references", null: false),
          Column.new(name: "slug", type: "string", index: "uniq")
        ])
        source = builder.migration_source

        expect(source).to include("class CreateArticles < ActiveRecord::Migration[")
        expect(source).to include("    create_table :articles do |t|")
        expect(source).to include("      t.string :title, null: false")
        expect(source).to include("      t.integer :views_count, default: 0, null: false")
        expect(source).to include("      t.references :user, null: false, foreign_key: true")
        expect(source).to include("      t.string :slug\n")
        expect(source).to include("      t.timestamps")
        expect(source).to include("    add_index :articles, :slug, unique: true")
      end
    end

    describe "#model_source" do
      it "emits belongs_to for each reference" do
        builder = described_class.new(name: "Article", columns: [
          Column.new(name: "user", type: "references", null: false)
        ])

        expect(builder.model_source).to eq("class Article < ApplicationRecord\n  belongs_to :user\nend\n")
      end

      it "emits a bare model when there are no references" do
        expect(described_class.new(name: "Tag").model_source).to eq("class Tag < ApplicationRecord\nend\n")
      end
    end

    describe "name inflection" do
      it "singularizes a plural input into a model name, keeping the table plural" do
        builder = described_class.new(name: "Articles")

        expect(builder.model_class_name).to eq("Article")
        expect(builder.table_name).to eq("articles")
        expect(builder.migration_class_name).to eq("CreateArticles")
        expect(builder.model_filename).to eq("article.rb")
        expect(builder.pluralized_input?).to be(true)
      end

      it "handles compound and irregular names like Active Record does" do
        expect(described_class.new(name: "blog_posts").model_class_name).to eq("BlogPost")
        expect(described_class.new(name: "people").model_class_name).to eq("Person")
        expect(described_class.new(name: "people").table_name).to eq("people")
      end

      it "does not warn for an already-singular name" do
        expect(described_class.new(name: "Article").pluralized_input?).to be(false)
        expect(described_class.new(name: "article").pluralized_input?).to be(false)
      end
    end

    describe "#references_with_id_suffix" do
      it "lists only references columns that still carry _id" do
        builder = described_class.new(name: "Article", columns: [
          Column.new(name: "user_id", type: "references"),
          Column.new(name: "category", type: "references"),
          Column.new(name: "title", type: "string")
        ])

        expect(builder.references_with_id_suffix).to eq(["user_id"])
      end
    end

    # The teaching promise: for columns both can express, our output is exactly
    # what `rails g model` would write. Guards against drift from Rails' style.
    describe "fidelity with rails g model" do
      it "matches the generator on the overlapping subset" do
        builder = described_class.new(name: "Article", columns: [
          Column.new(name: "title", type: "string"),
          Column.new(name: "body", type: "text"),
          Column.new(name: "count", type: "integer"),
          Column.new(name: "price", type: "decimal", precision: "10", scale: "2"),
          Column.new(name: "nickname", type: "string", limit: "30"),
          Column.new(name: "user", type: "references", null: false),
          Column.new(name: "slug", type: "string", index: "uniq")
        ])

        generated = generator_migration(
          %w[Article title:string body:text count:integer price:decimal{10,2} nickname:string{30} user:references slug:string:uniq]
        )

        expect(builder.migration_source).to eq(generated)
      end
    end

    describe "self-references via .from_params" do
      it "resolves the (this table) sentinel to the table being created" do
        builder = described_class.from_params(name: "Employee", rows: [
          {name: "manager", type: "references", null: "not_null", default: "", index: "", to_table: described_class::SELF_TABLE}
        ])

        expect(builder.migration_source).to include("t.references :manager, null: false, foreign_key: { to_table: :employees }")
        expect(builder.model_source).to include('belongs_to :manager, class_name: "Employee"')
      end
    end

    describe "#write!" do
      after do
        Dir.glob(Rails.root.join("db/migrate/*_create_widgets.rb")).each { |f| File.delete(f) }
        path = Rails.root.join("app/models/widget.rb")
        File.delete(path) if File.exist?(path)
      end

      it "writes the migration and model and returns their relative paths" do
        builder = described_class.new(name: "Widget", columns: [Column.new(name: "name", type: "string")])
        written = builder.write!

        expect(written).to include(a_string_matching(%r{\Adb/migrate/\d{14}_create_widgets\.rb\z}))
        expect(written).to include("app/models/widget.rb")
        expect(Rails.root.join("app/models/widget.rb").read).to include("class Widget < ApplicationRecord")
      end
    end

    def generator_migration(args)
      Rails.application.load_generators
      Dir.mktmpdir do |dir|
        Rails::Generators.invoke("model", args + ["--quiet"], behavior: :invoke, destination_root: dir)
        File.read(Dir.glob(File.join(dir, "db/migrate/*.rb")).first)
      end
    end
  end
end
