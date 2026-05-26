# Demonstrates the host-app configuration API and lets request specs reach the
# mounted engine, which is development-only by default.
SlashMigrate.configure do |config|
  config.enabled_environments = %w[development test]
end
