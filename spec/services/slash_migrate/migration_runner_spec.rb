require "rails_helper"

module SlashMigrate
  RSpec.describe MigrationRunner do
    subject(:runner) { described_class.new }

    describe "#status / #pending?" do
      it "reports the applied sample migration as up" do
        sample = runner.status.find { |migration| migration.version == "20260526000001" }

        expect(sample).to be_present
        expect(sample.applied?).to be(true)
        expect(sample.name).to eq("Create sample schema")
      end

      # pending? against the real db/migrate dir is fragile — the dummy app
      # accumulates throwaway migrations as the engine is exercised by hand — so
      # pin the file list to assert the semantics directly.
      it "is not pending when every migration file is applied" do
        allow(runner).to receive(:migration_files)
          .and_return([Rails.root.join("db/migrate/20260526000001_create_sample_schema.rb").to_s])

        expect(runner.pending?).to be(false)
      end

      context "with an unapplied migration file present" do
        let(:path) { Rails.root.join("db/migrate/29990101000000_add_a_pending_thing.rb") }

        before { File.write(path, "class AddAPendingThing < ActiveRecord::Migration[8.1]\n  def change\n  end\nend\n") }
        after { File.delete(path) if File.exist?(path) }

        it "lists it as pending" do
          pending = runner.status.find { |migration| migration.version == "29990101000000" }

          expect(pending.applied?).to be(false)
          expect(pending.name).to eq("Add a pending thing")
          expect(runner.pending?).to be(true)
        end
      end
    end

    describe "#delete" do
      let(:path) { Rails.root.join("db/migrate/29990202000000_remove_me.rb") }

      after { File.delete(path) if File.exist?(path) }

      it "deletes a pending migration file" do
        File.write(path, "class RemoveMe < ActiveRecord::Migration[8.1]\n  def change\n  end\nend\n")

        result = runner.delete("29990202000000")

        expect(result).to be_success
        expect(File.exist?(path)).to be(false)
      end

      it "refuses to delete a migration that has already been run" do
        result = runner.delete("20260526000001")

        expect(result).not_to be_success
        expect(result.output).to match(/already been run/)
        expect(File.exist?(Rails.root.join("db/migrate/20260526000001_create_sample_schema.rb"))).to be(true)
      end

      it "reports an unknown version without deleting anything" do
        result = runner.delete("11111111111111")

        expect(result).not_to be_success
        expect(result.output).to match(/No migration/)
      end
    end

    describe "#migrate" do
      it "shells out to bin/rails db:migrate, anchored to the host app, and captures output" do
        captured = nil
        process = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture2e) do |*args, **opts|
          captured = {args:, opts:}
          ["== migrated ==\n", process]
        end

        # Must reset to the host app's own bundle env (with_original_env), not a
        # fully-unbundled one — with_unbundled_env strips a custom BUNDLE_PATH
        # (Codespaces) and breaks a git-sourced gem. See MigrationRunner#run.
        expect(Bundler).to receive(:with_original_env).and_call_original

        result = runner.migrate

        expect(result).to be_success
        expect(result.output).to include("migrated")
        expect(captured[:args]).to include("db:migrate")
        expect(captured[:args]).to include(a_string_ending_with("bin/rails"))
        expect(captured[:opts]).to include(chdir: Rails.root.to_s)
      end
    end

    describe "#rollback" do
      it "shells out to db:rollback and reports failure" do
        captured = nil
        process = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture2e) do |*args, **opts|
          captured = args
          ["boom\n", process]
        end

        result = runner.rollback

        expect(result).not_to be_success
        expect(captured).to include("db:rollback")
      end
    end
  end
end
