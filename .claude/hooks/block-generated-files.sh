#!/usr/bin/env bash
# PreToolUse hook: refuse hand edits to generated or tool-owned files.
# docs/ is YARD output (bundle exec rake yard); Gemfile.lock is owned by bundler.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty')"
root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${file#"${root}"/}"

case "${rel}" in
  docs/* )
    echo "docs/ is generated YARD output. Edit the YARD comments in lib/ and run: bundle exec rake yard" >&2
    exit 2 ;;
  Gemfile.lock )
    echo "Gemfile.lock is owned by bundler. Change the gemspec and run bundle install instead." >&2
    exit 2 ;;
esac
exit 0
