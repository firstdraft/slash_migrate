require "tmpdir"

module SlashMigrate
  # Wraps Rails' own model generator so we can both (a) preview exactly what it
  # will write and (b) write it for real, from a single code path. Preview runs
  # the generator into a throwaway directory and reads the results back, so the
  # code a student sees is byte-identical to what `create!` produces — the same
  # guarantee that makes this a teaching tool rather than a black box.
  #
  # Only the generator-expressible grammar (type, references, index, unique
  # index) lives here. null:false / default belong to the modify-table flow,
  # where Rails' generator grammar can't reach but our own builder can.
  class ModelGenerator
    # Column types the new-model form offers. These are exactly the types Rails'
    # migration DSL understands; `references` becomes a belongs_to + foreign key.
    TYPES = %w[
      string text integer bigint float decimal boolean
      date datetime time references binary json
    ].freeze

    # The index choices the form offers, beyond "no index".
    INDEX_MODIFIERS = %w[index uniq].freeze

    # One column the student is adding. `index` is "", "index" or "uniq".
    Attribute = Struct.new(:name, :type, :index, keyword_init: true) do
      def to_arg
        modifier = index.to_s if INDEX_MODIFIERS.include?(index.to_s)
        [name, type, modifier].compact.join(":")
      end

      def blank?
        name.to_s.strip.empty?
      end
    end

    GeneratedFile = Struct.new(:relative_path, :content, keyword_init: true) do
      def migration?
        relative_path.start_with?("db/migrate/")
      end

      def model?
        relative_path.start_with?("app/models/")
      end

      def filename
        File.basename(relative_path)
      end
    end

    def self.from_params(name:, attributes:)
      attrs = Array(attributes).map do |attr|
        Attribute.new(name: attr[:name], type: attr[:type], index: attr[:index])
      end
      new(name: name, attributes: attrs)
    end

    attr_reader :name, :attributes

    def initialize(name:, attributes: [])
      @name = name.to_s.strip
      @attributes = attributes
    end

    def argv
      [name, *present_attributes.map(&:to_arg)]
    end

    # The equivalent terminal command, shown alongside the generated code so
    # students learn the grammar they could have typed themselves.
    def cli_command
      "bin/rails generate model #{argv.join(" ")}"
    end

    # Generates into a temp directory and returns the files without touching the
    # host app. Returns an array of GeneratedFile.
    def preview
      Dir.mktmpdir do |dir|
        invoke_generator(destination_root: dir)
        read_all(dir)
      end
    end

    # Runs the generator against the host app for real. `--skip` keeps it
    # non-interactive (it never blocks a web request on a conflict prompt).
    # Returns the files it created.
    def create!
      root = Rails.root.to_s
      invoke_generator(destination_root: root, extra_args: ["--skip"])
      read_created(root)
    end

    private

    def present_attributes
      attributes.reject(&:blank?)
    end

    def invoke_generator(destination_root:, extra_args: [])
      self.class.ensure_generators_loaded!
      Rails::Generators.invoke(
        "model",
        argv + ["--quiet"] + extra_args,
        behavior: :invoke,
        destination_root: destination_root
      )
    end

    # Everything the generator wrote into the (empty) temp directory.
    def read_all(dir)
      Dir.glob(File.join(dir, "**", "*"))
        .reject { |path| File.directory?(path) }
        .sort
        .map { |path| GeneratedFile.new(relative_path: path.sub("#{dir}/", ""), content: File.read(path)) }
    end

    # When generating into the live app we can't diff the whole tree, so read
    # back the known target paths instead.
    def read_created(root)
      table = name.underscore.pluralize
      migration = Dir.glob(File.join(root, "db/migrate/*_create_#{table}.rb")).max
      model = File.join(root, "app/models/#{name.underscore}.rb")

      [migration, model].compact.select { |p| File.exist?(p) }.map do |path|
        GeneratedFile.new(relative_path: path.sub("#{root}/", ""), content: File.read(path))
      end
    end

    class << self
      def ensure_generators_loaded!
        return if @generators_loaded

        Rails.application.load_generators
        @generators_loaded = true
      end
    end
  end
end
