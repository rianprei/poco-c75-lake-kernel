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
  if [ "$rc" -ne 0 ] && grep -qE "$pat" <<<"$out"; then
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
  "printf '\nThe LK always writes the image in one single uninterrupted pass.\n' >> docs/SAFETY.md && sed -i 's/What we verified in the real bootloader (and what we did not)/XXX/' docs/SAFETY.md"

# V15: the legacy RAM-boot offered again as an executable step
case_run 12 "V15 fastboot boot de volta como passo executável" check_protocol_invariants.sh '^V15 FAIL' \
  "printf '\n| T-pre | fastboot boot boot_b_new.img to try it in RAM | no | boots |\\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V16: the whole pre-flight write gate removed (size/partition-size/hash gone)
case_run 13 "V16 pré-voo de gravação removido do protocolo" check_protocol_invariants.sh '^V16 FAIL' \
  "sed -i '/partition-size:boot_b/d; /0x4000000/d; /67108864/d; /sha256sum boot_b_new.img/d' docs/DEVICE-TEST-PROTOCOL.md"

# V17: check order presented as fact (strings-only proof) — INFERRED label replaced by 'measured'
case_run 14 "V17 RE1 disassembly citation dropped from SAFETY" check_protocol_invariants.sh '^V17 FAIL' \
  "sed -i 's/RE1_opencode_flash.md/XXX/' docs/SAFETY.md"

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

# V21b: extra getvar added INSIDE the Z0.3 list (closed allowlist violation)
case_run 18b "V21 extra getvar added to Z0.3" check_protocol_invariants.sh '^V21 FAIL' \
  "sed -i '/^  \`fastboot getvar battery-voltage\`$/a\\  \`fastboot getvar cpuid\`' docs/DEVICE-TEST-PROTOCOL.md"

# V22: adb reboot promoted from optional/documentary to required
case_run 19 "V22 adb reboot no longer marked optional" check_protocol_invariants.sh '^V22 FAIL' \
  "sed -i 's/Z0.0 (optional, documentary)/Z0.0 (mandatory)/' docs/DEVICE-TEST-PROTOCOL.md"

# V22b: Z0.1 missing "Vol− + Power" phrase
case_run 19b "V22 Z0.1 missing Vol−+Power phrase" check_protocol_invariants.sh '^V22 FAIL' \
  "sed -i 's/hold \`Vol− + Power\` until the fastboot screen/wait for the fastboot screen to appear on its own/' docs/DEVICE-TEST-PROTOCOL.md"

# V23: slot!=b rule flipped to 'always fastboot reboot'
case_run 20 "V23 slot!=b rule flipped" check_protocol_invariants.sh '^V23 FAIL' \
  "sed -i 's/never \`fastboot reboot\`/always \`fastboot reboot\`/' docs/DEVICE-TEST-PROTOCOL.md"

# V24: charger requirement flipped to connected
case_run 21 "V24 charger requirement flipped" check_protocol_invariants.sh '^V24 FAIL' \
  "sed -i 's/charger disconnected/charger connected/' docs/DEVICE-TEST-PROTOCOL.md"

# V25: second failure no longer ends the day
case_run 22 "V25 second failure no longer ends the day" check_protocol_invariants.sh '^V25 FAIL' \
  "sed -i 's/second failure ends the day/second failure try again/' docs/DEVICE-TEST-PROTOCOL.md"

# V26: '429' promoted from example to criterion
case_run 23 "V26 day baseline replaced by 429 criterion" check_protocol_invariants.sh '^V26 FAIL' \
  "sed -i 's/429 modules (example only); your number is your baseline/429 modules is the criterion/' docs/DEVICE-TEST-PROTOCOL.md"

# V26b: 429 line has "example" but says baseline is criterion (wrong meaning)
case_run 23b "V26 429 line has example but wrong meaning" check_protocol_invariants.sh '^V26 FAIL' \
  "sed -i 's/modules ⊇ day baseline (429 modules (example only); your number is your baseline)/modules must EQUAL the audited-device count (429 is the criterion; the baseline is only for reference)/' docs/DEVICE-TEST-PROTOCOL.md"

# V27: honest list of what Z0 does not prove deleted
case_run 24 "V27 honest not-proven list deleted" check_protocol_invariants.sh '^V27 FAIL' \
  "sed -i '/What Z0 does not prove/d' docs/DEVICE-TEST-PROTOCOL.md"

# FIX10 (exec bits) — one sabotage per new invariant:

# V28: a tool script loses its exec bit
case_run 25 "V28 tool script without exec bit" check_protocol_invariants.sh '^V28 FAIL' \
  "chmod 644 tools/gate_kmi_crc.sh"

# V29: a measured table name dropped from SAFETY
case_run 26 "V29 table name dropped from SAFETY" check_protocol_invariants.sh '^V29 FAIL' \
  "sed -i 's/protect2/XXXX/' docs/SAFETY.md"

# V30: 'getvar all' ordered as an executable step
case_run 27 "V30 getvar all ordered as executable step" check_protocol_invariants.sh '^V30 FAIL' \
  "printf '\n| T9 | run \`fastboot getvar all\` and continue | no | n/a |\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V30b/V42: allowlist mentioned but the line still orders it (R10-F4)
case_run 27b "V42 getvar all with allowlist mention but executable" check_protocol_invariants.sh '^V30 FAIL' \
  "printf '\ncheck the allowlist then run fastboot getvar all\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V31: a third 'fastboot flash' command appears in the protocol
case_run 28 "V31 third fastboot flash in protocol" check_protocol_invariants.sh '^V31 FAIL' \
  "printf '\nfastboot flash super super.img\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V32: T-1 moved back before R3
case_run 29 "V32 T-1 before R3 again" check_protocol_invariants.sh '^V32 FAIL' \
  "sed -i '1i ### T-1 MOVED' docs/DEVICE-TEST-PROTOCOL.md"

# V33: a machine path planted in a research note
case_run 30 "V33 machine path in research note" check_protocol_invariants.sh '^V33 FAIL' \
  "printf '\nsee /tmp/scratch/debug.log\n' >> docs/research/RE1_opencode_flash.md"

# FIX12 (REVIEW9/REVIEW10/RUNBOOK findings) — new invariants V35-V53:

# V34: Z0 header missing mandatory/optional distinction
case_run 31 "V35 Z0 header missing mandatory/optional" check_protocol_invariants.sh '^V35 FAIL' \
  "sed -i 's/mandatory Z0 (Z0.1/Z0 writes nothing/' docs/DEVICE-TEST-PROTOCOL.md"

# V35: SAFETY missing two-writes statement
case_run 32 "V36 SAFETY missing two-writes" check_protocol_invariants.sh '^V36 FAIL' \
  "sed -i 's/two protected writes/single protected write/' docs/SAFETY.md"

# V38: extra getvar in Z0.3 (closed allowlist)
case_run 33 "V38 extra getvar in Z0.3" check_protocol_invariants.sh '^V38 FAIL' \
  "sed -i '/^  \`fastboot getvar battery-voltage\`$/a\\  \`fastboot getvar cpuid\`' docs/DEVICE-TEST-PROTOCOL.md"

# V38: stale single-write sentence
case_run 34 "V39 stale single-write sentence" check_protocol_invariants.sh '^V39 FAIL' \
  "printf '\nThe protocol has a single write command.\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V40: docs/research/README.md missing warning/UNVERIFIED
case_run 35 "V41 research README missing warning" check_protocol_invariants.sh '^V41 FAIL' \
  "sed -i 's/They contain errors./They are correct./' docs/research/README.md"

# V42: Z0.4 missing rollback index 0 / LK can boot old slot A
case_run 36 "V43 Z0.4 missing rollback index 0" check_protocol_invariants.sh '^V43 FAIL' \
  "sed -i 's/rollback index 0 means the LK can boot old slot A/old slot is not barred by rollback/' docs/DEVICE-TEST-PROTOCOL.md"

# V43: is-userspace missing "string exists in LK getvar table"
case_run 37 "V44 is-userspace missing string exists" check_protocol_invariants.sh '^V44 FAIL' \
  "sed -i 's/string \`is-userspace\` \*\*exists\*\* in the LK getvar table/the variable is-userspace does not exist/' docs/DEVICE-TEST-PROTOCOL.md"

# V44: missing RE1 citation for check-before-write order
case_run 38 "V45 missing RE1 citation for check-before-write" check_protocol_invariants.sh '^V45 FAIL' \
  "sed -i 's/check \`bl 0x4c4367d2\` precedes write \`bl 0x4c436834\`/check order is INFERRED (other device)/' docs/DEVICE-TEST-PROTOCOL.md"

# V45: T-1.2 missing exact command; T2b missing inline getvars
case_run 39 "V46 T-1.2 missing exact command" check_protocol_invariants.sh '^V46 FAIL' \
  "sed -i 's/command fastboot flash boot_b <path\\/to\\/backup\\/boot_b.img>/run the T-1 command from *The two write commands* below/' docs/DEVICE-TEST-PROTOCOL.md"

# V46: shell guard missing or doesn't allow exactly two commands
case_run 40 "V47 shell guard missing or wrong" check_protocol_invariants.sh '^V47 FAIL' \
  "sed -i 's/BLOQUEADO: comando de gravação proibido/COMMAND BLOCKED/' docs/DEVICE-TEST-PROTOCOL.md"

# V47: protect1 before protect2
case_run 41 "V48 protect1 before protect2" check_protocol_invariants.sh '^V48 FAIL' \
  "sed -i 's/protect2\`, \`protect1/protect1\`, \`protect2/g' docs/DEVICE-TEST-PROTOCOL.md && sed -i 's/protect2\`, \`protect1/protect1\`, \`protect2/g' docs/SAFETY.md"

# V48: baseline modules missing "example only" or "your number"
case_run 42 "V49 baseline missing example only" check_protocol_invariants.sh '^V49 FAIL' \
  "sed -i 's/429 modules (example only)/429 modules/' docs/DEVICE-TEST-PROTOCOL.md"

# V50: pstore reading guidance missing
case_run 43 "V50 pstore reading guidance missing" check_protocol_invariants.sh '^V50 FAIL' \
  "sed -i 's/next normal boot on a good kernel/next boot/' docs/DEVICE-TEST-PROTOCOL.md"

# V50: SAFETY Never touch missing project policy
case_run 44 "V51 SAFETY missing project policy" check_protocol_invariants.sh '^V51 FAIL' \
  "sed -i 's/project policy //; s/wider than the bootloader//' docs/SAFETY.md"

# V51: accept in writing missing specific phrase
case_run 45 "V52 accept in writing missing phrase" check_protocol_invariants.sh '^V52 FAIL' \
  "sed -i 's/I accept that slot A is older firmware OS3.0.20.0 and fallback would boot old OS over new data/accept in writing/' docs/DEVICE-TEST-PROTOCOL.md"

# V52: abort criteria missing L1-L6
case_run 46 "V53 missing L1-L6 lacunae" check_protocol_invariants.sh '^V53 FAIL' \
  "sed -i '/L1/d; /L2/d; /L3/d; /L4/d; /L5/d; /L6/d' docs/DEVICE-TEST-PROTOCOL.md"

# V42: plain executable 'getvar all' line (R10-F4, bare form)
case_run 47 "V42 bare executable getvar all line" check_protocol_invariants.sh '^V30 FAIL' \
  "printf '\nrun fastboot getvar all\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# FIX11 (V29 bidirectional / never-touch completeness) — cases preserved from the main side:

# V29: extra name inserted in the controlled table row
case_run 48 "V29 extra name in controlled table" check_protocol_invariants.sh '^V29 FAIL' \
  "sed -i 's/nvram, nvcfg, proinfo/nvram, nvcfg, seccfg, proinfo/' docs/SAFETY.md"

# V29: name moved from the erase-forbidden table into the controlled row
case_run 49 "V29 name moved between tables" check_protocol_invariants.sh '^V29 FAIL' \
  "sed -i 's/nvram, nvcfg, proinfo/nvram, nvcfg, proinfo, boot0/' docs/SAFETY.md"

# V34: never-touch rule missing misc
case_run 50 "V34 never-touch rule missing misc" check_protocol_invariants.sh '^V34 FAIL' \
  "python3 -c \"import re; t=open('docs/SAFETY.md').read(); open('docs/SAFETY.md','w').write(re.sub(r'\\\`misc\\\`, ', '', t))\""

# V34: protocol NEVER list missing boot_para
case_run 51 "V34 protocol NEVER list missing boot_para" check_protocol_invariants.sh '^V34 FAIL' \
  "python3 -c \"import re; t=open('docs/DEVICE-TEST-PROTOCOL.md').read(); open('docs/DEVICE-TEST-PROTOCOL.md','w').write(re.sub(r'\\\`boot_para\\\`', 'XXX', t))\""

# V34: protocol NEVER list missing expdb
case_run 52 "V34 protocol NEVER list missing expdb" check_protocol_invariants.sh '^V34 FAIL' \
  "python3 -c \"import re; t=open('docs/DEVICE-TEST-PROTOCOL.md').read(); open('docs/DEVICE-TEST-PROTOCOL.md','w').write(re.sub(r'\\\`expdb\\\`, ', '', t))\""

# V37: regex controls extended outside the protocol (README) — escaped pipe in an -E pattern
case_run 53 "V37 regex controls outside protocol (via V2)" check_regex_controls.sh '^V2 FAIL' \
  "sed -i '\$a Run: grep -iE \"Unknown\\\\|disagrees\" dmesg' README.md"

# V54: status-checked pipe into grep -q (SIGPIPE race under pipefail)
case_run 54 "V54 pipe into grep -q in tools" check_sigpipe.sh '^V54 FAIL' \
  "printf 'x() { printf \"%%s\\\\n\" \"\\\$z0\" | grep -qF foo; }\\n' >> tools/check_protocol_invariants.sh"

# V55: dangling PROTO:NN cross-reference (points past the last line)
case_run 55 "V55 dangling PROTO ref in protocol" check_protocol_invariants.sh '^V55 FAIL' \
  "printf '\n| Tx | see PROTO:999 for details | no | n/a |\n' >> docs/DEVICE-TEST-PROTOCOL.md"

# V39: stale suite-range description back in README
case_run 56 "V39 stale suite range in README" check_protocol_invariants.sh '^V39 FAIL' \
  "printf '\nInvariants V1–V9 + V14–V17 are checked.\n' >> README.md"

# V47: SAFETY recovery path loses the guarded command form
case_run 57 "V47 SAFETY recovery bare flash form" check_protocol_invariants.sh '^V47 FAIL' \
  "sed -i 's/\`command fastboot flash boot_b <backup boot_b.img>\`/fastboot flash boot_b <backup boot_b.img>/' docs/SAFETY.md"

# V56: T-1.3/baseline lose the adb shell prefix (would read the host)
case_run 58 "V56 bare on-device command in protocol" check_protocol_invariants.sh '^V56 FAIL' \
  "sed -i 's/adb shell uname -r/uname -r/' docs/DEVICE-TEST-PROTOCOL.md"

# V40: V22/V26 loose tokens (already covered by V22b/26b)

printf 'SABOTAGENS: %s detectada(s) FAIL->PASS, %s falha(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && { echo 'SELFTEST-BACKPROP PASS'; exit 0; } || { echo 'SELFTEST-BACKPROP FAIL'; exit 1; }