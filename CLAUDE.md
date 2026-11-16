# CLAUDE.md

Enumpath is a Ruby gem: JSONPath-compatible path expressions over nested Ruby objects (hashes, arrays,
structs). Read `CONTRIBUTING.md` before opening a PR (open an issue first unless one exists).

## Commands

```bash
bin/setup                       # bundle install
bundle exec rspec               # full suite (rake spec is equivalent)
bundle exec rspec spec/enumpath/operator/slice_spec.rb   # one file
rubocop                         # lint; line length 120, specs exempt from BlockLength
bundle exec rake yard           # regenerate docs/ (redcarpet markdown)
bin/console                     # pry console with the gem loaded
```

`rubocop` is not in the bundle. Install it separately (`gem install rubocop`); CI adds it with
`bundle add`.

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
- CI runs Ruby 2.6, 2.7, 3.0 and 3.1 (the gemspec says `>= 2.3.0`). Avoid syntax newer than 2.6.
- Do not hand-edit `Gemfile.lock` or `lib/enumpath/version.rb` outside a dependency bump or release.
- The default branch is `main`; changes go through PRs from a fork or branch.

## Claude Code setup

`.claude/settings.json` registers two hooks (scripts in `.claude/hooks/`): `rubocop-autocorrect.sh`
runs `rubocop -a` on edited `.rb` files and reports what is left, and `block-generated-files.sh`
refuses edits to `docs/` and `Gemfile.lock`. Both skip quietly when a tool they need is missing.

Changes to `.claude/` (hooks and the allowlist) and to this file run or steer Claude Code on the machine
of whoever opens the repo, so `.github/CODEOWNERS` routes them to the maintainer. When reviewing an
outside PR that touches them, read the diff first (`gh pr diff <number> -- .claude CLAUDE.md`) before
checking the branch out and starting Claude Code there.
