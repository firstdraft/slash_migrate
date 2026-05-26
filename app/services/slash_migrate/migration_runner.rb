require "open3"

module SlashMigrate
  # Reports migration status and runs db:migrate / db:rollback.
  #
  # Status is computed directly from the migration files and the
  # schema_migrations table rather than through MigrationContext, whose
  # migrations_paths are relative to the process cwd (which isn't Rails.root in
  # a mounted-engine dev setup). Running shells out to bin/rails so students see
  # the real task output; chdir keeps it anchored to the host app.
  class MigrationRunner
    Migration = Struct.new(:version, :name, :applied, keyword_init: true) do
      def applied? = applied
      def status = applied ? "up" : "down"
    end

    Result = Struct.new(:output, :success, keyword_init: true) do
      def success? = success
    end

    def status
      applied = applied_versions
      migration_files.map do |path|
        version, name = parse(path)
        Migration.new(version: version, name: name, applied: applied.include?(version))
      end
    end

    def pending?
      status.any? { |migration| !migration.applied? }
    end

    def applied_any?
      status.any?(&:applied?)
    end

    def migrate
      run("db:migrate")
    end

    def rollback
      run("db:rollback")
    end

    # Deletes a migration file, but only when it hasn't been run (pending, or
    # already rolled back). Deleting an applied migration would orphan its
    # schema_migrations row and leave it unreversible, so we refuse.
    def delete(version)
      version = version.to_s
      migration = status.find { |candidate| candidate.version == version }

      return Result.new(output: "No migration #{version} found.", success: false) unless migration
      if migration.applied?
        return Result.new(output: "“#{migration.name}” has already been run — roll it back before deleting.", success: false)
      end

      path = migration_files.find { |file| File.basename(file).start_with?("#{version}_") }
      File.delete(path) if path
      Result.new(output: "Deleted “#{migration.name}”.", success: true)
    end

    private

    def run(task)
      output, process = Bundler.with_unbundled_env do
        Open3.capture2e({"RAILS_ENV" => Rails.env.to_s}, rails_bin, task, chdir: Rails.root.to_s)
      end
      Result.new(output: output, success: process.success?)
    end

    def rails_bin
      Rails.root.join("bin/rails").to_s
    end

    def migration_files
      Dir.glob(Rails.root.join("db/migrate/*.rb")).sort
    end

    def parse(path)
      version, slug = File.basename(path, ".rb").split("_", 2)
      [version, slug.to_s.humanize]
    end

    def applied_versions
      connection = ActiveRecord::Base.connection
      return [] unless connection.table_exists?("schema_migrations")

      connection.select_values("SELECT version FROM schema_migrations").map(&:to_s)
    end
  end
end
