require "rails_helper"

module SlashMigrate
  RSpec.describe Column do
    def column(**attrs)
      described_class.new(name: "x", type: "string", **attrs)
    end

    describe "#to_ruby" do
      it "renders a plain column" do
        expect(column(name: "title").to_ruby).to eq("t.string :title")
      end

      it "renders NOT NULL" do
        expect(column(name: "title", null: false).to_ruby).to eq("t.string :title, null: false")
      end

      it "quotes a string default" do
        expect(column(name: "title", default: "hi").to_ruby).to eq('t.string :title, default: "hi"')
      end

      it "leaves a numeric default unquoted" do
        expect(column(name: "count", type: "integer", default: "0").to_ruby).to eq("t.integer :count, default: 0")
      end

      it "renders a boolean default as a literal" do
        expect(column(name: "admin", type: "boolean", default: "true", null: false).to_ruby)
          .to eq("t.boolean :admin, default: true, null: false")
      end

      it "orders default before null" do
        expect(column(name: "title", default: "x", null: false).to_ruby)
          .to eq('t.string :title, default: "x", null: false')
      end

      it "renders decimal precision and scale" do
        expect(column(name: "price", type: "decimal", precision: "10", scale: "2").to_ruby)
          .to eq("t.decimal :price, precision: 10, scale: 2")
      end

      it "renders a reference with null: false and foreign_key" do
        expect(column(name: "user", type: "references", null: false).to_ruby)
          .to eq("t.references :user, null: false, foreign_key: true")
      end
    end

    describe "references pointing at a differently-named table" do
      it "emits foreign_key: { to_table: } when the pick doesn't match the column name" do
        col = column(name: "author", type: "references", null: false, to_table: "users")
        expect(col.to_ruby).to eq("t.references :author, null: false, foreign_key: { to_table: :users }")
        expect(col.belongs_to_line).to eq('belongs_to :author, class_name: "User"')
      end

      it "stays conventional when the pick matches the column name" do
        col = column(name: "author", type: "references", to_table: "authors")
        expect(col.to_ruby).to eq("t.references :author, foreign_key: true")
      end

      it "is conventional when no table is picked" do
        col = column(name: "user", type: "references")
        expect(col.to_ruby).to eq("t.references :user, foreign_key: true")
      end
    end

    describe "#belongs_to_line optionality" do
      it "marks a nullable reference optional to match the column" do
        expect(column(name: "user", type: "references", null: true).belongs_to_line)
          .to eq("belongs_to :user, optional: true")
      end

      it "leaves a NOT NULL reference required, with no override needed by default" do
        expect(column(name: "user", type: "references", null: false).belongs_to_line)
          .to eq("belongs_to :user")
      end

      it "combines class_name and optional for a nullable, differently-named reference" do
        expect(column(name: "author", type: "references", null: true, to_table: "users").belongs_to_line)
          .to eq('belongs_to :author, class_name: "User", optional: true')
      end

      context "when the app does not require belongs_to by default" do
        before { allow(ActiveRecord::Base).to receive(:belongs_to_required_by_default).and_return(false) }

        it "states required: true for a NOT NULL reference" do
          expect(column(name: "user", type: "references", null: false).belongs_to_line)
            .to eq("belongs_to :user, required: true")
        end

        it "leaves a nullable reference as-is, with no override needed" do
          expect(column(name: "user", type: "references", null: true).belongs_to_line)
            .to eq("belongs_to :user")
        end
      end
    end

    describe "indexing" do
      it "marks plain columns as indexed and builds the statement" do
        slug = column(name: "slug", index: "uniq")
        expect(slug.indexed?).to be(true)
        expect(slug.index_statement("articles")).to eq("add_index :articles, :slug, unique: true")
      end

      it "never separately indexes references (they index inline)" do
        expect(column(name: "user", type: "references", index: "index").indexed?).to be(false)
      end
    end

    describe ".from_params" do
      it "maps the not_null select and default" do
        col = described_class.from_params(name: "title", type: "string", null: "not_null", default: "x", index: "")
        expect(col.allow_null?).to be(false)
        expect(col.to_ruby).to eq('t.string :title, default: "x", null: false')
      end

      it "treats a blank null select as allowing null" do
        expect(described_class.from_params(name: "title", type: "string", null: "", default: "", index: "").allow_null?).to be(true)
      end
    end
  end
end
