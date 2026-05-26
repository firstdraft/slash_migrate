Rails.application.routes.draw do
  # SlashMigrate mounts itself (see SlashMigrate::Engine). A host app does not
  # add a `mount` line — this dummy app deliberately has none so it exercises
  # the self-mount the same way a real host would.
end
