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
#   V76 fetch name/type/hash publish gate .......... tools/selftest_fetch_publish.sh
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
#   V58-V64  FIX14 guard/wrapper/stderr/retry/policy/T-1.3/RAM-generic
#   V65  Python unit tests (ResourceWarning=error)  tools/selftest_python.sh
#   V68  Google-key fingerprint exact ............ tools/check_docs_numbers.sh
#   V69  controlled safety vocabulary ............ tools/check_protocol_invariants.sh
#   V70  config table hygiene .................... tools/check_config_table.sh
#   V66  fastboot guard behavioral selftest ...... tools/selftest_fastboot_guard.sh
#   V67  modsig synthetic matrix (8 cases) ....... tools/verify_modsig.sh --selftest-full
#   V77  gate exit 0 before V1 trusts numbers .... tools/check_docs_numbers.sh
#   V78  curl failure is reported ................ tools/selftest_fetch_publish.sh
#   V79-V88 build-doc claims + cms + checkout SHA  tools/check_build_claims.sh
#   V85  required docs exist before later checks . tools/check_protocol_invariants.sh
#   V89  reboot reads current-slot before reboot .. tools/selftest_fastboot_guard.sh
#   V90-V115 Z0 retry through the T-1 flash interlock, second disk, mid-write,
#           T-1.3b gate, uname, day order, hash file, isolated Z0, identity,
#           fact 21 ............................ tools/check_protocol_invariants.sh
#                                            ....... tools/check_protocol_invariants.sh (V58 guard file),
#                                            docs (V59-V64)
#   V10-V13  aliases of V2/V5/V2/V7 (FIX6 ids, see SPEC.md §V)
#   GATE  the CRC gate's own self-test ............. tools/selftest_gates.sh
#
# usage: tools/run_all_checks.sh            (read-only apart from mktemp dirs)
# Fail-closed (items 18/19): each check passes only with exit 0, no FAIL line
# for its invariants, and an explicit OK/PASS signal. The gate needs the
# SELFTEST PASS string AND exit 0.
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

run() { # <label> <script> [extra-arg]
  local label="$1" script="$2" rc=0
  echo "--- $label"
  if [ $# -ge 3 ]; then
    bash "$script" "$3" >"$T/$label.out" 2>&1 || rc=$?
  else
    bash "$script" >"$T/$label.out" 2>&1 || rc=$?
  fi
  sed 's/^/    /' "$T/$label.out"
  echo
  printf '%s' "$rc" > "$T/$label.rc"
}

# Item 18/19 hardening: a check passes only if it exits 0 AND shows no FAIL AND
# shows an explicit PASS/OK signal. A crashed/muted script can no longer pass
# by absence of FAIL lines, and the gate needs the string AND exit 0.
script_ok() { # <label> <fail-pattern> -> 0 only if rc==0, no FAIL, explicit PASS/OK
  local label="$1" pat="$2" rc
  rc="$(cat "$T/$label.rc")"
  [ "$rc" -eq 0 ] || return 1
  grep -qE "$pat" "$T/$label.out" && return 1
  grep -qE 'OK|PASS' "$T/$label.out" || return 1
  return 0
}

declare -A RC
run "V1 docs numbers"          "$HERE/check_docs_numbers.sh"
script_ok "V1 docs numbers" '^V1 FAIL' && RC[V1]=0 || RC[V1]=1
script_ok "V1 docs numbers" '^V68 FAIL' && RC[V68]=0 || RC[V68]=1
script_ok "V1 docs numbers" '^V77 FAIL' && RC[V77]=0 || RC[V77]=1
run "V2 regex controls"        "$HERE/check_regex_controls.sh"
script_ok "V2 regex controls" '^V2 FAIL' && RC[V2]=0 || RC[V2]=1
run "V3-V8+V14-V17 invariants" "$HERE/check_protocol_invariants.sh"
for v in 3 4 5 7 8 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 55 56 57 58 59 60 61 62 63 64 69 71 72 73 74 75 85 90 91 92 93 94 95 96 97 99 100 101 103 104 105 106 107 108 109 110 111 113 114 115; do script_ok "V3-V8+V14-V17 invariants" "^V$v FAIL" && RC[V$v]=0 || RC[V$v]=1; done
# V37 is enforced by check_regex_controls.sh (V2 extended to all five docs), not by the invariants script
script_ok "V2 regex controls" '^V37 FAIL' && RC[V37]=0 || RC[V37]=1
# V10-V13 are aliases of V2/V5/V2/V7 respectively (SPEC.md §V)
for v in 10 12; do RC[V$v]="${RC[V2]}"; done
for v in 11; do RC[V$v]="${RC[V5]}"; done
for v in 13; do RC[V$v]="${RC[V7]}"; done
run "V6 destructive ops"       "$HERE/check_destructive_ops.sh"
script_ok "V6 destructive ops" '^V6 FAIL' && RC[V6]=0 || RC[V6]=1
run "V54 sigpipe hygiene"      "$HERE/check_sigpipe.sh"
script_ok "V54 sigpipe hygiene" '^V54 FAIL' && RC[V54]=0 || RC[V54]=1
run "V9 fetch url"             "$HERE/selftest_fetch.sh"
script_ok "V9 fetch url" '^V9 FAIL' && RC[V9]=0 || RC[V9]=1
run "V76 fetch publish"        "$HERE/selftest_fetch_publish.sh"
script_ok "V76 fetch publish" '^V76 FAIL' && RC[V76]=0 || RC[V76]=1
script_ok "V76 fetch publish" '^V78 FAIL' && RC[V78]=0 || RC[V78]=1
run "GATE crc self-test"       "$HERE/selftest_gates.sh"
# GATE (item 19): needs the explicit SELFTEST PASS string AND exit 0.
if [ "$(cat "$T/GATE crc self-test.rc")" -eq 0 ] && grep -q 'SELFTEST PASS' "$T/GATE crc self-test.out"; then RC[GATE]=0; else RC[GATE]=1; fi
run "PY unit tests"              "$HERE/selftest_python.sh"
script_ok "PY unit tests" '^V65 FAIL' && RC[V65]=0 || RC[V65]=1
run "GUARD fastboot stub"          "$HERE/selftest_fastboot_guard.sh"
script_ok "GUARD fastboot stub" '^V66 FAIL' && RC[V66]=0 || RC[V66]=1
script_ok "GUARD fastboot stub" '^V89 FAIL' && RC[V89]=0 || RC[V89]=1
script_ok "V3-V8+V14-V17 invariants" '^V98 FAIL' && inv98=0 || inv98=1
script_ok "GUARD fastboot stub" '^V98 FAIL' && grd98=0 || grd98=1
if [ "$inv98" -eq 0 ] && [ "$grd98" -eq 0 ]; then RC[V98]=0; else RC[V98]=1; fi
script_ok "V3-V8+V14-V17 invariants" '^V102 FAIL' && inv102=0 || inv102=1
script_ok "GUARD fastboot stub" '^V102 FAIL' && grd102=0 || grd102=1
if [ "$inv102" -eq 0 ] && [ "$grd102" -eq 0 ]; then RC[V102]=0; else RC[V102]=1; fi
script_ok "V3-V8+V14-V17 invariants" '^V112 FAIL' && inv112=0 || inv112=1
script_ok "GUARD fastboot stub" '^V112 FAIL' && grd112=0 || grd112=1
if [ "$inv112" -eq 0 ] && [ "$grd112" -eq 0 ]; then RC[V112]=0; else RC[V112]=1; fi
run "CONFIG table"                   "$HERE/check_config_table.sh"
script_ok "CONFIG table" '^V70 FAIL' && RC[V70]=0 || RC[V70]=1
run "MODSIG matrix"                    "$HERE/verify_modsig.sh" --selftest-full
script_ok "MODSIG matrix" '^V67 FAIL' && RC[V67]=0 || RC[V67]=1
run "BUILD claims"                   "$HERE/check_build_claims.sh"
for v in 79 80 81 82 83 84 86 87 88; do script_ok "BUILD claims" "^V$v FAIL" && RC[V$v]=0 || RC[V$v]=1; done

echo "=== resumo dos invariantes ==="
bad=0
for v in V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12 V13 V14 V15 V16 V17 V18 V19 V20 V21 V22 V23 V24 V25 V26 V27 V28 V29 V30 V31 V32 V33 V34 V35 V36 V37 V38 V39 V40 V41 V42 V43 V44 V45 V46 V47 V48 V49 V50 V51 V52 V53 V54 V55 V56 V57 V58 V59 V60 V61 V62 V63 V64 V65 V66 V67 V68 V69 V70 V71 V72 V73 V74 V75 V76 V77 V78 V79 V80 V81 V82 V83 V84 V85 V86 V87 V88 V89 V90 V91 V92 V93 V94 V95 V96 V97 V98 V99 V100 V101 V102 V103 V104 V105 V106 V107 V108 V109 V110 V111 V112 V113 V114 V115 GATE; do
  if [ "${RC[$v]:-1}" -eq 0 ]; then printf '%-5s PASS\n' "$v"; else printf '%-5s FAIL\n' "$v"; bad=$((bad + 1)); fi
done
if [ "$bad" -eq 0 ]; then
  echo "run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V115 + gate self-test)"
  exit 0
fi
echo "run_all_checks: FAIL ($bad de 116 verificações falharam)"
exit 1
