module SlashMigrate
  # Builds a migration that adds one or more columns to an existing table.
  # add_column / add_reference are reversible, so this stays a plain def change.
  class AddColumnsMigration
    def self.from_params(table:, rows:)
      columns = Array(rows).map { |row| Column.from_params(resolve_self_reference(row, table)) }
      new(table: table, columns: columns)
    end

    # A self-reference here points at the table being modified, which already
    # exists. Reuse the create-table sentinel so the shared row partial works.
    def self.resolve_self_reference(row, table)
      return row unless row[:to_table].to_s == MigrationBuilder::SELF_TABLE

      hash = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row.to_h
      hash.symbolize_keys.merge(to_table: table)
    end

    attr_reader :table

    def initialize(table:, columns: [])
      @table = table.to_s
      @columns = columns.reject(&:blank?)
    end

    def any?
      @columns.any?
    end

    # Names of any references columns the student suffixed with _id, so the UI can
    # warn that references adds it for them.
    def references_with_id_suffix
      @columns.select(&:reference_with_id_suffix?).map(&:name)
    end

    def migration_class_name
      if @columns.one?
        "Add#{@columns.first.name.camelize}To#{@table.camelize}"
      else
        "AddColumnsTo#{@table.camelize}"
      end
    end

    def migration_filename
      stem = @columns.one? ? "add_#{@columns.first.name}_to_#{@table}" : "add_columns_to_#{@table}"
      "#{version}_#{stem}.rb"
    end

    def migration_source
      lines = []
      lines << "class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]"
      lines << "  def change"
      @columns.each do |column|
        lines << "    #{column.add_statement(@table)}"
        lines << "    #{column.index_statement(@table)}" if column.indexed?
      end
      lines << "  end"
      lines << "end"
      lines.join("\n") + "\n"
    end

    def write!
      path = Rails.root.join("db/migrate", migration_filename)
      File.write(path, migration_source)
      [path.relative_path_from(Rails.root).to_s]
    end

    private

    def version
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
  end
end
