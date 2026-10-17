#!/usr/bin/env bash
# Scripts/test_preview_scripts.sh: fixture test of check_sha.sh and check_data.sh.
set -uo pipefail
cd "$(dirname "$0")" || exit 2
fails=0
expect() { # <name> <want rc> <got rc>
  if [[ "$2" -eq "$3" ]]; then echo "ok: $1"; else echo "❌ FAIL: $1: want rc $2, got $3"; fails=$((fails + 1)); fi
}

good=0123456789abcdef0123456789abcdef01234567
./check_sha.sh "$good" >/dev/null; expect "full sha accepted" 0 $?
./check_sha.sh "${good:0:39}" >/dev/null; expect "39 digits refused" 1 $?
./check_sha.sh "${good}0" >/dev/null; expect "41 digits refused" 1 $?
./check_sha.sh "$(printf %s "$good" | tr a-f A-F)" >/dev/null; expect "upper case refused" 1 $?
./check_sha.sh main >/dev/null; expect "branch name refused" 1 $?
./check_sha.sh "${good:0:39}g" >/dev/null; expect "non-hex refused" 1 $?
./check_sha.sh "$good; rm -rf /" >/dev/null; expect "injection refused" 1 $?
./check_sha.sh >/dev/null 2>&1; expect "no argument is usage" 2 $?
printed="$(./check_sha.sh "$good")"; [[ "$printed" == "$good" ]] && rc=0 || rc=1; expect "prints the sha" 0 "$rc"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/data"
./check_data.sh "$tmp" >/dev/null; expect "empty checkout refused" 1 $?
echo "version: 1" > "$tmp/forsgren.config.yml"
printf 'h\na\nb\n' > "$tmp/data/deployments.csv"
out="$(./check_data.sh "$tmp")"; expect "usable checkout accepted" 0 $?
[[ "$out" == *"data/deployments.csv: 2 rows"* ]] && rc=0 || rc=1; expect "row count printed" 0 "$rc"
: > "$tmp/data/deployments.csv"
./check_data.sh "$tmp" >/dev/null; expect "empty deployments refused" 1 $?
./check_data.sh >/dev/null 2>&1; expect "no argument is usage" 2 $?

[[ "$fails" -eq 0 ]] || { echo "❌ FAIL: $fails check(s) failed"; exit 1; }
echo "OK: all checks held"
