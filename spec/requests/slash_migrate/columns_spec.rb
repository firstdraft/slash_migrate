require "rails_helper"

module SlashMigrate
  RSpec.describe "Columns", type: :request do
    describe "GET edit — drop reversibility caveat" do
      it "warns that a column's index and foreign key won't be restored on rollback" do
        get "/rails/migrate/tables/posts/columns/user_id/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("index and foreign key")
        expect(response.body).to include("be restored")
      end

      it "keeps the caveat simple for a plain column with no index or foreign key" do
        get "/rails/migrate/tables/posts/columns/body/edit"

        expect(response.body).to include("gone for good")
        expect(response.body).not_to include("be restored")
      end
    end

    # With turbo-rails in the bundle, a turbo_stream Accept header negotiates the
    # request to the :turbo_stream format; render_stream must still render the
    # html template rather than 500 on a missing .turbo_stream.erb.
    describe "live previews under a turbo_stream Accept header" do
      let(:turbo) { {"Accept" => "text/vnd.turbo-stream.html"} }

      it "streams the add-column preview" do
        post "/rails/migrate/tables/posts/columns/preview",
          headers: turbo,
          params: {attributes: [{name: "blurb", type: "text", null: "", default: "", index: ""}]}

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("turbo-stream", ":blurb")
      end

      it "streams the edit-column preview" do
        post "/rails/migrate/tables/posts/columns/body/update_preview",
          headers: turbo,
          params: {column: {type: "string", null: "not_null", default: ""}}

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("turbo-stream")
      end
    end
  end
end
