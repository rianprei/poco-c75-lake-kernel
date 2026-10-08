#!/usr/bin/env bash
# selftest_python.sh — V65: offline Python unit tests (unittest, stdlib only).
#
# usage: tools/selftest_python.sh      (read-only; prints V65 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"

out="$(python3 -m unittest discover -s tests -p 'test_*.py' 2>&1)"; rc=$?
tail -5 <<<"$out" | sed 's/^/    /'
if [ "$rc" -eq 0 ] && grep -q '^OK' <<<"$out"; then
  echo "V65 OK Python unit tests pass (unittest discover tests/test_*.py)"
  exit 0
fi
echo "V65 FAIL Python unit tests failed (exit=$rc)"
exit 1
