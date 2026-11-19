# CLAUDE.md

Enumpath is a Ruby gem: JSONPath-compatible path expressions over nested Ruby objects (hashes, arrays,
structs). Read `CONTRIBUTING.md` before opening a PR (open an issue first unless one exists).

## Commands

```bash
bin/setup                       # bundle install
bundle exec rake                # default task = `rake spec`: the full spec suite, what CI runs
bundle exec rspec               # same suite, run directly
bundle exec rspec spec/enumpath/operator/slice_spec.rb   # one file
BUNDLE_GEMFILE=gemfiles/rubocop.gemfile bundle exec rubocop   # lint, as CI does
bundle exec rake yard           # regenerate docs/ (redcarpet markdown)
bin/console                     # IRB console with the gem loaded
bundle exec ruby benchmarks/baseline.rb --compare benchmarks/baseline-0.2.1.json   # performance vs the recorded baseline
```

`rubocop` is not in the main bundle (it needs Ruby >= 2.7); it lives in `gemfiles/rubocop.gemfile`, which the
CI `lint` job uses (run it locally with the `BUNDLE_GEMFILE=` command above, on Ruby >= 2.7). Config: line
length 120, specs exempt from BlockLength; `.rubocop_todo.yml` parks existing offenses (fix those rather
than adding new entries).

## Architecture

- `lib/enumpath.rb`: public entry point (`Enumpath.apply(path, enum, options = {})`, `Enumpath.verbose`).
- `lib/enumpath/path.rb`, `path/normalized_path.rb`: parse and normalize path expressions.
- `lib/enumpath/operator.rb`: `Operator.detect` maps a path segment to an operator class instance (or `nil`).
- `lib/enumpath/operator/*.rb`: one class per JSONPath operator (child, slice, union, wildcard,
  recursive descent, filter and subscript expressions), all inheriting `operator/base.rb`.
- `lib/enumpath/results.rb`: `Results`, an Array subclass that stores matches as values or `:path` strings.
- `lib/enumpath/logger.rb`: `Logger`, the debug logger behind `Enumpath.verbose` (`Enumpath.log`).
- `lib/enumpath/resolver/`: how a key is read from an object (`simple`, `property`).
- `spec/` mirrors `lib/`. Shared operator examples live in `spec/shared_examples/operator/base.rb`;
  `spec/integration_tests/store_examples_spec.rb` runs the JSONPath "store" examples end to end.
  `.rspec` auto-requires `spec_helper` and uses the documentation format.

## Gotchas

- `docs/` is generated YARD output and is committed. Never hand-edit it; change the YARD comments in
  `lib/` and run `bundle exec rake yard`.
- CI (`.github/workflows/ruby.yml`) runs the specs on Ruby 2.6 to 4.0 (plus an allowed-failure `ruby-head`) and a rubocop
  `lint` job; the `ci-gate` job aggregates them. The gemspec requires Ruby `>= 2.6.0`; avoid syntax newer than 2.6.
- `Gemfile.lock` is pinned to Bundler 2.4.22 (the last Bundler that supports Ruby 2.6); regenerate it with
  `bundle` commands, never by hand (the `block-generated-files.sh` hook refuses edits). Do not touch it or
  `lib/enumpath/version.rb` outside a dependency bump or release. The lock is for Ruby 2.6 to 3.4 only: on Ruby 4.0+
  Bundler 4 would switch to the locked 2.4.22 and the old rake in it needs `ostruct` (gone in 4.0), so the 4.0 and
  `ruby-head` CI jobs `rm Gemfile.lock` and resolve fresh. Locally on Ruby 4.0, delete (or copy away) the lock too.
- Releases use the `release-enumpath` skill (`.claude/skills/release-enumpath/SKILL.md`), an overlay on the
  shared `chrisbloom7-development:release` skill (install it from `chrisbloom7/ai-tools` first). Never run
  `rake release`; publishing to rubygems.org is always an explicit request.
- Add a line under `## [Unreleased]` in `CHANGELOG.md` for any change to the published gem (what a
  user of the gem would notice). The release skill moves those lines under the new version.
- The default branch is `main`; changes go through PRs from a fork or branch.

## Claude Code setup

`.claude/settings.json` registers two hooks (scripts in `.claude/hooks/`): `rubocop-autocorrect.sh`
runs `rubocop -a` on edited `.rb` files and reports what is left, and `block-generated-files.sh`
refuses edits to `docs/` and `Gemfile.lock`. Both skip quietly when a tool they need is missing.

Changes to `.claude/` (hooks and the allowlist) and to this file run or steer Claude Code on the machine
of whoever opens the repo, so `.github/CODEOWNERS` routes them to the maintainer. When reviewing an
outside PR that touches them, read the diff first (`gh pr diff <number> -- .claude CLAUDE.md`) before
checking the branch out and starting Claude Code there.
