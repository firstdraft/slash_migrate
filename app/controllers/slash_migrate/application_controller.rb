module SlashMigrate
  class ApplicationController < ActionController::Base
    # Make the engine's view helpers (sm_icon, ruby_code_body, callouts, …)
    # available in every engine view, regardless of how the host app configures
    # helper inclusion.
    helper SlashMigrate::ApplicationHelper
  end
end
