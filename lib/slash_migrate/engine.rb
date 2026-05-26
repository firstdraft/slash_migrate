module SlashMigrate
  class Engine < ::Rails::Engine
    isolate_namespace SlashMigrate

    # Mount the engine into the host app with no routes.rb edit required. The
    # mount lives inside a routes.append block, which the host's route set
    # evaluates *after* its own routes and after config initializers have run.
    # That deferral is deliberate: it lets a host's SlashMigrate.configure block
    # change mount_path / enabled_environments before these values are read, and
    # it re-evaluates on every development route reload.
    initializer "slash_migrate.mount" do |app|
      app.routes.append do
        if SlashMigrate.config.enabled_in?(Rails.env)
          mount SlashMigrate::Engine, at: SlashMigrate.config.mount_path
        end
      end
    end

    # Keep the engine reachable when the host app has pending migrations.
    # Runs after Active Record inserts CheckPending so there is something to
    # swap; a no-op when the page-load check isn't enabled (e.g. test/prod).
    initializer "slash_migrate.bypass_pending_migration_check",
      after: "active_record.migration_error" do |app|
      next unless app.config.active_record.migration_error == :page_load

      app.config.app_middleware.swap(
        ActiveRecord::Migration::CheckPending,
        SlashMigrate::PendingMigrationCheckProxy,
        file_watcher: app.config.file_watcher
      )
    end
  end
end
