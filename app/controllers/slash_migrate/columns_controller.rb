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

    private

    def require_table
      @table = params[:table_id]
      head :not_found unless inspector.exists?(@table)
    end

    def inspector
      @inspector ||= SchemaInspector.new
    end
  end
end
