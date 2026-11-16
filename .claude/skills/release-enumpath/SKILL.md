---
name: release-enumpath
description: Use when releasing a new version of the enumpath gem - "cut a release", "release vX.Y.Z", "bump the version", "tag a release", "publish a new version".
---

# Release enumpath

Use the `chrisbloom7-development:release` skill with the parameters below. That skill holds the
generic steps and the safety rules (never `wt merge`, never push `main`, the owner merges the release
PR, confirm before pushing the tag). If it is not available, stop and tell the owner to install it
(`/plugin marketplace add chrisbloom7/ai-tools`, then install `chrisbloom7-development`).

**Never run `bundle exec rake release`.** It builds the gem, tags, pushes the tag and pushes the gem
to rubygems.org in one go, and a published version cannot be undone. Publishing is covered by the
post_tag steps below and always needs an explicit request from the owner.

## Release parameters

- project: enumpath
- flow: release-branch; base_branch: main
- preconditions:
  - `bundle exec rake` green (runs the specs, as CI does). If `bundle exec` cannot resolve the
    pinned gems on the local Ruby, stop and report it; do not edit `Gemfile.lock`.
  - `rubocop` clean. It is not in the bundle: use an installed `rubocop` (`gem install rubocop`).
  - `gh run list --branch main --limit 1 --json conclusion,workflowName` shows `success`
- version_file: `lib/enumpath/version.rb`, one line `VERSION = 'X.Y.Z'` (single quotes, no `v`).
  `Gemfile.lock` records `enumpath (X.Y.Z)` under PATH, so after the edit run `bundle install` and
  commit the changed `Gemfile.lock` with the release. Never edit `Gemfile.lock` by hand (a project
  hook blocks it). If `bundle install` cannot run, stop and ask.
- changelog: keep-a-changelog (`CHANGELOG.md`; no `v` prefix in headings, links are not used). The
  release moves the `## [Unreleased]` content under the new version heading. If `[Unreleased]` is
  empty, warn the owner before going on: contributors add entries as they change the gem.
- tag_prefix: `v`; tag_style: lightweight, `vX.Y.Z` (existing tags v0.1.0 to v0.1.2 are lightweight)
- commit_message: `Bump version to X.Y.Z` (the repo's earlier release commit); pr_title: `Release vX.Y.Z`;
  branch `chore/release-vX.Y.Z`
- pr_body_extra: "After merging: tag vX.Y.Z on the merge commit. Publishing to rubygems.org and the GitHub
  release are separate steps that need an explicit request."
- merge_method: merge commit (the repo's history uses `Merge pull request #N`)
- audit:
  - (blocking) Regenerate the YARD docs with `bundle exec rake yard` and include the `docs/` diff in the
    release commit. `docs/` is generated and committed (the `VERSION` constant page shows the version);
    never hand-edit it (a project hook blocks that). If `rake yard` cannot run, stop and ask.
  - (advisory, propose edits and wait for approval) README.md: the "requires Ruby 2.3.0 or higher"
    line, the install and usage examples and any version mention vs the gemspec
    (`required_ruby_version`) and the CI matrix in `.github/workflows/ruby.yml` (currently Ruby 2.6,
    2.7, 3.0, 3.1). CONTRIBUTING.md: same check for any Ruby or version mention.
  - (advisory) Check what the gem will ship: it should contain only `lib/`, `LICENSE` and
    `README.md`. Build into a throwaway path (see post_tag step 1) and list it with
    `tar -xOf <gem> data.tar.gz | tar tz`. Report anything else (for example `docs/`, `.claude/`,
    `.github/`, `CLAUDE.md` or `Gemfile.lock`), which means `spec.files` in `enumpath.gemspec` has
    drifted.
  - (advisory) Check that the gemspec metadata sets `rubygems_mfa_required` to `'true'` and report it
    if not.
- post_tag:
  1. Build the gem without publishing, into a throwaway path:
     `gem build enumpath.gemspec -o "$(mktemp -d)/enumpath-X.Y.Z.gem"`. Report the file name and size.
     Never push it.
  2. **Stop and ask.** Publishing to rubygems.org (`gem push <file>`) and creating a GitHub release
     (`gh release create vX.Y.Z`, with the CHANGELOG entry for that version as the notes) are
     separate steps. Do them only if the owner explicitly asks, and
     confirm each one immediately before running it. Never ask for or store rubygems credentials; the
     owner signs in on their own machine. If the gemspec lacks `rubygems_mfa_required`, say so before
     any `gem push`.
