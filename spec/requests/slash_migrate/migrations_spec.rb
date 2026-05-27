require "rails_helper"

module SlashMigrate
  RSpec.describe "Migrations", type: :request do
    describe "GET /rails/migrate/migrations" do
      it "lists migrations inside the Turbo Stream target" do
        get "/rails/migrate/migrations"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="sm-migrations"')
        expect(response.body).to include("Create sample schema")
      end
    end

    # Regression for the CookieOverflow crash: db:migrate output can be large,
    # so it must travel in the Turbo Stream body, never the 4 KB session cookie.
    # Posting 5 KB of output here would overflow a CookieStore flash on a redirect.
    describe "POST /rails/migrate/migrations/run" do
      it "streams the output in place rather than redirecting through the flash" do
        big_output = "Migrating...\n" + ("x" * 5000)
        allow_any_instance_of(MigrationRunner).to receive(:migrate)
          .and_return(double(success?: true, output: big_output))

        post "/rails/migrate/migrations/run"

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream", 'target="sm-migrations"')
        expect(response.body).to include("Migrating...")
      end
    end

    describe "POST /rails/migrate/migrations/rollback" do
      it "streams the command output and flags a failure" do
        allow_any_instance_of(MigrationRunner).to receive(:rollback)
          .and_return(double(success?: false, output: "boom"))

        post "/rails/migrate/migrations/rollback"

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("boom")
        expect(response.body).to include("exited 1")
      end
    end

    describe "DELETE /rails/migrate/migrations/:version" do
      let(:path) { Rails.root.join("db/migrate/29990303000000_remove_me_stream.rb") }
      after { File.delete(path) if File.exist?(path) }

      it "deletes a pending file and streams the refreshed list" do
        File.write(path, "class RemoveMeStream < ActiveRecord::Migration[8.0]\n  def change\n  end\nend\n")

        delete "/rails/migrate/migrations/29990303000000"

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('target="sm-migrations"')
        expect(File.exist?(path)).to be(false)
      end
    end
  end
end
