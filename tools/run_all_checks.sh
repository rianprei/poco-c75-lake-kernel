#!/usr/bin/env bash
# run_all_checks.sh — run every backprop check and print one PASS/FAIL line per invariant V1..V9.
# Exit 0 only if every invariant passed and the CRC gate self-test passed.
#
#   V1  docs numbers == gate/data .................. tools/check_docs_numbers.sh
#   V2  documented greps have positive+negative .... tools/check_regex_controls.sh
#   V3  no slot switch without firmware comparison .. tools/check_protocol_invariants.sh
#   V4  bootloader-dependent commands never asserted  tools/check_protocol_invariants.sh
#   V5  absence claims cite >= 2 sources ........... tools/check_protocol_invariants.sh
#   V6  rm -rf only under mktemp -d + trap ......... tools/check_destructive_ops.sh
#   V7  kernel-behaviour claims cite a source ...... tools/check_protocol_invariants.sh
#   V8  every fact row has a proof ................. tools/check_protocol_invariants.sh
#   V9  fetch URL == documented viewer URL ......... tools/selftest_fetch.sh
#   GATE  the CRC gate's own self-test ............. tools/selftest_gates.sh
#
# usage: tools/run_all_checks.sh            (read-only apart from mktemp dirs)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() { # <label> <script>
  local label="$1" script="$2" rc=0
  echo "--- $label"
  bash "$script" >"$T/$label.out" 2>&1 || rc=$?
  sed 's/^/    /' "$T/$label.out"
  echo
  printf '%s' "$rc" > "$T/$label.rc"
}

declare -A RC
run "V1 docs numbers"          "$HERE/check_docs_numbers.sh"
RC[V1]=$(grep -q '^V1 FAIL' "$T/V1 docs numbers.out" && echo 1 || echo 0)
run "V2 regex controls"        "$HERE/check_regex_controls.sh"
RC[V2]=$(grep -q '^V2 FAIL' "$T/V2 regex controls.out" && echo 1 || echo 0)
run "V3-V8 protocol invariants" "$HERE/check_protocol_invariants.sh"
for v in 3 4 5 7 8; do RC[V$v]=$(grep -q "^V$v FAIL" "$T/V3-V8 protocol invariants.out" && echo 1 || echo 0); done
run "V6 destructive ops"       "$HERE/check_destructive_ops.sh"
RC[V6]=$(grep -q '^V6 FAIL' "$T/V6 destructive ops.out" && echo 1 || echo 0)
run "V9 fetch url"             "$HERE/selftest_fetch.sh"
RC[V9]=$(grep -q '^V9 FAIL' "$T/V9 fetch url.out" && echo 1 || echo 0)
run "GATE crc self-test"       "$HERE/selftest_gates.sh"
RC[GATE]=$(grep -q 'SELFTEST PASS' "$T/GATE crc self-test.out" && echo 0 || echo 1)

echo "=== resumo dos invariantes ==="
bad=0
for v in V1 V2 V3 V4 V5 V6 V7 V8 V9 GATE; do
  if [ "${RC[$v]:-1}" -eq 0 ]; then printf '%-5s PASS\n' "$v"; else printf '%-5s FAIL\n' "$v"; bad=$((bad + 1)); fi
done
if [ "$bad" -eq 0 ]; then
  echo "run_all_checks: PASS (9 invariantes + gate self-test)"
  exit 0
fi
echo "run_all_checks: FAIL ($bad de 10 verificações falharam)"
exit 1
