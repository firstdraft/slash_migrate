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
  end
end
