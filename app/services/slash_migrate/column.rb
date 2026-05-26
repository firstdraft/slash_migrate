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
        index: row[:index]
      )
    end

    attr_reader :name, :type, :default, :limit, :precision, :scale, :index

    def initialize(name:, type: "string", null: true, default: nil,
      limit: nil, precision: nil, scale: nil, index: "", foreign_key: true)
      @name = name.to_s.strip
      @type = type.to_s
      @null = null
      @default = presence(default)
      @limit = presence(limit)
      @precision = presence(precision)
      @scale = presence(scale)
      @index = index.to_s
      @foreign_key = foreign_key
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

    def belongs_to_line
      "belongs_to :#{name}"
    end

    private

    def format_options
      options = reference? ? reference_options : column_options
      options.empty? ? "" : ", #{options.join(", ")}"
    end

    def reference_options
      options = []
      options << "null: false" unless allow_null?
      options << "foreign_key: true" if foreign_key?
      options
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
