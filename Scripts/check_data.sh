#!/usr/bin/env bash
# Scripts/check_data.sh <metrics-checkout-dir>
# The preview renders forsgren-metrics' already-collected data and never
# collects. Before it renders, the checkout must hold forsgren.config.yml and a
# non-empty data/deployments.csv (render reads commits.csv, failures.csv and
# issues.csv beside it). Prints one line per data file with its row count.
# Exit: 0 usable, 1 a file is missing or empty (::error on stdout), 2 usage.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: Scripts/check_data.sh <metrics-checkout-dir>" >&2
  exit 2
fi
dir="$1"
for f in forsgren.config.yml data/deployments.csv; do
  if [[ ! -s "$dir/$f" ]]; then
    echo "::error title=preview data::$f is missing or empty in the metrics checkout; the preview never collects"
    exit 1
  fi
done
for f in "$dir"/data/*.csv; do
  rows=$(( $(wc -l < "$f") - 1 ))
  printf '%s: %d rows\n' "data/$(basename "$f")" "$(( rows < 0 ? 0 : rows ))"
done
