module SlashMigrate
  class ApplicationController < ActionController::Base
    # Make the engine's view helpers (sm_icon, ruby_code_body, callouts, …)
    # available in every engine view, regardless of how the host app configures
    # helper inclusion.
    helper SlashMigrate::ApplicationHelper

    # A builder refuses to write a migration whose name duplicates an existing
    # one (two same-named migrations break db:migrate); surface it as a friendly
    # alert rather than a 500.
    rescue_from MigrationFileWriter::DuplicateError do |error|
      redirect_to migrations_path, alert: error.message
    end
  end
end
