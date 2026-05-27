module SlashMigrate
  # Builds a migration that adds an index to an existing table — single-column
  # or composite, optionally unique, with an optional explicit name. add_index
  # is reversible, so this stays a plain def change.
  class AddIndexMigration
    def self.from_params(table:, columns:, unique: nil, name: nil)
      new(table: table, columns: columns, unique: %w[unique true 1].include?(unique.to_s), name: name)
    end

    attr_reader :table, :columns

    def initialize(table:, columns: [], unique: false, name: nil)
      @table = table.to_s
      @columns = Array(columns).map { |column| column.to_s.strip }.reject(&:empty?)
      @unique = unique
      @name = name.to_s.strip
    end

    def any?
      @columns.any?
    end

    def unique?
      @unique
    end

    def migration_class_name
      "AddIndexOn#{@columns.map(&:camelize).join("And")}To#{@table.camelize}"
    end

    def migration_basename
      "add_index_on_#{@columns.join("_and_")}_to_#{@table}"
    end

    def index_statement
      statement = "add_index :#{@table}, #{column_argument}"
      statement += ", unique: true" if unique?
      statement += ", name: #{@name.inspect}" unless @name.empty?
      statement
    end

    def migration_source
      [
        "class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]",
        "  def change",
        "    #{index_statement}",
        "  end",
        "end"
      ].join("\n") + "\n"
    end

    def write!
      [MigrationFileWriter.write(basename: migration_basename, source: migration_source)]
    end

    private

    # A single column reads as a bare symbol; two or more as an array — the
    # idiomatic composite-index form.
    def column_argument
      if @columns.one?
        ":#{@columns.first}"
      else
        "[#{@columns.map { |column| ":#{column}" }.join(", ")}]"
      end
    end
  end
end
