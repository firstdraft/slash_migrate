require "rails_helper"

module SlashMigrate
  RSpec.describe MigrationRunner do
    subject(:runner) { described_class.new }

    describe "#status / #pending?" do
      it "reports the applied sample migration as up, with nothing pending" do
        sample = runner.status.find { |migration| migration.version == "20260526000001" }

        expect(sample).to be_present
        expect(sample.applied?).to be(true)
        expect(sample.name).to eq("Create sample schema")
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

    describe "#migrate" do
      it "shells out to bin/rails db:migrate, anchored to the host app, and captures output" do
        captured = nil
        process = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture2e) do |*args, **opts|
          captured = {args:, opts:}
          ["== migrated ==\n", process]
        end

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
