# Changelog

All notable changes to this project are documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow the `pubspec.yaml` scheme `major.minor.patch+build`; a
release is tagged `v<version>` (e.g. `v1.2.0+3`).

## [1.2.0+3] - 2026-11-16

### Added

- Shared links now open the prefilled edit form instead of saving
  straight away: the URL and title are extracted from the shared text,
  default tags/privacy applied, and the entry is only saved after you
  confirm in the form — pressing back cancels. ([#1](https://github.com/k997/shaarli_android/issues/1))
- New settings switch **Edit before saving shared links** (default on)
  restores the previous save-immediately behaviour.
- The title and description are now fetched automatically when a URL is
  prefilled into the add/edit form (previously the fetch only ran after
  manually editing the URL field).

### Fixed

- Instant-save mode now shows a failure snackbar when the server is not
  configured or the request fails (previously the error was swallowed).
- The settings and add/edit forms no longer overflow the bottom on
  short screens; both are scrollable now.
