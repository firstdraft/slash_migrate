source "https://rubygems.org"

# Specify your gem's dependencies in slash_migrate.gemspec.
gemspec

gem "puma"

gem "sqlite3"

gem "propshaft"

group :development, :test do
  gem "appraisal"
  gem "rspec-rails"
  gem "standard"
  # NOT a runtime dependency (the gemspec needs only Rails). It's here so the
  # suite runs against the common "host app has turbo-rails" config: turbo-rails
  # registers the text/vnd.turbo-stream.html MIME, which drives request-format
  # negotiation for the engine's hand-written streamed responses.
  gem "turbo-rails"
end

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
