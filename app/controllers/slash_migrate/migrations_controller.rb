module SlashMigrate
  class MigrationsController < ApplicationController
    def index
      load_migrations
    end

    def run
      @result = runner.migrate
      @command = "rails db:migrate"
      stream_result
    end

    def rollback
      @result = runner.rollback
      @command = "rails db:rollback"
      stream_result
    end

    def destroy
      @result = runner.delete(params[:version])
      stream_result
    end

    private

    def runner
      @runner ||= MigrationRunner.new
    end

    def load_migrations
      @migrations = runner.status
      @pending = runner.pending?
    end

    # Update the page in place with a Turbo Stream instead of redirecting and
    # carrying the command output in the flash: that output can be large, and
    # CookieStore (the Rails default) caps the session at 4 KB, so a redirect
    # could overflow the cookie and crash the host app. The engine ships no
    # turbo-rails, so the <turbo-stream> is written by hand (see stream.html.erb)
    # and rendered via render_stream, which forces the html template and sets the
    # turbo-stream MIME; native Turbo form handling applies it. A plain refresh
    # re-issues the GET, so the task never re-runs.
    def stream_result
      load_migrations
      render_stream :stream, content_type: "text/vnd.turbo-stream.html"
    end
  end
end
