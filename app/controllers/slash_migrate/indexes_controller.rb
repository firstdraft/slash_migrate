module SlashMigrate
  class IndexesController < ApplicationController
    before_action :require_table

    def new
      @columns = inspector.table(@table).columns.map(&:name)
      @migration = AddIndexMigration.new(table: @table)
    end

    def preview
      @migration = build_migration
      @hint = "Pick a column to index to see the migration it will generate." unless @migration.any?
      render_stream :preview
    rescue => e
      @error = e.message
      render_stream :preview
    end

    def create
      migration = build_migration

      unless migration.any?
        redirect_to(new_table_index_path(@table), alert: "Pick at least one column to index.")
        return
      end

      written = migration.write!
      redirect_to migrations_path, notice: "Created #{written.join(", ")}. Run it below to apply."
    end

    def drop
      index = inspector.table(@table).indexes.find { |candidate| candidate.name == params[:name] }
      head :not_found and return unless index

      written = DropIndexMigration.new(table: @table, index: index).write!
      redirect_to migrations_path, notice: "Created #{written.join(", ")}. Run it below to apply."
    end

    private

    def build_migration
      AddIndexMigration.from_params(table: @table, columns: params[:columns], unique: params[:unique], name: params[:name])
    end

    def require_table
      @table = params[:table_id]
      head :not_found unless inspector.exists?(@table)
    end

    def inspector
      @inspector ||= SchemaInspector.new
    end
  end
end
