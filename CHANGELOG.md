# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **The menu bar icon never appeared.** `MenuBarManager` was never constructed, so no
  `NSStatusItem` was created: no icon, no *Browsers* / *Fallback Browser* submenus, no
  *Set as Default Browser*, no *Quit*, and no login-item registration at launch. URL
  routing kept working the whole time — `application(_:open:)` bootstraps itself — which
  made the app look half-alive rather than broken. ([#17](https://github.com/hexember/active-browser/pull/17))
- **`make release` did nothing.** The target was listed in `.PHONY` but its recipe was
  absent, so the release workflow produced no artefacts and `v0.1.0` published without
  them. ([#16](https://github.com/hexember/active-browser/pull/16))

Both defects were introduced by merges that dropped a hunk while keeping the surrounding
code, so everything still compiled and every branch-level check passed.

### Added

- Continuous integration on every push and pull request: builds both configurations,
  assembles and signs the bundle, runs `make release`, verifies the checksum, and asserts
  the wiring that the two fixes above restored.
- `LICENSE` (MIT), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, issue and pull
  request templates.

### Changed

- The repository moved to the `hexember` account. The installer is now served from
  `https://activebrowser.app/install.sh`; the raw GitHub URL is kept as a fallback (see
  the README).

## [0.1.0] - 2026-09-22

Initial release.

### Added

- Routes every `http`/`https` link to the most recently focused browser.
- Menu bar agent (`LSUIElement`) showing the live routing target and recent focus order.
- *Browsers* submenu to include or exclude browsers, with a guard that prevents the
  include set from ever becoming empty.
- *Fallback Browser* submenu for when no browser has been focused yet; the selection
  migrates automatically if that browser is excluded.
- *Set as Default Browser* and *Launch at Login*.
- `install.sh` one-liner installer: verifies the SHA-256 checksum and validates the
  bundle before replacing anything on disk.
- `make release` and a tag-triggered GitHub Actions workflow publishing
  `ActiveBrowser.app.zip` and `SHA256SUMS`.

### Known issues

> **This release is not usable.** The published binary has no menu bar icon, so none of
> the menu features above can be reached. Link routing works. Use a build from `main`
> until the next release.

[Unreleased]: https://github.com/hexember/active-browser/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hexember/active-browser/releases/tag/v0.1.0
