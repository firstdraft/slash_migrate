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

    private

    # Render a hand-written <turbo-stream> template (the engine ships no
    # turbo-rails). The html format is forced deliberately: when the host app
    # *does* have turbo-rails, it registers the text/vnd.turbo-stream.html MIME,
    # so a request asking for a Turbo Stream negotiates to the :turbo_stream
    # format and a bare `render :preview` would look for a nonexistent
    # preview.turbo_stream.erb and raise MissingTemplate (500). Pass content_type
    # when the response is applied by native Turbo form handling (it keys off the
    # header); the live previews are applied client-side by
    # Turbo.renderStreamMessage and don't need it.
    def render_stream(template, content_type: nil)
      options = {layout: false, formats: [:html]}
      options[:content_type] = content_type if content_type
      render(template, **options)
    end
  end
end
