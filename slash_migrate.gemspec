require_relative "lib/slash_migrate/version"

Gem::Specification.new do |spec|
  spec.name        = "slash_migrate"
  spec.version     = SlashMigrate::VERSION
  spec.authors     = [ "Raghu Betina" ]
  spec.email       = [ "raghu@firstdraft.com" ]
  spec.homepage    = "https://github.com/firstdraft/slash_migrate"
  spec.summary     = "A development-only GUI for common Rails database migrations."
  spec.description = "slash_migrate is a mountable, development-only Rails engine. " \
    "Mount it and visit /rails/migrate to generate models and migrations, design " \
    "indexes and defaults, and modify existing tables through a GUI that always " \
    "shows the migration code it will write."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.3"
end
