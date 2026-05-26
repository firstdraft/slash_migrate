require "slash_migrate/version"
require "slash_migrate/configuration"
require "slash_migrate/pending_migration_check_proxy"
require "slash_migrate/engine"

module SlashMigrate
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end
  end
end
