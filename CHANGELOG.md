# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The published gem now contains only `lib/`, `LICENSE` and `README.md`. It used to ship the whole repository, including the generated `docs/`.
- RubyGems.org now requires multi-factor authentication to publish the gem (`rubygems_mfa_required`).
- The API documentation is generated with Redcarpet and lives in `docs/`.
- Continuous integration also runs on Ruby 3.1.
- Updated development dependencies.

## [0.1.2] - 2021-04-07

### Fixed

- A `Proc` error on Ruby 3.0.
- A gemspec problem affecting Bundler.

### Changed

- Updated development dependencies, including `rake` 12.3.3 to address a security vulnerability, and added `yard` as a development dependency.
- Continuous integration moved to GitHub Actions.

## [0.1.1] - 2018-09-07

### Changed

- Gemspec updates.

## [0.1.0] - 2018-09-07

### Added

- A rewrite of the original Enumpath project with full JSONPath compatibility.
- YARD documentation, with a rake task (`rake yard`) that generates it.
