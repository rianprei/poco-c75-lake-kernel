#!/usr/bin/env bash
# selftest_python.sh — V65: offline Python unit tests (unittest, stdlib only).
# ResourceWarning is an error. tools/run_fuzz.py is not part of this tree; if a
# later change adds tools/run_fuzz.py or tests/run_fuzz.py, this check runs it.
#
# usage: tools/selftest_python.sh      (read-only; prints V65 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"

out="$(python3 -W error::ResourceWarning -m unittest discover -s tests -p 'test_*.py' 2>&1)"; rc=$?
tail -5 <<<"$out" | sed 's/^/    /'
# Finalizer warnings still print "Exception ignored" and leave exit 0.
# The text is the failure; -W error covers warnings raised in the test body.
if [ "$rc" -ne 0 ] || ! grep -q '^OK' <<<"$out" || grep -q 'ResourceWarning' <<<"$out"; then
  echo "V65 FAIL Python unit tests failed (exit=$rc)"
  exit 1
fi

for cand in tools/run_fuzz.py tests/run_fuzz.py; do
  if [ -f "$cand" ]; then
    fout="$(python3 -W error::ResourceWarning "$cand" 2>&1)" || frc=$?
    frc="${frc:-0}"
    if [ "$frc" -ne 0 ]; then
      printf '%s\n' "$fout" | tail -5 | sed 's/^/    /'
      echo "V65 FAIL $cand failed (exit=$frc)"
      exit 1
    fi
  fi
done
if [ ! -f tools/run_fuzz.py ] && [ ! -f tests/run_fuzz.py ]; then
  echo "V65 NOTE run_fuzz.py is not in this tree; V65 is unittest discover only"
fi
echo "V65 OK Python unit tests pass (unittest discover tests/test_*.py; ResourceWarning is an error)"
exit 0
