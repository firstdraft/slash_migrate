module SlashMigrate
  # Builds the migration for editing an existing column — rename and/or change
  # its type, nullability, or default — by diffing the desired column against
  # the original (live) one and emitting only the operations that changed.
  #
  # change_column (a type change) isn't auto-reversible, so any edit that
  # includes one is written as explicit up/down. A pure rename stays a clean,
  # auto-reversible def change.
  class EditColumnMigration
    def initialize(table:, original:, desired:)
      @table = table.to_s
      @original = original
      @desired = desired
    end

    def changed?
      renamed? || type_changed? || null_changed? || default_changed?
    end

    # NOT NULL on a column with existing NULL rows fails without a backfill; flag it.
    def tightening_null?
      null_changed? && !@desired.allow_null?
    end

    def reversible_as_change?
      simple_rename?
    end

    def migration_class_name
      if simple_rename?
        "Rename#{@original.name.camelize}In#{@table.camelize}"
      else
        "Change#{column_name.camelize}In#{@table.camelize}"
      end
    end

    def migration_filename
      stem = simple_rename? ? "rename_#{@original.name}_in_#{@table}" : "change_#{column_name}_in_#{@table}"
      "#{version}_#{stem}.rb"
    end

    def migration_source
      body =
        if simple_rename?
          method_block("change", up_statements)
        else
          method_block("up", up_statements) + [""] + method_block("down", down_statements)
        end

      lines = ["class #{migration_class_name} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]"]
      lines += body
      lines << "end"
      lines.join("\n") + "\n"
    end

    def write!
      path = Rails.root.join("db/migrate", migration_filename)
      File.write(path, migration_source)
      [path.relative_path_from(Rails.root).to_s]
    end

    private

    def method_block(name, statements)
      ["  def #{name}", *statements.map { |statement| "    #{statement}" }, "  end"]
    end

    # The column's name after any rename — change ops run after the rename, so
    # they reference the new name.
    def column_name
      @desired.name
    end

    def renamed?
      @desired.name != @original.name
    end

    def type_changed?
      @desired.type != @original.type
    end

    def null_changed?
      @desired.allow_null? != @original.allow_null?
    end

    def default_changed?
      @desired.default != @original.default
    end

    def simple_rename?
      renamed? && !type_changed? && !null_changed? && !default_changed?
    end

    def up_statements
      statements = []
      statements << "rename_column :#{@table}, :#{@original.name}, :#{@desired.name}" if renamed?
      statements << "change_column :#{@table}, :#{column_name}, :#{@desired.type}" if type_changed?
      statements << "change_column_null :#{@table}, :#{column_name}, #{@desired.allow_null?}" if null_changed?
      statements << "change_column_default :#{@table}, :#{column_name}, from: #{@original.default_sql}, to: #{@desired.default_sql}" if default_changed?
      statements
    end

    # The reverse of up, in reverse order, so the column is renamed back last.
    def down_statements
      statements = []
      statements << "change_column_default :#{@table}, :#{column_name}, from: #{@desired.default_sql}, to: #{@original.default_sql}" if default_changed?
      statements << "change_column_null :#{@table}, :#{column_name}, #{@original.allow_null?}" if null_changed?
      statements << "change_column :#{@table}, :#{column_name}, :#{@original.type}" if type_changed?
      statements << "rename_column :#{@table}, :#{@desired.name}, :#{@original.name}" if renamed?
      statements
    end

    def version
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
  end
end
