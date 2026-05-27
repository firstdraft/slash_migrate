module SlashMigrate
  class ModelsController < ApplicationController
    def new
      @builder = MigrationBuilder.new(name: "")
      @existing_tables = inspector.table_names
    end

    # Live preview: rebuilds the migration + model source on every (debounced)
    # form change and streams it back. Pure string building, no disk writes.
    def preview
      @builder = build_builder

      if @builder.name_present?
        @table_exists = inspector.exists?(@builder.table_name)
      else
        @hint = "Enter a model name to see the migration it will generate."
      end

      render_stream :preview
    rescue => e
      # Partial/invalid input shouldn't 500 the live preview; show the problem.
      @error = e.message
      render_stream :preview
    end

    def create
      builder = build_builder

      if inspector.exists?(builder.table_name)
        redirect_to(new_model_path, alert: "A table named #{builder.table_name} already exists.")
        return
      end

      written = builder.write!
      redirect_to migrations_path,
        notice: "Created #{written.join(", ")}. Run it below to apply."
    end

    private

    def build_builder
      MigrationBuilder.from_params(name: params[:model_name], rows: params[:attributes])
    end

    def inspector
      @inspector ||= SchemaInspector.new
    end
  end
end
