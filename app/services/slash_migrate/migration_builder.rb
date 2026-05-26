module SlashMigrate
  # Builds the migration (and model) for a brand-new table from a column plan.
  # Unlike the old generator-backed path, this emits the Ruby itself, so it can
  # express options the `rails g` grammar can't (null:, default:). A create_table
  # migration is always reversible, so the output is a plain `def change`.
  #
  # Fidelity with Rails' own output is guarded by a spec that diffs this against
  # `rails g model` for the subset both can express.
  class MigrationBuilder
    def self.from_params(name:, rows:)
      columns = Array(rows).map { |row| Column.from_params(row) }
      new(name: name, columns: columns)
    end

    attr_reader :name

    def initialize(name:, columns: [])
      @name = name.to_s.strip
      @columns = columns.reject(&:blank?)
    end

    def name_present?
      !name.empty?
    end

    def table_name
      name.underscore.pluralize
    end

    def model_class_name
      name.underscore.camelize
    end

    def migration_class_name
      "Create#{table_name.camelize}"
    end

    def migration_filename
      "#{version}_create_#{table_name}.rb"
    end

    def model_filename
      "#{name.underscore}.rb"
    end

    def migration_source
      lines = []
      lines << "class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]"
      lines << "  def change"
      lines << "    create_table :#{table_name} do |t|"
      @columns.each { |column| lines << "      #{column.to_ruby}" }
      lines << ""
      lines << "      t.timestamps"
      lines << "    end"
      index_columns.each { |column| lines << "    #{column.index_statement(table_name)}" }
      lines << "  end"
      lines << "end"
      lines.join("\n") + "\n"
    end

    def model_source
      lines = ["class #{model_class_name} < ApplicationRecord"]
      reference_columns.each { |column| lines << "  #{column.belongs_to_line}" }
      lines << "end"
      lines.join("\n") + "\n"
    end

    # Writes the migration and model into the host app. Skips an existing model
    # file rather than clobbering it. Returns the paths written, relative to root.
    def write!
      migration_path = Rails.root.join("db/migrate", migration_filename)
      model_path = Rails.root.join("app/models", model_filename)

      File.write(migration_path, migration_source)
      written = [migration_path]

      unless model_path.exist?
        File.write(model_path, model_source)
        written << model_path
      end

      written.map { |path| path.relative_path_from(Rails.root).to_s }
    end

    private

    def index_columns
      @columns.select(&:indexed?)
    end

    def reference_columns
      @columns.select(&:reference?)
    end

    def version
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
  end
end
