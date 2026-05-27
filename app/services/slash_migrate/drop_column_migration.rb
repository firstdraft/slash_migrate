module SlashMigrate
  # Builds a migration that drops a column. remove_column is reversible only
  # when given the column's type (and we pass the rest of its definition too),
  # so a rollback re-adds the column faithfully — exactly the lesson it teaches.
  class DropColumnMigration
    attr_reader :column

    def initialize(table:, column:)
      @table = table.to_s
      @column = column
    end

    def migration_class_name
      "Remove#{column.name.camelize}From#{@table.camelize}"
    end

    def migration_basename
      "remove_#{column.name}_from_#{@table}"
    end

    def migration_source
      [
        "class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]",
        "  def change",
        "    #{column.remove_statement(@table)}",
        "  end",
        "end"
      ].join("\n") + "\n"
    end

    def write!
      [MigrationFileWriter.write(basename: migration_basename, source: migration_source)]
    end
  end
end
