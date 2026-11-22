# forsgren-metrics-feta

A preview of the [forsgren](https://github.com/yveshanoulle/forsgren) metrics site, at <https://feta.forsgren.forsgren.be>.

It shows the newest forsgren code, which is not released yet, rendered on the data the public metrics installation ([forsgren-metrics](https://github.com/yveshanoulle/forsgren-metrics)) has already collected. It never collects data itself, so any difference from the live site comes from the code alone.

The live site, with the released version, is <https://forsgren.forsgren.be>.

## How it is updated

After a push to forsgren's main branch, forsgren starts this repository's `preview` workflow with the pushed commit. The workflow builds forsgren at that commit, renders the data in forsgren-metrics' `data/` with forsgren-metrics' `forsgren.config.yml`, and publishes the result to GitHub Pages. Only the newest preview is published.

## Dependabot updates

Dependabot proposes updates of the pinned GitHub Actions (`.github/dependabot.yml`). Every pull request runs `Checks` (actionlint and yamllint). When `Checks` completes for a Dependabot pull request, `Dependabot merge` runs forsgren's reusable merge policy ([forsgren's docs/dependabot-merge.md](https://github.com/yveshanoulle/forsgren/blob/main/docs/dependabot-merge.md)), pinned by commit, with the settings in `.github/dependabot-merge.conf`: a GitHub Actions patch or minor update merges once `Checks` is green on its head commit and it is mergeable and up to date with main; anything else stays a manual merge. The decision is one comment on the pull request.

- The repository variable `DEPENDABOT_AUTOMERGE` is the kill switch: `off` logs only, `on` comments and merges, unset or any other value comments "dry run" and merges nothing.
- The Actions secret `DEPENDABOT_MERGE_TOKEN`, a fine-grained token with Contents and Pull requests read and write on this repository, makes the merge. A merge with the job token would start no workflow on the merge commit; the policy never falls back to it.

## Files

- `.github/workflows/preview.yml`: the preview workflow.
- `.github/workflows/checks.yml`: the checks of every pull request.
- `.github/workflows/dependabot_merge.yml` and `.github/dependabot-merge.conf`: the Dependabot merge policy and its settings.
- `Scripts/check_sha.sh`: accepts only a full 40-digit commit.
- `Scripts/check_data.sh`: refuses to render without the collected data.
- `Scripts/test_preview_scripts.sh`: tests both scripts.
- `Scripts/test_dependabot_merge.sh`: tests the merge policy at the pinned forsgren commit against fixtures (needs a local forsgren clone, `FORSGREN_DIR`).
- `Scripts/yamllint_requirements.txt` and `.yamllint.yml`: the pinned yamllint and its rules, forsgren's.
- `Scripts/run_checks.sh`: runs both tests, actionlint, yamllint and shellcheck locally.
