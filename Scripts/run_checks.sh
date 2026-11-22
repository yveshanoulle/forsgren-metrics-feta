#!/usr/bin/env bash
# Scripts/run_checks.sh: runs this repository's tests and lint locally:
# both fixture tests, actionlint, yamllint and shellcheck. Each must be on
# PATH; a missing tool is red, never skipped. FORSGREN_DIR is passed on to
# Scripts/test_dependabot_merge.sh (a forsgren clone with the pinned commit).
# Run: [FORSGREN_DIR=<forsgren clone>] Scripts/run_checks.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fails=0
run() { # <name> <command...>
  echo "== $1"
  if "$@"; then :; else echo "❌ FAIL: $1"; fails=$((fails + 1)); fi
}
run Scripts/test_preview_scripts.sh
run Scripts/test_dependabot_merge.sh
run actionlint
run yamllint -c .yamllint.yml .github .yamllint.yml
run shellcheck Scripts/*.sh
if [ "$fails" -eq 0 ]; then echo "✅ all checks passed"; else echo "❌ ${fails} check(s) failed"; exit 1; fi
