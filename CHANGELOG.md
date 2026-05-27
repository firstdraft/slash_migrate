# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-27

### Added

- Initial release: a development-only, self-mounting Rails engine that serves a
  GUI for common database migrations at `/rails/migrate`.
- Browse tables, columns, indexes, and foreign keys.
- Create models and migrations with column types, `null` / `default`, indexes
  (including unique), and `references` / foreign keys.
- Add, edit, and drop columns; add and drop indexes.
- Run, roll back, and delete pending migrations.
- A live preview of the migration and model code each action will generate.
- `SlashMigrate.configure` for `mount_path` and `enabled_environments`.

[0.1.0]: https://github.com/firstdraft/slash_migrate/releases/tag/v0.1.0
