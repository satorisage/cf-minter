#!/usr/bin/env bash
#
# run-all.sh — every test in this project, offline. No suite here reaches
# Cloudflare: curl (and az) are PATH stubs, so a full run mints nothing, uses
# nothing and deletes nothing. Exit 0 only when every suite passed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for suite in "$HERE"/*.test.sh; do
  echo
  echo "=============================================================="
  echo "  $(basename "$suite")"
  echo "=============================================================="
  bash "$suite" || rc=1
done
echo
if [[ "$rc" -eq 0 ]]; then echo "ALL SUITES PASSED"; else echo "SOME SUITES FAILED" >&2; fi
exit "$rc"
