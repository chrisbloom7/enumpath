# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A `property_resolver:` option on `Enumpath.apply` that controls which methods a path may call: `:safe` (the default), `:none`, `:all`, or a callable that receives the object and the method name.

### Changed

- **BREAKING:** Paths only call read-only methods by default (`property_resolver: :safe`). A segment like `clear`, `pop`, `sort!` or `destroy` used to call that method and mutate the data; it now matches nothing. Custom methods on your own objects (other than `attr_reader`s) and on subclasses of core classes no longer resolve, nor do members of `Data` objects or methods on ranges, sets, enumerators and IO objects (for example `Enumpath.apply('first', 1..5)`). Pass `property_resolver: :all` to restore the old behavior, or a callable to allow specific methods.
- `Enumpath.apply` no longer removes the `:verbose` and `:result_type` keys from the options hash you pass in.

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
