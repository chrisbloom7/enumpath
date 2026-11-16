# CLAUDE.md

Enumpath is a Ruby gem: JSONPath-compatible path expressions over nested Ruby objects (hashes, arrays,
structs). Read `CONTRIBUTING.md` before opening a PR (open an issue first unless one exists).

## Commands

```bash
bin/setup                       # bundle install
bundle exec rake                # what CI runs: the full spec suite
bundle exec rspec               # full suite (rake spec is equivalent)
bundle exec rspec spec/enumpath/operator/slice_spec.rb   # one file
BUNDLE_GEMFILE=gemfiles/rubocop.gemfile bundle exec rubocop   # lint, as CI does
bundle exec rake yard           # regenerate docs/ (redcarpet markdown)
bin/console                     # pry console with the gem loaded
```

`rubocop` is not in the main bundle (it needs Ruby >= 2.7); it lives in `gemfiles/rubocop.gemfile`, which the
CI `lint` job uses. Config: line length 120, specs exempt from BlockLength; existing offenses are listed in
`.rubocop_todo.yml`.

## Architecture

- `lib/enumpath.rb`: public entry point (`Enumpath.apply`, `Enumpath.verbose`).
- `lib/enumpath/path.rb`, `path/normalized_path.rb`: parse and normalize path expressions.
- `lib/enumpath/operator/*.rb`: one class per JSONPath operator (child, slice, union, wildcard,
  recursive descent, filter and subscript expressions), all inheriting `operator/base.rb`.
- `lib/enumpath/resolver/`: how a key is read from an object (`simple`, `property`).
- `spec/` mirrors `lib/`. Shared operator examples live in `spec/shared_examples/operator/base.rb`;
  `spec/integration_tests/store_examples_spec.rb` runs the JSONPath "store" examples end to end.

## Gotchas

- `docs/` is generated YARD output and is committed. Never hand-edit it; change the YARD comments in
  `lib/` and run `bundle exec rake yard`.
- CI (`.github/workflows/ruby.yml`) runs the specs on Ruby 2.6 to 3.4 plus a rubocop `lint` job; the `ci-gate`
  job aggregates them. The gemspec says `>= 2.3.0`; avoid syntax newer than 2.6.
- Do not hand-edit `Gemfile.lock` or `lib/enumpath/version.rb` outside a dependency bump or release.
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
