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
        # Normalize to a String, matching the form-input path. Active Record
        # casts defaults differently across versions and adapters (Rails 8.0
        # hands back "0", 8.1 casts it to 0; a boolean default arrives as
        # false), and the rest of this class — to_s.strip.presence, downcase,
        # literal interpolation — assumes a string.
        default: ar_column.default&.to_s,
        limit: meta&.limit,
        precision: meta&.precision,
        scale: meta&.scale
      )
    end

    attr_reader :name, :type, :default, :limit, :precision, :scale, :index

    def initialize(name:, type: "string", null: true, default: nil,
      limit: nil, precision: nil, scale: nil, index: "", to_table: nil)
      @name = name.to_s.strip
      @type = type.to_s
      @null = null
      @default = default.to_s.strip.presence
      @limit = limit.to_s.strip.presence
      @precision = precision.to_s.strip.presence
      @scale = scale.to_s.strip.presence
      @index = index.to_s
      @to_table = to_table.to_s.strip.presence
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

    # A references column gets a foreign key only when it's pointed at a real
    # target table; with no target it's just the _id column (plus its index),
    # which always migrates cleanly even if no such table exists yet.
    def foreign_key?
      !@to_table.nil?
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
      options = []
      options << "class_name: #{@to_table.classify.inspect}" if foreign_key? && !conventional_reference?
      options << requiredness_option if requiredness_option
      options.empty? ? "belongs_to :#{name}" : "belongs_to :#{name}, #{options.join(", ")}"
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
        options << (conventional_reference? ? "foreign_key: true" : "foreign_key: { to_table: :#{@to_table} }")
      end
      options
    end

    # A foreign key needs no to_table: when the chosen table is the one Rails
    # would infer from the column name anyway.
    def conventional_reference?
      @to_table == name.pluralize
    end

    # Keep the association's optionality in step with the column's nullability:
    # a nullable column should be an optional belongs_to, a NOT NULL one
    # required. We only state it when it differs from the app's
    # belongs_to_required_by_default, so the generated model matches that app's
    # conventions rather than hard-coding one.
    def requiredness_option
      desired_required = !allow_null?
      default_required = !!ActiveRecord::Base.belongs_to_required_by_default
      return nil if desired_required == default_required

      desired_required ? "required: true" : "optional: true"
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
  end
end
