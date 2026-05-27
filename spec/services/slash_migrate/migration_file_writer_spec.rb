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
  end
end
