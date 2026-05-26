module SlashMigrate
  # A single column in a migration plan. Renders itself as the `t.<type> :name`
  # line for a create_table block, including the options Rails' generator
  # grammar can't express (null:, default:). Shared by the new-model flow and,
  # later, the modify-table flow.
  class Column
    TYPES = %w[
      string text integer bigint float decimal boolean
      date datetime time references binary json
    ].freeze
    REFERENCE_TYPES = %w[references belongs_to].freeze
    INDEX_CHOICES = %w[index uniq].freeze

    def self.from_params(row)
      new(
        name: row[:name],
        type: row[:type],
        null: row[:null].to_s != "not_null",
        default: row[:default],
        index: row[:index],
        to_table: row[:to_table]
      )
    end

    # Builds a Column from an Active Record column (the live schema), so the
    # engine can reconstruct a column's current definition — needed to make a
    # drop reversible and to pre-fill the edit form.
    def self.from_schema(ar_column)
      meta = ar_column.sql_type_metadata
      new(
        name: ar_column.name,
        type: ar_column.type.to_s,
        null: ar_column.null,
        default: ar_column.default,
        limit: meta&.limit,
        precision: meta&.precision,
        scale: meta&.scale
      )
    end

    attr_reader :name, :type, :default, :limit, :precision, :scale, :index

    def initialize(name:, type: "string", null: true, default: nil,
      limit: nil, precision: nil, scale: nil, index: "", foreign_key: true, to_table: nil)
      @name = name.to_s.strip
      @type = type.to_s
      @null = null
      @default = presence(default)
      @limit = presence(limit)
      @precision = presence(precision)
      @scale = presence(scale)
      @index = index.to_s
      @foreign_key = foreign_key
      @to_table = presence(to_table)
    end

    def blank?
      name.empty?
    end

    def reference?
      REFERENCE_TYPES.include?(type)
    end

    def allow_null?
      @null
    end

    def foreign_key?
      @foreign_key
    end

    # References are indexed inline by Rails, so they never get a separate
    # add_index line.
    def indexed?
      !reference? && INDEX_CHOICES.include?(index)
    end

    def unique_index?
      index == "uniq"
    end

    # The line that goes inside `create_table do |t|`.
    def to_ruby
      "t.#{type} :#{name}#{format_options}"
    end

    def index_statement(table_name)
      statement = "add_index :#{table_name}, :#{name}"
      statement += ", unique: true" if unique_index?
      statement
    end

    # The standalone statement that adds this column to an existing table,
    # reusing the same option rendering as the create_table line.
    def add_statement(table_name)
      if reference?
        options = reference_options
        statement = "add_reference :#{table_name}, :#{name}"
      else
        options = column_options
        statement = "add_column :#{table_name}, :#{name}, :#{type}"
      end
      statement += ", #{options.join(", ")}" unless options.empty?
      statement
    end

    # remove_column is only reversible when given the column's type; we also
    # pass the other options so a rollback recreates the column faithfully.
    def remove_statement(table_name)
      statement = "remove_column :#{table_name}, :#{name}, :#{type}"
      statement += ", #{column_options.join(", ")}" unless column_options.empty?
      statement
    end

    # The default rendered as a Ruby literal (or "nil"), for change_column_default's
    # from:/to: arguments.
    def default_sql
      @default.nil? ? "nil" : rendered_default
    end

    def belongs_to_line
      if conventional_reference?
        "belongs_to :#{name}"
      else
        "belongs_to :#{name}, class_name: #{target_table.classify.inspect}"
      end
    end

    private

    def format_options
      options = reference? ? reference_options : column_options
      options.empty? ? "" : ", #{options.join(", ")}"
    end

    def reference_options
      options = []
      options << "null: false" unless allow_null?
      if foreign_key?
        options << (conventional_reference? ? "foreign_key: true" : "foreign_key: { to_table: :#{target_table} }")
      end
      options
    end

    # The table this reference points at: the explicit pick, or Rails' default
    # inference from the column name when left blank.
    def target_table
      @to_table || name.pluralize
    end

    def conventional_reference?
      target_table == name.pluralize
    end

    def column_options
      options = []
      options << "limit: #{limit}" if limit
      options << "precision: #{precision}" if precision
      options << "scale: #{scale}" if scale
      options << "default: #{rendered_default}" if @default
      options << "null: false" unless allow_null?
      options
    end

    def rendered_default
      case type
      when "boolean"
        %w[true t 1 yes].include?(@default.downcase) ? "true" : "false"
      when "integer", "bigint", "float", "decimal"
        @default
      else
        @default.inspect
      end
    end

    def presence(value)
      string = value.to_s.strip
      string.empty? ? nil : string
    end
  end
end
