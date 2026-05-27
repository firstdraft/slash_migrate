require "rails_helper"

module SlashMigrate
  RSpec.describe MigrationFileWriter do
    after do
      Dir.glob(Rails.root.join("db/migrate/*_writer_spec_*.rb")).each { |file| File.delete(file) }
    end

    it "writes the source to a versioned file and returns its relative path" do
      path = described_class.write(basename: "writer_spec_alpha", source: "# alpha\n")

      expect(path).to match(%r{\Adb/migrate/\d{14}_writer_spec_alpha\.rb\z})
      expect(Rails.root.join(path).read).to eq("# alpha\n")
    end

    it "gives each migration a distinct, increasing version, even within one second" do
      first = described_class.write(basename: "writer_spec_one", source: "# one\n")
      second = described_class.write(basename: "writer_spec_two", source: "# two\n")

      expect(File.basename(second).to_i).to be > File.basename(first).to_i
    end

    it "refuses a second migration whose name duplicates an existing one" do
      described_class.write(basename: "writer_spec_dup", source: "# first\n")

      expect { described_class.write(basename: "writer_spec_dup", source: "# second\n") }
        .to raise_error(described_class::DuplicateError, /already exists/)
    end

    # A brand-new app has no db/migrate until its first migration — the very
    # thing a student generates here. Point the writer at a dir that doesn't
    # exist and confirm it's created rather than raising.
    it "creates the migrate directory when the app doesn't have one yet" do
      fresh = Rails.root.join("tmp", "writer_spec_fresh_#{SecureRandom.hex(4)}", "db", "migrate")
      allow_any_instance_of(described_class).to receive(:migrate_dir).and_return(fresh)
      expect(fresh).not_to exist

      described_class.write(basename: "writer_spec_freshdir", source: "# fresh\n")

      expect(fresh).to be_directory
      expect(fresh.glob("*_writer_spec_freshdir.rb")).not_to be_empty
    ensure
      FileUtils.rm_rf(Rails.root.join("tmp").glob("writer_spec_fresh_*"))
    end
  end
end
