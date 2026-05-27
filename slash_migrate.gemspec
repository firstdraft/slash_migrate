require_relative "lib/slash_migrate/version"

Gem::Specification.new do |spec|
  spec.name = "slash_migrate"
  spec.version = SlashMigrate::VERSION
  spec.authors = ["Raghu Betina"]
  spec.email = ["raghu@firstdraft.com"]
  spec.homepage = "https://github.com/firstdraft/slash_migrate"
  spec.summary = "A development-only GUI for common Rails database migrations."
  spec.description = "slash_migrate is a mountable, development-only Rails engine. " \
    "Mount it and visit /rails/migrate to generate models and migrations, design " \
    "indexes and defaults, and modify existing tables through a GUI that always " \
    "shows the migration code it will write."
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "CHANGELOG.md", "MIT-LICENSE", "README.md", "Rakefile"]
  end

  # Targets Ruby 3.4 and up; avoids syntax newer than that floor.
  spec.required_ruby_version = ">= 3.4.0"

  spec.add_dependency "rails", ">= 8.0"
end
