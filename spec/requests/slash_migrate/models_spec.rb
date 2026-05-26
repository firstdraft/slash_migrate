require "rails_helper"

module SlashMigrate
  RSpec.describe "Models", type: :request do
    describe "GET /rails/migrate/models/new" do
      it "renders the form" do
        get "/rails/migrate/models/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New model")
      end
    end

    describe "POST /rails/migrate/models/preview" do
      it "streams the generated migration without writing any files" do
        before = Dir.glob(Rails.root.join("db/migrate/*.rb")).length

        post "/rails/migrate/models/preview", params: {
          model_name: "Article",
          attributes: [
            {name: "title", type: "string", index: ""},
            {name: "user", type: "references", index: ""}
          ]
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("create_table :articles")
        expect(response.body).to include("t.references :user")
        expect(response.body).to include("bin/rails generate model Article title:string user:references")

        after = Dir.glob(Rails.root.join("db/migrate/*.rb")).length
        expect(after).to eq(before)
      end

      it "shows a hint when no model name is given" do
        post "/rails/migrate/models/preview", params: {model_name: ""}

        expect(response.body).to include("Enter a model name")
      end
    end

    describe "POST /rails/migrate/models" do
      after do
        Dir.glob(Rails.root.join("db/migrate/*_create_widgets.rb")).each { |f| File.delete(f) }
        ["app/models/widget.rb", "spec/models/widget_spec.rb"].each do |relative|
          path = Rails.root.join(relative)
          File.delete(path) if File.exist?(path)
        end
      end

      it "writes the migration and model, then redirects with a notice" do
        post "/rails/migrate/models", params: {
          model_name: "Widget",
          attributes: [{name: "name", type: "string", index: ""}]
        }

        expect(response).to redirect_to("/rails/migrate/models/new")
        expect(flash[:notice]).to match(/create_widgets/)

        expect(Dir.glob(Rails.root.join("db/migrate/*_create_widgets.rb"))).not_to be_empty
        expect(Rails.root.join("app/models/widget.rb")).to exist
      end
    end
  end
end
