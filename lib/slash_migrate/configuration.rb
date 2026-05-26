module SlashMigrate
  # Host apps tune the engine through SlashMigrate.configure. Both values are
  # read at route-draw time (see Engine), so a host initializer can override
  # them even though the engine mounts itself.
  class Configuration
    attr_accessor :mount_path, :enabled_environments

    def initialize
      @mount_path = "/rails/migrate"
      @enabled_environments = ["development"]
    end

    def enabled_in?(env)
      enabled_environments.map(&:to_s).include?(env.to_s)
    end
  end
end
