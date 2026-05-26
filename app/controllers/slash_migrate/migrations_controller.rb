module SlashMigrate
  class MigrationsController < ApplicationController
    def index
      @migrations = runner.status
      @pending = runner.pending?
    end

    def run
      finish(runner.migrate, "Migrated.")
    end

    def rollback
      finish(runner.rollback, "Rolled back the last migration.")
    end

    private

    def runner
      @runner ||= MigrationRunner.new
    end

    # Post/redirect/get: stash the (truncated) command output in the flash so a
    # refresh doesn't re-run the task.
    def finish(result, message)
      flash[:migrate_output] = result.output.to_s.last(3000)
      if result.success?
        flash[:notice] = message
      else
        flash[:alert] = "Command failed — see the output below."
      end
      redirect_to migrations_path
    end
  end
end
