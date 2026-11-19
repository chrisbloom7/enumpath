# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A `property_resolver:` option on `Enumpath.apply` that controls which methods a path may call: `:safe` (the default), `:readers` (also any public no-argument method written in Ruby, including those of installed gems, and ActiveModel-style attributes; not read-only, for trusted data only), `:none`, `:all`, or a callable that receives the object and the method name.
- Members of Ruby 3.2+ `Data` objects resolve and iterate like `Struct` members.
- Support for Ruby 4.0: `logger` is now declared as a runtime dependency, since it is no longer a default gem there.

### Changed

- **BREAKING:** Paths only call read-only methods by default (`property_resolver: :safe`). A segment like `clear`, `pop`, `sort!` or `destroy` used to call that method and mutate the data; it now matches nothing. Custom methods on your own objects (other than `attr_reader`s) and on subclasses of core classes no longer resolve, nor do methods on ranges, sets, enumerators and IO objects (for example `Enumpath.apply('first', 1..5)`). On plain objects an `attr_reader` value is now read from the instance variable instead of calling the method. By default, wildcards, filters and recursive descent no longer call `to_h` on objects other than arrays, hashes, structs and `Data` objects, so they find no members in them. Pass `property_resolver: :readers` to allow readers written in Ruby, including those of installed gems (not read-only), `property_resolver: :all` to restore the old behavior, or a callable to allow specific methods.
- `Enumpath.apply` no longer removes the `:verbose` and `:result_type` keys from the options hash you pass in.
- **Breaking:** the minimum supported Ruby version is now 2.6.0 (was 2.3.0). Ruby 2.3 to 2.5 are no longer supported; CI only ever tested 2.6 and up.
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
