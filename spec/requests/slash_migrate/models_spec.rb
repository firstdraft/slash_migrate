require "rails_helper"

module SlashMigrate
  RSpec.describe "Models", type: :request do
    describe "GET /rails/migrate/models/new" do
      it "renders the form" do
        get "/rails/migrate/models/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New table")
      end
    end

    # These send Accept: text/vnd.turbo-stream.html and run with turbo-rails in
    # the bundle, so they exercise the :turbo_stream format negotiation that
    # broke a bare `render :preview` (it looked for a nonexistent
    # preview.turbo_stream.erb). render_stream forces the html template.
    describe "POST /rails/migrate/models/preview" do
      it "streams the generated migration, including options the CLI can't express" do
        before = Dir.glob(Rails.root.join("db/migrate/*.rb")).length

        post "/rails/migrate/models/preview", params: {
          model_name: "Article",
          attributes: [
            {name: "title", type: "string", null: "not_null", default: "", index: ""},
            {name: "views_count", type: "integer", null: "not_null", default: "0", index: ""},
            {name: "user", type: "references", null: "not_null", default: "", index: "", to_table: "users"}
          ]
        }, headers: {"Accept" => "text/vnd.turbo-stream.html"}

        # The preview renders syntax-highlighted, so read the code with its
        # markup stripped back to plain text before asserting on the migration.
        code = CGI.unescapeHTML(response.body.gsub(/<[^>]+>/, ""))

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("turbo-stream")
        expect(code).to include("create_table :articles")
        expect(code).to include("t.string :title, null: false")
        expect(code).to include("t.integer :views_count, default: 0, null: false")
        expect(code).to include("t.references :user, null: false, foreign_key: true")
        expect(response.body).not_to include("bin/rails generate")

        after = Dir.glob(Rails.root.join("db/migrate/*.rb")).length
        expect(after).to eq(before)
      end

      it "shows a hint when no model name is given" do
        post "/rails/migrate/models/preview", params: {model_name: ""}, headers: {"Accept" => "text/vnd.turbo-stream.html"}

        expect(response.body).to include("Enter a model name")
      end
    end

    describe "POST /rails/migrate/models" do
      after do
        Dir.glob(Rails.root.join("db/migrate/*_create_widgets.rb")).each { |f| File.delete(f) }
        path = Rails.root.join("app/models/widget.rb")
        File.delete(path) if File.exist?(path)
      end

      it "writes the migration and model, then redirects with a notice" do
        post "/rails/migrate/models", params: {
          model_name: "Widget",
          attributes: [{name: "name", type: "string", null: "", default: "", index: ""}]
        }

        expect(response).to redirect_to("/rails/migrate/migrations")
        expect(flash[:notice]).to match(/create_widgets/)

        expect(Dir.glob(Rails.root.join("db/migrate/*_create_widgets.rb"))).not_to be_empty
        expect(Rails.root.join("app/models/widget.rb")).to exist
      end

      it "refuses to create a table that already exists" do
        post "/rails/migrate/models", params: {
          model_name: "User",
          attributes: [{name: "name", type: "string", null: "", default: "", index: ""}]
        }

        expect(response).to redirect_to("/rails/migrate/models/new")
        expect(flash[:alert]).to match(/already exists/)
        expect(Dir.glob(Rails.root.join("db/migrate/*_create_users.rb"))).to be_empty
      end
    end
  end
end
