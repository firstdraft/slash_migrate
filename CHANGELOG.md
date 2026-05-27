# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-05-27

### Fixed

- Running a migration or rollback from the GUI no longer crashes the host app
  with `ActionDispatch::Cookies::CookieOverflow`. The migrations page now updates
  in place via a Turbo Stream rather than carrying the command output through the
  4 KB session cookie.
- Live previews and migration actions no longer return 500
  (`ActionView::MissingTemplate`) in host apps that have `turbo-rails` installed;
  the engine's hand-written stream templates are pinned to the HTML format.
- `db:migrate` / `db:rollback` no longer fail with "… is not yet checked out"
  when the host app uses a custom `BUNDLE_PATH` (e.g. GitHub Codespaces): the task
  now shells out within the host's own bundle environment.
- Restored two margins — above the "Drop this column" panel and below the
  migration output — that an internal spacing-token rename had silently dropped,
  and moved those values into CSS so a future rename can't break them again.

### Changed

- Migrations run / rollback / delete now update the page in place via Turbo
  Stream instead of reloading after a redirect.
- The nav brand and page titles follow the configured mount path, and the table
  stats line pluralizes correctly.

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

[0.1.1]: https://github.com/firstdraft/slash_migrate/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/firstdraft/slash_migrate/releases/tag/v0.1.0
