module SlashMigrate
  class ColumnsController < ApplicationController
    before_action :require_table

    def new
      @migration = AddColumnsMigration.new(table: @table)
      @existing_tables = inspector.table_names
    end

    def preview
      @migration = AddColumnsMigration.from_params(table: @table, rows: params[:attributes])
      @hint = "Add a column to see the migration it will generate." unless @migration.any?
      render :preview, layout: false
    rescue => e
      @error = e.message
      render :preview, layout: false
    end

    def create
      migration = AddColumnsMigration.from_params(table: @table, rows: params[:attributes])

      unless migration.any?
        redirect_to(new_table_column_path(@table), alert: "Add at least one column.")
        return
      end

      written = migration.write!
      redirect_to table_path(@table),
        notice: "Created #{written.join(", ")}. Run the migration to apply it."
    end

    def edit
      @column = find_column
      head :not_found and return unless @column

      @drop_migration = DropColumnMigration.new(table: @table, column: @column)
    end

    def drop
      column = find_column
      head :not_found and return unless column

      written = DropColumnMigration.new(table: @table, column: column).write!
      redirect_to table_path(@table),
        notice: "Created #{written.join(", ")}. Run the migration to apply it."
    end

    def update_preview
      original = find_column
      @migration = original && EditColumnMigration.new(table: @table, original: original, desired: desired_column)
      @hint = "Change a value to see the migration it will generate." unless @migration&.changed?
      render :update_preview, layout: false
    rescue => e
      @error = e.message
      render :update_preview, layout: false
    end

    def update
      original = find_column
      head :not_found and return unless original

      migration = EditColumnMigration.new(table: @table, original: original, desired: desired_column)

      unless migration.changed?
        redirect_to(edit_table_column_path(@table, params[:name]), alert: "No changes to apply.")
        return
      end

      written = migration.write!
      redirect_to table_path(@table),
        notice: "Created #{written.join(", ")}. Run the migration to apply it."
    end

    private

    def require_table
      @table = params[:table_id]
      head :not_found unless inspector.exists?(@table)
    end

    def find_column
      ar_column = inspector.table(@table).columns.find { |column| column.name == params[:name] }
      ar_column && Column.from_schema(ar_column)
    end

    def desired_column
      Column.from_params(params.fetch(:column, {}))
    end

    def inspector
      @inspector ||= SchemaInspector.new
    end
  end
end
