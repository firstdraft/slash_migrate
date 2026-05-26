module SlashMigrate
  # Reads the live database schema through the Active Record connection. This is
  # the single source of truth the rest of the engine builds on: the table
  # browser renders from it, and the migration builder relies on it to know the
  # current type/default/index of a column so every generated migration can be
  # made reversible.
  class SchemaInspector
    # Active Record's own bookkeeping tables. Never shown or touched.
    INTERNAL_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    def table_names
      (connection.tables - INTERNAL_TABLES).sort
    end

    def exists?(name)
      table_names.include?(name.to_s)
    end

    def table(name)
      Table.new(name.to_s, connection)
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    # A thin, read-only view over one table's columns, indexes and foreign keys.
    class Table
      attr_reader :name

      def initialize(name, connection)
        @name = name
        @connection = connection
      end

      def columns
        @connection.columns(@name)
      end

      def indexes
        @connection.indexes(@name)
      end

      def foreign_keys
        @connection.foreign_keys(@name)
      end

      def primary_key
        @connection.primary_key(@name)
      end
    end
  end
end
