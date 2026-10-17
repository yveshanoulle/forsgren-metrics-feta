#!/usr/bin/env bash
# Scripts/check_sha.sh <sha>
# Accepts only a full commit: exactly 40 lower-case hex digits. A tag, a branch
# or a short sha would name whatever it points at on the day of the run, so the
# preview never builds from one. Prints the sha on success.
# Exit: 0 valid, 1 invalid (::error on stdout), 2 usage.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: Scripts/check_sha.sh <40-hex-sha>" >&2
  exit 2
fi
if [[ ! "$1" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error title=preview sha::the sha input must be a full 40-digit lower-case hex commit"
  exit 1
fi
printf '%s\n' "$1"
