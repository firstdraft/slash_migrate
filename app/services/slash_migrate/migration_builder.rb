module SlashMigrate
  # Builds the migration (and model) for a brand-new table from a column plan.
  # Unlike the old generator-backed path, this emits the Ruby itself, so it can
  # express options the `rails g` grammar can't (null:, default:). A create_table
  # migration is always reversible, so the output is a plain `def change`.
  #
  # Fidelity with Rails' own output is guarded by a spec that diffs this against
  # `rails g model` for the subset both can express.
  class MigrationBuilder
    # The "references table" picker uses this sentinel for a self-reference,
    # since the table being created doesn't exist to list yet. We resolve it to
    # the new table's name here, where it's known.
    SELF_TABLE = "__self__".freeze

    def self.from_params(name:, rows:)
      table = name.to_s.strip.underscore.pluralize
      columns = Array(rows).map { |row| Column.from_params(resolve_self_reference(row, table)) }
      new(name: name, columns: columns)
    end

    def self.resolve_self_reference(row, table)
      return row unless row[:to_table].to_s == SELF_TABLE

      hash = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
      hash.symbolize_keys.merge(to_table: table)
    end

    attr_reader :name

    def initialize(name:, columns: [])
      @name = name.to_s.strip
      @columns = columns.reject(&:blank?)
    end

    def name_present?
      !name.empty?
    end

    # A model is singular and its table plural, whatever the student typed.
    # classify and tableize are the same inflections Active Record uses to map
    # between a model and its table, so "Articles", "articles", and "Article"
    # all yield the Article model on the articles table.
    def table_name
      name.tableize
    end

    def model_class_name
      name.classify
    end

    # True when the input was plural and we singularized it, so the UI can warn.
    def pluralized_input?
      name.present? && name != name.singularize
    end

    def migration_class_name
      "Create#{table_name.camelize}"
    end

    def migration_basename
      "create_#{table_name}"
    end

    def model_filename
      "#{name.classify.underscore}.rb"
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
      written = [MigrationFileWriter.write(basename: migration_basename, source: migration_source)]

      model_path = Rails.root.join("app/models", model_filename)
      unless model_path.exist?
        model_path.dirname.mkpath # a namespaced model (app/models/admin/…) may need its dir
        File.write(model_path, model_source)
        written << model_path.relative_path_from(Rails.root).to_s
      end

      written
    end

    private

    def index_columns
      @columns.select(&:indexed?)
    end

    def reference_columns
      @columns.select(&:reference?)
    end
  end
end
