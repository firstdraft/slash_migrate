module SlashMigrate
  class TablesController < ApplicationController
    def index
      @table_names = inspector.table_names
    end

    def show
      head :not_found and return unless inspector.exists?(params[:id])

      @table = inspector.table(params[:id])
    end

    private

    def inspector
      @inspector ||= SchemaInspector.new
    end
  end
end
