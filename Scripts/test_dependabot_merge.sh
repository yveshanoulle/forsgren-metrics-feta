#!/usr/bin/env bash
# Scripts/test_dependabot_merge.sh: fixture test of this repository's
# Dependabot merge policy, the caller .github/workflows/dependabot_merge.yml
# of forsgren's reusable workflow and its settings .github/dependabot-merge.conf.
#
# The policy itself is forsgren's, at exactly the commit the caller pins: this
# test reads forsgren's Scripts/dependabot_merge_policy.sh, Scripts/lib_tmp.sh
# and .github/workflows/dependabot_merge_policy.yml at that commit from a local
# forsgren clone (FORSGREN_DIR, default ../forsgren next to this repository),
# so a pin bump is tested against the same fixtures. No network: a fake gh on
# PATH answers each API read from a fixture.
#   1. pins: the caller (trigger, permissions, pin, mode, secret) and the
#      settings (allow lines, expected workflow) are what the policy needs
#   2. policy, with this repository's settings: an Actions patch, a minor and
#      a group of both are ELIGIBLE; a major, a red, missing or unfinished
#      Checks run, another author and another head repository are not
#   3. kill switch, the pinned workflow's own decision step with a fake
#      policy: off comments nothing; unset, dry-run and an unknown value
#      comment "dry run" and never reach the merge step; on comments
#      "eligible: merging" and reaches it only for an eligible pull request
# Run: FORSGREN_DIR=<forsgren clone> Scripts/test_dependabot_merge.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
CALLER=.github/workflows/dependabot_merge.yml
CONF=.github/dependabot-merge.conf
fails=0
ok() { echo "ok: $1"; }
bad() { echo "❌ FAIL: $1"; fails=$((fails + 1)); }
check() { # <name> <command...>: ok when the command succeeds
  local name="$1"; shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}
has() { grep -qxF -- "$2" "$1"; }   # <file> <exact line>
# D stands for a dollar sign inside double quotes, so an expected line reads
# as written without a shellcheck suppression.
D='$'

# 1. pins
pin_line="$(grep -E '^    uses: yveshanoulle/forsgren/\.github/workflows/dependabot_merge_policy\.yml@' "$CALLER")"
PIN="$(sed -nE 's#^    uses: yveshanoulle/forsgren/\.github/workflows/dependabot_merge_policy\.yml@([0-9a-f]{40})  \# v[0-9]+\.[0-9]+\.[0-9]+$#\1#p' <<< "$pin_line")"
check "1. the caller pins forsgren's reusable workflow by a full commit with its release named" test -n "$PIN"
check "1. the caller starts on Checks completed only" \
  test "$(sed -n '/^on:/,/^permissions:/p' "$CALLER" | grep -vE '^\s*(#|$)' | tr -s ' ')" = \
  "$(printf '%s\n' 'on:' ' workflow_run: # zizmor: ignore[dangerous-triggers]' ' workflows: [Checks]' ' types: [completed]' 'permissions:')"
check "1. the caller grants exactly contents read, pull-requests write, actions read" \
  test "$(sed -n '/^permissions:/,/^jobs:/p' "$CALLER" | grep -E '^  [a-z-]+:' | tr -d ' ' | sort | tr '\n' ' ')" = "actions:read contents:read pull-requests:write "
check "1. the mode is the variable DEPENDABOT_AUTOMERGE" has "$CALLER" "      mode: ${D}{{ vars.DEPENDABOT_AUTOMERGE }}"
check "1. the settings file is .github/dependabot-merge.conf" has "$CALLER" '      settings-file: .github/dependabot-merge.conf'
check "1. DEPENDABOT_MERGE_TOKEN is passed by name" has "$CALLER" "      DEPENDABOT_MERGE_TOKEN: ${D}{{ secrets.DEPENDABOT_MERGE_TOKEN }}"
check "1. no other secret and never secrets: inherit" \
  test "$(grep -c 'secrets\.' "$CALLER")" = 1 -a "$(grep -c 'inherit' "$CALLER")" = 0
check "1. the allow lines are exactly Actions patch and minor" \
  test "$(grep '^allow ' "$CONF" | tr '\n' '|')" = "allow github_actions * semver-patch|allow github_actions * semver-minor|"
check "1. no major is allowed" test "$(grep -c 'semver-major' "$CONF")" = 0
check "1. the one expected workflow is checks.yml, Checks" \
  test "$(grep '^workflow ' "$CONF")" = "workflow .github/workflows/checks.yml Checks"
check "1. checks.yml is named Checks and runs on pull_request" \
  bash -c 'grep -qx "name: Checks" .github/workflows/checks.yml && grep -qx "  pull_request:" .github/workflows/checks.yml'
others="$(grep -lE '^  pull_request(_target)?:' .github/workflows/*.yml | grep -vx .github/workflows/checks.yml)"
check "1. no other workflow runs on pull requests unexpected${others:+ (found: $others)}" test -z "$others"

# The pinned forsgren files.
FORSGREN_DIR="${FORSGREN_DIR:-$ROOT/../forsgren}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -z "$PIN" ] || ! git -C "$FORSGREN_DIR" cat-file -e "${PIN}^{commit}" 2> /dev/null; then
  bad "forsgren's commit ${PIN:-?} is not in ${FORSGREN_DIR}: set FORSGREN_DIR to a forsgren clone that has it"
  echo "❌ ${fails} failure(s)"; exit 1
fi
mkdir -p "$TMP/forsgren"
git -C "$FORSGREN_DIR" archive "$PIN" Scripts/dependabot_merge_policy.sh Scripts/lib_tmp.sh \
  .github/workflows/dependabot_merge_policy.yml | tar -x -C "$TMP/forsgren"
POLICY="$TMP/forsgren/Scripts/dependabot_merge_policy.sh"
CALLED="$TMP/forsgren/.github/workflows/dependabot_merge_policy.yml"

# 2. policy. The fake gh answers "gh api <path>" from the case's fixtures.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" << 'FAKE'
#!/usr/bin/env bash
[ "$1" = api ] && [ "$#" -eq 2 ] || { echo "fake gh: unexpected call: $*" >&2; exit 64; }
case "$2" in
  */pulls/*) kind=pr ;;
  */commits/*) kind=commit ;;
  */actions/runs*) kind=runs ;;
  */compare/*) kind=compare ;;
  *) echo "fake gh: unexpected path $2" >&2; exit 64 ;;
esac
cat "$FAKE_GH_DIR/$kind.json"
FAKE
chmod +x "$TMP/bin/gh"
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
BRANCH=dependabot/github_actions/actions-0123456789
PATCH="actions/checkout|direct:production|semver-patch|7.0.1|7.0.2"
MINOR="actions/setup-go|direct:production|semver-minor|7.0.0|7.1.0"
MAJOR="actions/setup-go|direct:production|semver-major|7.0.0|8.0.0"

message() { # <member "name|type|update|from|to"...>: a Dependabot commit message
  local m name type upd to
  printf 'actions: bump\n\n---\nupdated-dependencies:\n'
  for m in "$@"; do
    IFS='|' read -r name type upd _ to <<< "$m"
    printf -- '- dependency-name: "%s"\n  dependency-version: %s\n  dependency-type: %s\n  update-type: version-update:%s\n' \
      "$name" "$to" "$type" "$upd"
  done
  printf '...\n\nSigned-off-by: dependabot[bot] <support@github.com>\n'
}
N=0
new_case() { # <member...>: an eligible fixture (Checks green, clean, not behind) in a new d
  N=$((N + 1)); d="$TMP/case$N"; mkdir -p "$d"
  jq -n --arg sha "$SHA" --arg ref "$BRANCH" '{number: 2, title: "actions: bump", state: "open",
    user: {login: "dependabot[bot]"}, head: {sha: $sha, ref: $ref, repo: {full_name: "owner/repo"}},
    base: {ref: "main", repo: {default_branch: "main"}}, mergeable: true, mergeable_state: "clean"}' > "$d/pr.json"
  jq -n --arg msg "$(message "$@")" '{commit: {message: $msg}}' > "$d/commit.json"
  jq -n --arg sha "$SHA" '{workflow_runs: [{id: 11, name: "Checks", path: ".github/workflows/checks.yml",
    head_sha: $sha, status: "completed", conclusion: "success"}]}' > "$d/runs.json"
  echo '{"behind_by": 0, "ahead_by": 1}' > "$d/compare.json"
}
edit() { jq "$2" "$1" > "$1.new" && mv "$1.new" "$1"; }
judge() { # <name> <want rc> <text the record must hold>
  local out rc
  out="$(env FAKE_GH_DIR="$d" PATH="$TMP/bin:$PATH" GITHUB_REPOSITORY=owner/repo GITHUB_STEP_SUMMARY= \
    DEPENDABOT_MERGE_RETRY_SECONDS=0 DEPENDABOT_MERGE_CONF="$ROOT/$CONF" DEPENDABOT_MERGE_EXPECTED_HEAD="$SHA" \
    "$POLICY" 2 2>&1)"; rc=$?
  if [ "$rc" -eq "$2" ] && [[ "$out" == *"$3"* ]]; then ok "$1"; else bad "$1: want rc $2 and '$3', got rc $rc: $out"; fi
}
new_case "$PATCH"; judge "2. an Actions patch is eligible" 0 "Decision: ELIGIBLE"
new_case "$MINOR"; judge "2. an Actions minor is eligible" 0 "Decision: ELIGIBLE"
new_case "$PATCH" "$MINOR"; judge "2. a group of a patch and a minor is eligible" 0 "Decision: ELIGIBLE"
new_case "$MAJOR"; judge "2. an Actions major is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH" "$MAJOR"; judge "2. a group with one major is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/runs.json" '.workflow_runs[0].conclusion = "failure"'
judge "2. a red Checks run is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/runs.json" '.workflow_runs[0] |= (.status = "in_progress" | .conclusion = null)'
judge "2. an unfinished Checks run is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; echo '{"workflow_runs": []}' > "$d/runs.json"
judge "2. a missing Checks run is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/runs.json" '.workflow_runs[0].head_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'
judge "2. a Checks run of an older head is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/pr.json" '.user.login = "someone"'
judge "2. a pull request not opened by dependabot[bot] is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/pr.json" '.head.repo.full_name = "fork/repo"'
judge "2. a head in another repository is not eligible" 1 "Decision: NOT ELIGIBLE"
new_case "$PATCH"; edit "$d/compare.json" '.behind_by = 1'
judge "2. a pull request behind main is not eligible" 1 "Decision: NOT ELIGIBLE"

# 3. kill switch: the pinned workflow's decision step, run as written.
step="$TMP/apply.sh"
awk '/^      - name: Apply the merge policy$/ {f = 1} f && /^        run: \|$/ {r = 1; next}
     r && /^      - name:/ {exit} r {sub(/^          /, ""); print}' "$CALLED" > "$step"
check "3. the pinned workflow has its decision step" grep -qF "case \"${D}{MODE:-dry-run}\" in" "$step"
merge_if="$(awk '/^      - name: Merge the pull request$/ {f = 1} f && /^        if: / {sub(/^        if: /, ""); print; exit}' "$CALLED")"
check "3. the merge step runs only when ELIGIBLE and the mode is exactly on" \
  test "$merge_if" = "steps.policy.outputs.eligible == 'true' && inputs.mode == 'on'"
decide() { # <name> <mode, or - for unset> <fake policy rc> <comment text, or - for none> <merge runs: yes|no>
  local w="$TMP/k$N" mode="$2" comment merges=no
  N=$((N + 1)); w="$TMP/k$N"; mkdir -p "$w/forsgren-merge/Scripts"
  printf '#!/usr/bin/env bash\necho "- Head commit: %s"\nexit %s\n' "$SHA" "$3" > "$w/forsgren-merge/Scripts/dependabot_merge_policy.sh"
  printf '#!/usr/bin/env bash\ncp "%s2" "%s/posted.md"\n' "$D" "$w" > "$w/forsgren-merge/Scripts/dependabot_pr_comment.sh"
  chmod +x "$w"/forsgren-merge/Scripts/*.sh; : > "$w/out"
  if [ "$mode" = - ]; then mode=""; fi
  (cd "$w" && env PR=2 MODE="$mode" RUNNER_TEMP="$w" GITHUB_OUTPUT="$w/out" GITHUB_STEP_SUMMARY="$w/summary" \
    GITHUB_SERVER_URL=https://github.com GITHUB_REPOSITORY=owner/repo GITHUB_RUN_ID=1 bash -e "$step" > /dev/null) || { bad "$1: the step failed"; return; }
  if grep -qx 'eligible=true' "$w/out" && [ "$mode" = on ]; then merges=yes; fi
  if [ "$4" = - ]; then comment=$([ -e "$w/posted.md" ] && echo posted || echo -); else comment="$(head -1 "$w/posted.md" 2> /dev/null)"; fi
  if [ "$comment" = "$( [ "$4" = - ] && echo - || echo "**$4**")" ] && [ "$merges" = "$5" ]; then ok "$1"
  else bad "$1: comment '$comment', merge $merges"; fi
}
decide "3. off: no comment, no merge" off 0 - no
decide "3. unset: dry run would merge, no merge" - 0 "dry run: would merge" no
decide "3. dry-run: dry run would merge, no merge" dry-run 0 "dry run: would merge" no
decide "3. dry-run: dry run would not merge" dry-run 1 "dry run: would not merge" no
decide "3. an unknown value is dry-run, no merge" yes 0 "dry run: would merge" no
decide "3. on: eligible, merging" on 0 "eligible: merging" yes
decide "3. on: not eligible, no merge" on 1 "not eligible: no merge" no

if [ "$fails" -eq 0 ]; then echo "✅ all passed"; else echo "❌ ${fails} failure(s)"; exit 1; fi
