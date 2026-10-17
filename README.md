# forsgren-metrics-feta

A preview of the [forsgren](https://github.com/yveshanoulle/forsgren) metrics site, at <https://feta.forsgren.forsgren.be>.

It shows the newest forsgren code, which is not released yet, rendered on the data the public metrics installation ([forsgren-metrics](https://github.com/yveshanoulle/forsgren-metrics)) has already collected. It never collects data itself, so any difference from the live site comes from the code alone.

The live site, with the released version, is <https://forsgren.forsgren.be>.

## How it is updated

After a push to forsgren's main branch, forsgren starts this repository's `preview` workflow with the pushed commit. The workflow builds forsgren at that commit, renders the data in forsgren-metrics' `data/` with forsgren-metrics' `forsgren.config.yml`, and publishes the result to GitHub Pages. Only the newest preview is published.

## Files

- `.github/workflows/preview.yml`: the workflow.
- `Scripts/check_sha.sh`: accepts only a full 40-digit commit.
- `Scripts/check_data.sh`: refuses to render without the collected data.
- `Scripts/test_preview_scripts.sh`: tests both scripts.
