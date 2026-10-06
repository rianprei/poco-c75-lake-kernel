#!/usr/bin/env bash
# selftest_backprop.sh — PROOF OF SABOTAGE for every new check (SPEC.md §V).
#
# For each invariant the defect that the check is supposed to catch is planted in a throwaway
# copy of the repo (mktemp -d, never the working tree): the check must FAIL and cite the line,
# and the pristine copy must PASS. No case is trusted unless it demonstrably flips FAIL -> PASS.
#
# usage: tools/selftest_backprop.sh      (read-only on the repo; exit 0 = every case detected)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"

BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
PRISTINE="$BASE/pristine"; mkdir -p "$PRISTINE"
cp -a "$ROOT/tools" "$ROOT/tests" "$ROOT/docs" "$ROOT/data" "$ROOT/scripts" "$ROOT/README.md" "$PRISTINE/"

pass=0; fail=0
case_run() { # <n> <label> <check script> <expected FAIL pattern> <mutation (bash, runs inside the copy)>
  local n="$1" label="$2" script="$3" pat="$4" mut="$5"
  local dir out rc
  dir="$(mktemp -d "$BASE/case.XXXXXX")"; cp -a "$PRISTINE/." "$dir/"
  ( cd "$dir" && eval "$mut" ) >/dev/null 2>&1
  out="$( cd "$dir" && bash "tools/$script" 2>&1 )"; rc=$?
  printf '### [%s] %s\n' "$n" "$label"
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qE "$pat"; then
    printf '    defeito plantado DETECTADO: exit=%s, casou /%s/\n' "$rc" "$pat"
    printf '%s\n' "$out" | grep -E "$pat" | head -2 | sed 's/^/      /'
    local pout prc
    pout="$( cd "$PRISTINE" && bash "tools/$script" 2>&1 )"; prc=$?
    if [ "$prc" -eq 0 ]; then
      printf '    cópia limpa: PASS (exit=0)\n  => OK   FAIL->PASS\n\n'
      pass=$((pass + 1))
    else
      printf '    cópia limpa NÃO passa (exit=%s) — invariante quebrado no repo!\n  => FALHA (pristine)\n\n' "$prc"
      fail=$((fail + 1))
    fi
  else
    printf '    defeito NÃO detectado (exit=%s) — teste cego\n  => FALHA\n\n' "$rc"
    fail=$((fail + 1))
  fi
  rm -rf "$dir"
}

DMESG_PAT='Unknown symbol|disagrees about version|exports protected symbol|Invalid module format|kCFI|BUG: kernel NULL pointer|Kernel panic'

case_run 1 "V1 README 557 -> 215 (o bug da auditoria de 2026-10-06)" check_docs_numbers.sh '^V1 FAIL' \
  "sed -i 's/557/215/g' README.md"

case_run 2 "V2 controle POSITIVO: padrão dmesg trocado por algo que nunca casa" check_regex_controls.sh '^V2 FAIL' \
  "sed -i 's/$DMESG_PAT/ZZZ_never_matches/' docs/DEVICE-TEST-PROTOCOL.md"

case_run 3 "V2 pipe escapado dentro de -E (o padrão que nunca casava)" check_regex_controls.sh '^V2 FAIL' \
  "sed -i 's/Unknown symbol|disagrees/Unknown symbol\\\\|disagrees/' docs/DEVICE-TEST-PROTOCOL.md"

case_run 4 "V3 instrução positiva de troca de slot no protocolo" check_protocol_invariants.sh '^V3 FAIL' \
  "printf '\n| T4 | then run \`fastboot set_active a\` to test the other slot | yes | n/a |\n' >> docs/DEVICE-TEST-PROTOCOL.md"

case_run 5 "V4 fastboot boot afirmado como suportado" check_protocol_invariants.sh '^V4 FAIL' \
  "printf '\nfastboot boot is supported on lake for v4 images.\n' >> docs/DEVICE-TEST-PROTOCOL.md"

case_run 6 "V5 alegação de ausência com uma única fonte" check_protocol_invariants.sh '^V5 FAIL' \
  "printf '\n7. **The userdata partition is not in this project backup.**\n' >> docs/SAFETY.md"

case_run 7 "V6 rm -rf em caminho literal" check_destructive_ops.sh '^V6 FAIL' \
  "printf '\nrm -rf /tmp/opencode\n' >> tools/gate_kmi_crc.sh"

case_run 8 "V7 afirmação de comportamento do kernel sem fonte" check_protocol_invariants.sh '^V7 FAIL' \
  "python3 -c \"import pathlib;p=pathlib.Path('docs/KMI-GATES.md');p.write_text(p.read_text().replace('\`same_magic()\` (kernel/module/version.c)','\`same_magic()\`'))\""

case_run 9 "V8 linha da tabela de fatos sem coluna de prova" check_protocol_invariants.sh '^V8 FAIL' \
  "python3 -c \"import pathlib;p=pathlib.Path('docs/PLAN-AND-FINDINGS.pt-BR.md');p.write_text(p.read_text().replace('| OPENCODE2_boot_safety.md §1 |','|   |'))\""

case_run 10 "V9 URL do fetch alterada (build errado)" selftest_fetch.sh '^V9 FAIL' \
  "sed -i 's/^BID=13771415/BID=99999999/' tools/fetch_official_artifacts.sh"

# FIX7 (lk evidence) — the failures the cross-review found, and their checks:

# V14: a bootloader-behaviour claim with no evidence and no INFERRED label
case_run 11 "V14 afirmação sobre o LK sem evidência e sem rótulo" check_protocol_invariants.sh '^V14 FAIL' \
  "printf '\\nThe LK always writes the image in one single uninterrupted pass.\\n' >> docs/SAFETY.md && sed -i 's/What we verified in the real bootloader (and what we did not)/XXX/' docs/SAFETY.md"

# V15: the legacy RAM-boot offered again as an executable step
case_run 12 "V15 fastboot boot de volta como passo executável" check_protocol_invariants.sh '^V15 FAIL' \
  "printf '\\n| T-pre | fastboot boot boot_b_new.img to try it in RAM | no | boots |\\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V16: the whole pre-flight write gate removed (size/partition-size/hash gone)
case_run 13 "V16 pré-voo de gravação removido do protocolo" check_protocol_invariants.sh '^V16 FAIL' \
  "sed -i '/partition-size:boot_b/d; /0x4000000/d; /67108864/d; /sha256sum boot_b_new.img/d' docs/DEVICE-TEST-PROTOCOL.md"

# V17: check order presented as fact (strings-only proof) — INFERRED label replaced by 'measured'
case_run 14 "V17 rótulo INFERRED (other device) trocado por 'measured'" check_protocol_invariants.sh '^V17 FAIL' \
  "sed -i 's/the \\*order\\* of this check relative to the write is \\*\\*INFERRED (other device)\\*\\*/the order of this check is measured/' docs/SAFETY.md"

# FIX8 (T-1 rehearsal) — the write path must be demonstrated with identical content first:

# V18: the T-1 step (identical-content reflash) removed
case_run 15 "V18 T-1 write rehearsal removed from the protocol" check_protocol_invariants.sh '^V18 FAIL' \
  "sed -i '/^### T-1 /d' docs/DEVICE-TEST-PROTOCOL.md"

# FIX8 (disassembly findings) — the SAFETY LK table must keep the RE2/RE4 rows:

# V19: a disassembly citation dropped from the SAFETY bootloader table
case_run 16 "V19 fastboot_init citation dropped from the SAFETY LK table" check_protocol_invariants.sh '^V19 FAIL' \
  "sed -i '/fcn.4c461724/d' docs/SAFETY.md"

# FIX8 (is-userspace) — absence claims about the variable must be caught:

# V20: is-userspace described as absent from the real binary
case_run 17 "V20 is-userspace described as absent" check_protocol_invariants.sh '^V20 FAIL' \
  "printf '\nNote: is-userspace does not exist in lk_b.\n' >> docs/SAFETY.md"

# FIX9 (Z0 closed allowlist) — one sabotage per new invariant:

# V21: one allowlist getvar deleted from Z0.3
case_run 18 "V21 Z0 allowlist getvar deleted" check_protocol_invariants.sh '^V21 FAIL' \
  "sed -i '/^  \`fastboot getvar battery-soc-ok\`$/d' docs/DEVICE-TEST-PROTOCOL.md"

# V22: adb reboot promoted from optional/documentary to required
case_run 19 "V22 adb reboot no longer marked optional" check_protocol_invariants.sh '^V22 FAIL' \
  "sed -i 's/Z0.0 (optional, documentary)/Z0.0 (mandatory)/' docs/DEVICE-TEST-PROTOCOL.md"

# V23: slot!=b rule flipped to 'always fastboot reboot'
case_run 20 "V23 slot!=b rule flipped" check_protocol_invariants.sh '^V23 FAIL' \
  "sed -i 's/never \`fastboot reboot\`/always \`fastboot reboot\`/' docs/DEVICE-TEST-PROTOCOL.md"

# V24: charger requirement flipped to connected
case_run 21 "V24 charger requirement flipped" check_protocol_invariants.sh '^V24 FAIL' \
  "sed -i 's/charger disconnected/charger connected/' docs/DEVICE-TEST-PROTOCOL.md"

# V25: second failure no longer ends the day
case_run 22 "V25 second failure no longer ends the day" check_protocol_invariants.sh '^V25 FAIL' \
  "sed -i 's/second failure ends the day/second failure try again/' docs/DEVICE-TEST-PROTOCOL.md"

# V26: '~429' promoted from reference to criterion
case_run 23 "V26 day baseline replaced by ~429 criterion" check_protocol_invariants.sh '^V26 FAIL' \
  "sed -i 's/\`~429\` is only a reference/\`~429\` is the criterion/' docs/DEVICE-TEST-PROTOCOL.md"

# V27: honest list of what Z0 does not prove deleted
case_run 24 "V27 honest not-proven list deleted" check_protocol_invariants.sh '^V27 FAIL' \
  "sed -i '/What Z0 does not prove/d' docs/DEVICE-TEST-PROTOCOL.md"

printf 'SABOTAGENS: %s detectada(s) FAIL->PASS, %s falha(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && { echo 'SELFTEST-BACKPROP PASS'; exit 0; } || { echo 'SELFTEST-BACKPROP FAIL'; exit 1; }
