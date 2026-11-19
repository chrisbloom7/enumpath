# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Enumpath no longer depends on the unmaintained `mini_cache` and `to_regexp` gems (#47). Normalized paths are cached in a small built-in cache that is safe to share between threads and keeps at most 1,000 paths (least recently used dropped first); it used to grow without limit. `Enumpath.path_cache` now returns an `Enumpath::PathCache` with `get`, `set`, `get_or_set` and `reset`.
- Regular expressions in filters are parsed by Enumpath itself. A regular expression that is not valid now matches nothing instead of raising `RegexpError`, and the flags `e` and `s` (which already raised `ArgumentError` on Ruby 3.3 and later) are no longer accepted. `i`, `m`, `x`, `n` and `u` still work, as do `/pattern/` and `%r{pattern}`.
- Requiring Enumpath no longer adds `String#to_regexp` and `Regexp#to_regexp`, which came from the `to_regexp` gem. Code that relied on them needs its own dependency.
- The `logger` dependency is now `>= 1.4, < 3` (it was `>= 1.4`), so `gem build` no longer warns about an open-ended dependency. Enumpath only uses `Logger.new` and `<<`, and `logger` has been 1.x since 2017.

## [0.3.0] - 2026-11-19

### Fixed

- A child segment is resolved once. Under `property_resolver: :all` or a callable policy, a method that a segment calls (such as `pop` on an array) used to run twice, once to detect the operator and again to apply it (#51). A property repeated across the `&&` and `||` parts of one filter expression is also resolved once per member.

### Added

- A `regexp_timeout:` option on `Enumpath.apply`: the most seconds one regular expression match in a filter may take (default 1.0, or `nil` for no limit). A pattern that backtracks without end, such as `/^(a*)*\1$/`, no longer hangs the process on Ruby 3.2 and later (#60). A match that runs out of time does not match, and neither does any regular expression after it in the same call. On older Rubies the option is ignored.

## [0.2.1] - 2026-11-19

### Fixed

- A subscript expression can no longer exhaust CPU or memory (#52). Integer operands must fit in 64 bits, repeating a string or array with `*` is capped at 10,000 elements, integer powers with `**` at 1,024 bits, and `%` only applies to numbers. An expression over a limit matches nothing.
- A subscript expression that cannot be evaluated against the data, such as a division by zero or a string plus a number, matches nothing instead of raising `ZeroDivisionError`, `TypeError` or `RangeError`.

## [0.2.0] - 2026-11-19

### Fixed

- Array paths (an array of path segments, as the README describes) now work instead of raising a `TypeError`. Their segments are converted to strings.
- A path that is neither a String nor an Array raises an `ArgumentError` instead of an error from the path cache.
- README corrections: the property resolver is described in the Deviations section, a "Known limitations" section lists the open parser issues, and a few wrong examples and typos are fixed.

### Added

- A `property_resolver:` option on `Enumpath.apply` that controls which methods a path may call: `:safe` (the default), `:readers` (also any public no-argument method written in Ruby, including those of installed gems, and ActiveModel-style attributes; not read-only, for trusted data only), `:none`, `:all`, or a callable that receives the object and the method name.
- Members of Ruby 3.2+ `Data` objects resolve and iterate like `Struct` members.
- Support for Ruby 4.0: `logger` is now declared as a runtime dependency, since it is no longer a default gem there.

### Changed

- The README now leads with navigating nested Ruby objects (symbol keys, `Struct`s, plain objects, `OpenStruct`), adds an "Object traversal" section, and compares Enumpath with the `jsonpath` and `json_p3` gems.
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
