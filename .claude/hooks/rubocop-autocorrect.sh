#!/usr/bin/env bash
# PostToolUse hook: autocorrect an edited Ruby file with rubocop and report any remaining offenses.
# Skips quietly when jq or rubocop is missing, so it never blocks a contributor without them.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v rubocop >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty')"
case "${file}" in
  *.rb | *.gemspec | */Rakefile) ;;
  *) exit 0 ;;
esac
[ -f "${file}" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f .rubocop.yml ] || exit 0

output="$(rubocop -a --format emacs "${file}" 2>&1)"
remaining="$(printf '%s\n' "${output}" | grep -v ' \[Corrected\] ' | grep -E ': [CWEF]: ' || true)"
if [ -n "${remaining}" ]; then
  printf 'rubocop offenses left in %s:\n%s\n' "${file}" "${remaining}" >&2
  exit 2
fi
exit 0
