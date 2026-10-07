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
#   V14-V17  bootloader evidence, no RAM-boot step, getvar tolerance, evidence kinds
#                                            ....... tools/check_protocol_invariants.sh
#   V18  first write is identical-content rehearsal  tools/check_protocol_invariants.sh
#   V19  SAFETY fallback rows cite RE2/RE4 disassembly  tools/check_protocol_invariants.sh
#   V20  is-userspace never described as absent ..... tools/check_protocol_invariants.sh
#   V21-V27  Z0 closed allowlist, key-entry criterion, slot-mismatch power-off,
#            charger off, no-adb procedure, day baseline, honest not-proven list
#                                            ....... tools/check_protocol_invariants.sh
#   V28  tools/*.sh and scripts/*.sh executable ... tools/check_protocol_invariants.sh
#   V29  SAFETY names the 14 measured LK table names  tools/check_protocol_invariants.sh
#   V30  no executable 'getvar all' outside research  tools/check_protocol_invariants.sh
#   V31  two 'fastboot flash' commands, both boot_b . tools/check_protocol_invariants.sh
#   V32  T-1 section comes after R3 ............... tools/check_protocol_invariants.sh
#   V33  research notes free of machine paths ..... tools/check_protocol_invariants.sh
#   V34  never-touch set covers all critical partitions tools/check_protocol_invariants.sh
#   V35-V53  FIX12 invariants: Z0 header, two protected writes, closed allowlist, no stale
#            single-write, research-README warning, rollback/old-slot rule, is-userspace exists,
#            RE1 order cite, inline commands, shell guard, protect order, baseline example,
#            pstore reading, project policy, accept-in-writing, L1-L6 lacunae
#                                            ....... tools/check_protocol_invariants.sh
#   V54  no status-checked pipe into grep -q ..... tools/check_sigpipe.sh
#   V55  PROTO:NN/SAFETY:NN refs resolve ......... tools/check_protocol_invariants.sh
#   V56  on-device commands carry adb shell ...... tools/check_protocol_invariants.sh
#   V57  residual risks table R1-R4 present ..... tools/check_protocol_invariants.sh
#   V10-V13  aliases of V2/V5/V2/V7 (FIX6 ids, see SPEC.md §V)
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
run "V3-V8+V14-V17 invariants" "$HERE/check_protocol_invariants.sh"
for v in 3 4 5 7 8 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 55 56 57; do RC[V$v]=$(grep -q "^V$v FAIL" "$T/V3-V8+V14-V17 invariants.out" && echo 1 || echo 0); done
# V37 is enforced by check_regex_controls.sh (V2 extended to all five docs), not by the invariants script
RC[V37]=$(grep -q '^V37 FAIL' "$T/V2 regex controls.out" && echo 1 || echo 0)
# V10-V13 are aliases of V2/V5/V2/V7 respectively (SPEC.md §V)
for v in 10 12; do RC[V$v]="${RC[V2]}"; done
for v in 11; do RC[V$v]="${RC[V5]}"; done
for v in 13; do RC[V$v]="${RC[V7]}"; done
run "V6 destructive ops"       "$HERE/check_destructive_ops.sh"
RC[V6]=$(grep -q '^V6 FAIL' "$T/V6 destructive ops.out" && echo 1 || echo 0)
run "V54 sigpipe hygiene"      "$HERE/check_sigpipe.sh"
RC[V54]=$(grep -q '^V54 FAIL' "$T/V54 sigpipe hygiene.out" && echo 1 || echo 0)
run "V9 fetch url"             "$HERE/selftest_fetch.sh"
RC[V9]=$(grep -q '^V9 FAIL' "$T/V9 fetch url.out" && echo 1 || echo 0)
run "GATE crc self-test"       "$HERE/selftest_gates.sh"
RC[GATE]=$(grep -q 'SELFTEST PASS' "$T/GATE crc self-test.out" && echo 0 || echo 1)

echo "=== resumo dos invariantes ==="
bad=0
for v in V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12 V13 V14 V15 V16 V17 V18 V19 V20 V21 V22 V23 V24 V25 V26 V27 V28 V29 V30 V31 V32 V33 V34 V35 V36 V37 V38 V39 V40 V41 V42 V43 V44 V45 V46 V47 V48 V49 V50 V51 V52 V53 V54 V55 V56 V57 GATE; do
  if [ "${RC[$v]:-1}" -eq 0 ]; then printf '%-5s PASS\n' "$v"; else printf '%-5s FAIL\n' "$v"; bad=$((bad + 1)); fi
done
if [ "$bad" -eq 0 ]; then
  echo "run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V56 + gate self-test)"
  exit 0
fi
echo "run_all_checks: FAIL ($bad de 57 verificações falharam)"
exit 1
