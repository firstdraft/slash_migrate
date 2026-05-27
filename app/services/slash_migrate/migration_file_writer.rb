module SlashMigrate
  # Writes a migration file on behalf of every builder, so file creation is
  # collision-safe in one place:
  #
  #   - the version is collision-free (mirrors Rails' own next_migration_number),
  #     so two migrations generated in the same second still get distinct,
  #     ordered versions rather than clashing;
  #   - the write is exclusive, so a re-submitted form can't clobber a file;
  #   - a second pending migration with the same name is refused, since duplicate
  #     migration classes break db:migrate — caught here with a clear message
  #     instead of a cryptic failure when the student runs it.
  class MigrationFileWriter
    DuplicateError = Class.new(StandardError)

    def self.write(basename:, source:)
      new(basename: basename, source: source).write
    end

    # basename: the slug with no version and no extension, e.g. "create_posts".
    def initialize(basename:, source:)
      @basename = basename
      @source = source
    end

    def write
      if (existing = existing_with_same_name)
        raise DuplicateError, "A migration named #{@basename.camelize} already exists (#{existing}). " \
          "Run or delete it before generating another."
      end

      path = migrate_dir.join("#{next_version}_#{@basename}.rb")
      path.open(File::WRONLY | File::CREAT | File::EXCL) { |file| file.write(@source) }
      path.relative_path_from(Rails.root).to_s
    end

    private

    # A version that is both a current UTC timestamp and strictly greater than
    # every existing migration — the same rule Rails' generators use, so a
    # same-second collision still yields a distinct, ordered version (and one
    # that stays within Rails' "not in the future" validity window).
    def next_version
      number = current_migration_number + 1
      if ActiveRecord.timestamped_migrations
        [Time.now.utc.strftime("%Y%m%d%H%M%S"), format("%.14d", number)].max
      else
        format("%.14d", number)
      end
    end

    def current_migration_number
      existing_files.map { |path| File.basename(path).to_i }.max || 0
    end

    def existing_with_same_name
      existing_files.map { |path| File.basename(path) }
        .find { |name| name.sub(/\A\d+_/, "").chomp(".rb") == @basename }
    end

    def existing_files
      Dir.glob(migrate_dir.join("*.rb"))
    end

    def migrate_dir
      Rails.root.join("db/migrate")
    end
  end
end
