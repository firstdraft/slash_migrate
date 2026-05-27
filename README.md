# slash_migrate

A development-only Rails engine that gives you a GUI for everyday database
migrations. Mount it, visit `/rails/migrate`, and create models, design columns
and indexes, and modify existing tables — while it shows you the exact migration
code it will write, so you pick up the commands as you go.

It's built for people still getting comfortable with Active Record migrations.

> **Development only.** slash_migrate writes real files to `db/migrate` and
> `app/models` and runs real migrations against your database. It mounts in your
> development environment only (configurable) and should never be loaded in
> production.

## Installation

Add it to the `development` group of your `Gemfile`:

```ruby
group :development do
  gem "slash_migrate"
end
```

Then install:

```bash
bundle install
```

There's no `routes.rb` change to make — the engine mounts itself at
`/rails/migrate` in development. Start your server and visit
<http://localhost:3000/rails/migrate>.

## What you can do

- Browse your tables, columns, indexes, and foreign keys.
- Create a model and its migration, with column types, `null` / `default`,
  indexes (including unique), and `references` / foreign keys.
- Add, edit, or drop columns on an existing table.
- Add or drop indexes.
- Run, roll back, or delete pending migrations.

Every screen previews the migration (and model) code it will generate before you
commit to it.

## Configuration

The defaults suit most apps. To change them, add an initializer:

```ruby
# config/initializers/slash_migrate.rb
SlashMigrate.configure do |config|
  config.mount_path = "/rails/migrate"          # where the engine mounts
  config.enabled_environments = ["development"]  # environments it runs in
end
```

The engine mounts itself when routes are drawn, which happens after your
initializers run — so overriding these values here takes effect.

## Requirements

- Ruby >= 3.4
- Rails >= 8.1.3

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/firstdraft/slash_migrate>.

## License

Released under the [MIT License](MIT-LICENSE).
