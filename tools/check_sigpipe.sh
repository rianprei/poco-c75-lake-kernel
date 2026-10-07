#!/usr/bin/env bash
# check_sigpipe.sh — V54 (invariant): no status-checked pipeline may feed `grep -q`.
#
# Root cause (SPEC.md §B): with `set -o pipefail`, piping a writer into grep -q
# is a race. `grep -q` exits after the first match and closes the pipe; if the
# writer is still running (likely under load), it dies with SIGPIPE (exit 141)
# and pipefail reports the pipeline as FAILED even though the pattern IS present.
# Every `... && ok || fail` chain built on such a pipeline then flakes.
# The fix is a herestring (`grep -q PATTERN <<<"$var"`): no pipeline, no race.
# `grep -q` with a FILE argument is fine and stays allowed.
#
# usage: tools/check_sigpipe.sh      (read-only; prints V54 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"

fails=0
ok() { echo "V54 OK $1"; }
fail() { echo "V54 FAIL $1"; fails=$((fails + 1)); }

# A line starting a pipeline INTO grep -q, but not a logical-or (`||`).
# Fixture-append lines (`>>`, the sabotage strings in selftest_backprop.sh) are
# data, not executed pipelines — same doctrine as V6's fixture note.
bad="$(grep -rnE '[^|][|] grep -q' tools/*.sh 2>/dev/null | grep -v 'check_sigpipe.sh' | grep -v '>>' || true)"
if [ -z "$bad" ]; then
  ok "no pipe into grep -q in tools/*.sh (herestrings or file args only)"
else
  fail "SIGPIPE-fragile pipe into grep -q: $(printf '%s' "$bad" | head -1 | cut -c1-120)"
fi

if [ "$fails" -eq 0 ]; then
  echo "PASS sigpipe hygiene (V54)"
  exit 0
fi
echo "FAIL $fails higiene(s) de pipeline"
exit 1
