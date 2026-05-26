module SlashMigrate
  # Serves the engine's vendored, precompiled JS/CSS straight from the gem, so
  # the UI works identically no matter how the host app handles assets (or
  # whether it has an asset pipeline at all). Files live under lib/ specifically
  # so the host's pipeline never scans or fingerprints them.
  class AssetsController < ActionController::Base
    # These are static files, served by GET. Rails' forgery protection otherwise
    # raises InvalidCrossOriginRequest when returning JavaScript over a plain GET
    # (its cross-origin <script> defense), which would block our own bundle.
    skip_forgery_protection

    ASSET_DIR = SlashMigrate::Engine.root.join("lib/slash_migrate/assets")
    CONTENT_TYPES = {".js" => "text/javascript", ".css" => "text/css"}.freeze

    def show
      # File.basename strips any path components, so :name can only ever resolve
      # to a file directly inside ASSET_DIR — no directory traversal.
      path = ASSET_DIR.join(File.basename(params[:name].to_s))
      raise ActionController::RoutingError, "Asset not found: #{params[:name]}" unless path.file?

      send_file path,
        type: CONTENT_TYPES.fetch(path.extname, "application/octet-stream"),
        disposition: "inline"
    end
  end
end
