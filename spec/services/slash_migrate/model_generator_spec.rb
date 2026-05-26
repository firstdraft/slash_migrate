require "rails_helper"

module SlashMigrate
  RSpec.describe ModelGenerator do
    describe ModelGenerator::Attribute do
      it "builds field:type args" do
        expect(described_class.new(name: "title", type: "string", index: "").to_arg)
          .to eq("title:string")
      end

      it "appends a unique-index modifier" do
        expect(described_class.new(name: "slug", type: "string", index: "uniq").to_arg)
          .to eq("slug:string:uniq")
      end

      it "appends a plain-index modifier" do
        expect(described_class.new(name: "user", type: "references", index: "index").to_arg)
          .to eq("user:references:index")
      end

      it "ignores an unknown index modifier" do
        expect(described_class.new(name: "title", type: "string", index: "bogus").to_arg)
          .to eq("title:string")
      end
    end

    let(:generator) do
      described_class.from_params(
        name: "Article",
        attributes: [
          {name: "title", type: "string", index: ""},
          {name: "body", type: "text", index: ""},
          {name: "published", type: "boolean", index: ""},
          {name: "user", type: "references", index: ""},
          {name: "slug", type: "string", index: "uniq"}
        ]
      )
    end

    it "drops blank attribute rows from the argv" do
      generator = described_class.from_params(
        name: "Tag",
        attributes: [{name: "name", type: "string", index: ""}, {name: "", type: "string", index: ""}]
      )

      expect(generator.argv).to eq(%w[Tag name:string])
    end

    it "renders the equivalent CLI command" do
      expect(generator.cli_command).to eq(
        "bin/rails generate model Article title:string body:text published:boolean user:references slug:string:uniq"
      )
    end

    describe "#preview" do
      let(:files) { generator.preview }

      def content_for(predicate)
        files.find(&predicate).content
      end

      it "produces a migration byte-identical to rails g model" do
        version = ActiveRecord::VERSION::STRING.to_f
        expected = <<~RUBY
          class CreateArticles < ActiveRecord::Migration[#{version}]
            def change
              create_table :articles do |t|
                t.string :title
                t.text :body
                t.boolean :published
                t.references :user, null: false, foreign_key: true
                t.string :slug

                t.timestamps
              end
              add_index :articles, :slug, unique: true
            end
          end
        RUBY

        expect(content_for(:migration?)).to eq(expected)
      end

      it "names the migration with a timestamp" do
        migration = files.find(&:migration?)
        expect(migration.filename).to match(/\A\d{14}_create_articles\.rb\z/)
      end

      it "generates the model with its association" do
        expected = <<~RUBY
          class Article < ApplicationRecord
            belongs_to :user
          end
        RUBY

        expect(content_for(:model?)).to eq(expected)
      end

      it "does not write anything into the host app" do
        before = Dir.glob(Rails.root.join("db/migrate/*.rb")).length
        generator.preview
        after = Dir.glob(Rails.root.join("db/migrate/*.rb")).length

        expect(after).to eq(before)
      end
    end
  end
end
