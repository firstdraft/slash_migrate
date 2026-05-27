module SlashMigrate
  # Builds a migration that drops an existing index. remove_index is reversible
  # when given the column(s) — Rails re-creates the index on rollback — so we
  # always emit the `column:` form (plus unique:/name: when they aren't the
  # convention) and keep the migration a plain def change.
  class DropIndexMigration
    def initialize(table:, index:)
      @table = table.to_s
      @index = index
    end

    def columns
      Array(@index.columns).map(&:to_s)
    end

    def migration_class_name
      "RemoveIndexOn#{columns.map(&:camelize).join("And")}From#{@table.camelize}"
    end

    def migration_basename
      "remove_index_on_#{columns.join("_and_")}_from_#{@table}"
    end

    def remove_statement
      statement = "remove_index :#{@table}, column: #{column_argument}"
      statement += ", unique: true" if @index.unique
      statement += ", name: #{@index.name.inspect}" unless conventional_name?
      statement
    end

    def migration_source
      [
        "class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]",
        "  def change",
        "    #{remove_statement}",
        "  end",
        "end"
      ].join("\n") + "\n"
    end

    def write!
      [MigrationFileWriter.write(basename: migration_basename, source: migration_source)]
    end

    private

    def column_argument
      if columns.one?
        ":#{columns.first}"
      else
        "[#{columns.map { |column| ":#{column}" }.join(", ")}]"
      end
    end

    # Rails' default name; when the index uses it we can leave name: off and let
    # the rollback regenerate the same one.
    def conventional_name?
      @index.name.to_s == "index_#{@table}_on_#{columns.join("_and_")}"
    end
  end
end
