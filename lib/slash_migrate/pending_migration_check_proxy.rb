module SlashMigrate
  # In development Rails inserts ActiveRecord::Migration::CheckPending, which
  # raises PendingMigrationError on every request when an unrun migration
  # exists. Since this engine's whole job is to create migrations, that check
  # would lock the student out of the very GUI they need to run them.
  #
  # This proxy replaces CheckPending: it delegates to the real check for the
  # host app's routes (preserving that safety net everywhere else) but skips it
  # for requests under the engine's mount path, so the tool stays reachable.
  class PendingMigrationCheckProxy
    def initialize(app, **options)
      @app = app
      @inner = ActiveRecord::Migration::CheckPending.new(app, **options)
    end

    def call(env)
      if engine_request?(env)
        @app.call(env)
      else
        @inner.call(env)
      end
    end

    private

    def engine_request?(env)
      path = env["PATH_INFO"].to_s
      mount = SlashMigrate.config.mount_path
      path == mount || path.start_with?("#{mount}/")
    end
  end
end
