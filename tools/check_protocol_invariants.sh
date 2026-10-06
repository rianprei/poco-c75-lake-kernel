#!/usr/bin/env bash
# check_protocol_invariants.sh — structural invariants of the device-facing docs:
#   V3  no slot switch without the documented both-slots firmware comparison
#   V4  bootloader-dependent commands are never asserted as supported (fastboot boot = UNKNOWN)
#   V5  an absence claim cites >= 2 independent sources
#   V7  a claim about kernel behaviour cites the source file (a .c/.h/.cpp, or the CONFIG symbol)
#   V8  every fact row in the facts log carries a non-empty proof column, and the raw research
#       notes carry the "contains errors / UNVERIFIED links" warning
#   V14 every bootloader claim cites real-lk_b.img evidence or is labelled INFERRED (other device)
#   V15 no alternative boot path is an executable protocol step; legacy RAM-boot discarded
#   V16 every getvar check declares tolerated answers incl. 'Variable not found'; write pre-flight
#       (partition-size:boot_b = 0x4000000 == file bytes 67108864 + sha256) is present
#   V17 order/behaviour claims about the LK are labelled INFERRED (other device), never PROVED from
#   V18 the first write is an identical-content rehearsal (T-1) gated on Z0 PASS + owner yes
#   V19 SAFETY bootloader-fallback rows cite the RE2/RE4 disassembly reports
#   V20 is-userspace is never described as absent from the real binary
#   V21 Z0 runs a closed getvar allowlist; 'getvar all' and any 'oem' are forbidden there
#   V22 Z0 PASS is powered-off key entry; adb reboot is documentary only
#   V23 slot != b means power off by keys, never 'fastboot reboot'
#   V24 charger disconnected during Z0
#   V25 3-min no-adb procedure ends the day on second failure, no USB improvisation
#   V26 day baseline is the criterion, '~429' is reference only
#   V27 the honest list of what Z0 does not prove is present
#
# What each check can and cannot automate is spelled out in SPEC.md §V; anything left to manual
# review is printed as "V<n> NOTE manual-review" so the gap is visible instead of silent.
#
# usage: tools/check_protocol_invariants.sh     (read-only; prints V<n> PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"

fails=0
fail() { printf 'V%s FAIL %s\n' "$1" "$2"; fails=$((fails + 1)); }
note() { printf 'V%s NOTE manual-review %s\n' "$1" "$2"; }
ok()   { printf 'V%s OK %s\n' "$1" "$2"; }

PROTO=docs/DEVICE-TEST-PROTOCOL.md
SAFETY=docs/SAFETY.md

# ------------------------------------------------------------------------------------------------
# V3 — slot switching is forbidden unless both slots' firmware is compared first
# ------------------------------------------------------------------------------------------------
if grep -qE 'avbtool info_image' "$PROTO" && grep -qE 'vbmeta_a' "$PROTO" && grep -qE 'vbmeta_b' "$PROTO" \
   && grep -qiE 'never switch slots|do \*\*not\*\* run `set_active`' "$PROTO"; then
  ok 3 "protocol compares avbtool info_image of vbmeta_a and vbmeta_b and forbids slot switching"
else
  fail 3 "$PROTO does not both forbid slot switching AND require avbtool info_image on vbmeta_a + vbmeta_b"
fi
# no *executable* positive slot-switch instruction (the shell guard that blocks one is fine)
exec_switch="$(grep -nE 'fastboot +(--?set-active|set_active)\b' "$PROTO" | grep -viE 'not|never|BLOQUEADO|proibido|blocked|STOP|abort' || true)"
if [ -n "$exec_switch" ]; then
  fail 3 "positivo comando de troca de slot em $PROTO: $(printf '%s' "$exec_switch" | head -1 | cut -c1-100)"
else
  ok 3 "no un-negated 'fastboot set_active' instruction in $PROTO"
fi

# ------------------------------------------------------------------------------------------------
# V4 — fastboot boot is UNKNOWN on lake, never asserted as a fact
# ------------------------------------------------------------------------------------------------
if grep -E 'fastboot boot' "$PROTO" | grep -qiE 'UNKNOWN'; then
  ok 4 "$PROTO states the fastboot boot caveat (UNKNOWN) next to the command"
else
  fail 4 "$PROTO mentions fastboot boot without any UNKNOWN caveat"
fi
asserted="$(grep -nEi 'fastboot boot (is|works|is supported|will work|is available|supports)|supported on (lake|this device)' "$PROTO" "$SAFETY" README.md || true)"
if [ -n "$asserted" ]; then
  fail 4 "afirmação positiva de suporte a fastboot boot: $(printf '%s' "$asserted" | head -1 | cut -c1-100)"
else
  ok 4 "no positive support claim for fastboot boot in $PROTO/$SAFETY/README.md"
fi
grep -qE 'unknown command' "$PROTO" && grep -qiE 'stop' "$PROTO" \
  && ok 4 "protocol STOPs when the bootloader answers 'unknown command'" \
  || fail 4 "protocol does not STOP on 'unknown command'"

# ------------------------------------------------------------------------------------------------
# V5 — an absence claim cites >= 2 independent sources
# ------------------------------------------------------------------------------------------------
python3 - "$PROTO" "$SAFETY" <<'PY'
import re, sys
# Empirical absence claims about the device/firmware/backup. Statements about the doc's own tables
# ("nothing in T0/T2 writes flash") are not absence claims and are out of scope — see SPEC.md §V5.
MARK = re.compile(r'does not contain|is not in (?:this project|the backup|the dump|the repo)'
                  r'|has no public recovery|no `wipe` flag|no entry in'
                  r'|is \*\*UNKNOWN\*\*|never (?:verified|observed|present)')
TOKEN = re.compile(r'`[^`]*(?:/|\.(?:md|cpp|cc|c|h|txt|log|tsv|csv|bzl))[^`]*`'
                   r'|\bfacts? \d+|\bfato \d+|\bmeasurement M\d+|\bM\d\b')
bad = 0
for path in sys.argv[1:]:
    for i, line in enumerate(open(path), 1):
        if not MARK.search(line):
            continue
        n = len(set(m.group(0) for m in TOKEN.finditer(line)))
        if n < 2:
            bad += 1
            print(f'V5 FAIL {path}:{i} alegação de ausência com {n} fonte(s) independente(s): {line.strip()[:110]}')
if bad == 0:
    print('V5 OK every absence claim in the protocol/safety docs cites 2+ independent sources')
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fails=$((fails + 1))
note 5 "scope: empirical absence claims only; 'nothing in T0/T2 writes flash' is a statement about the doc's own table, checked by reading the table"

# ------------------------------------------------------------------------------------------------
# V7 — claims about kernel behaviour cite their source
# ------------------------------------------------------------------------------------------------
python3 - README.md docs/KMI-GATES.md docs/SAFETY.md <<'PY'
import re, sys
BEHAVIOUR = re.compile(r'same_magic|skips the first token|MODULE_SIG_PROTECT|sig_ok|protected export'
                       r'|partition_wiped|first_stage_mount|fs_mgr_do_format|MODVERSIONS')
CITE = re.compile(r'\.(?:c|h|cpp)\b|CONFIG_[A-Z0-9_]+|\bAOSP\b|`[^`]*/[^`]*`')
bad = 0
for path in sys.argv[1:]:
    for i, line in enumerate(open(path), 1):
        if BEHAVIOUR.search(line) and not CITE.search(line):
            bad += 1
            print(f'V7 FAIL {path}:{i} afirmação de comportamento do kernel sem fonte: {line.strip()[:110]}')
if bad == 0:
    print('V7 OK every kernel-behaviour claim cites a source file or CONFIG symbol')
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fails=$((fails + 1))

# ------------------------------------------------------------------------------------------------
# V14 — bootloader claims cite the real lk_b.img evidence or are labelled INFERRED (other device)
# ------------------------------------------------------------------------------------------------
if grep -qE 'What we verified in the real bootloader' "$SAFETY" && grep -qF 'strings -n 5 backup-2026-10-05/lk_b.img' "$SAFETY" && grep -qF 'INFERRED (other device)' "$SAFETY"; then
  ok 14 "$SAFETY has the real-bootloader evidence table (lk_b.img strings source + INFERRED labelling)"
else
  fail 14 "$SAFETY lost the LK evidence table (source command, INFERRED label, or the table itself)"
fi
# the key protective strings must stay quoted somewhere in the public docs
for s in 'size too large, space small' 'Forbidden to erase boot/preloader partition.' "download for partition '%s' is not allowed" 'flash preloader is not permitted.'; do
  grep -qF "$s" "$SAFETY" || fail 14 "$SAFETY não cita mais a string do lk_b real: $s"
done
if grep -qF 'INFERRED (other device)' "$PROTO" || grep -qF 'RE1_opencode_flash.md' "$PROTO"; then
  ok 14 "protocol labels LK check order (INFERRED other-device, or cites RE1 disassembly)"
else
  fail 14 "$PROTO states LK check order with neither INFERRED (other device) nor RE1 evidence"
fi
note 14 "that each quoted string really is in lk_b.img is NOT automatable here (the binary is retained, not published); the quoted strings were grepped against /tmp/lk_b_strings.txt during the FIX7 review"

# ------------------------------------------------------------------------------------------------
# V15 — no alternative boot path is an executable step; legacy RAM-boot explicitly discarded
# ------------------------------------------------------------------------------------------------
ram_exec="$(grep -nE 'fastboot +boot ' "$PROTO" | grep -viE 'NOT part|UNKNOWN|discarded|hypothesis|never|no fastboot boot|without' || true)"
if [ -n "$ram_exec" ]; then
  fail 15 "$PROTO still offers 'fastboot boot' as a step: $(printf '%s' "$ram_exec" | head -1 | cut -c1-100)"
else
  ok 15 "no executable 'fastboot boot' step in $PROTO"
fi
grep -qF 'Why the legacy RAM-boot is discarded' "$PROTO" \
  && grep -qF 'slot_suffix' "$PROTO" \
  && ok 15 "protocol documents why the legacy RAM-boot was discarded (slot-selection risk)" \
  || fail 15 "$PROTO lost the 'Why the legacy RAM-boot is discarded' rationale (slot_suffix risk)"
grep -qE 'no fastboot boot|No RAM test|NOT part of this protocol' "$SAFETY" \
  && ok 15 "$SAFETY states the RAM path is not used" \
  || fail 15 "$SAFETY no longer rules out the RAM path"

# ------------------------------------------------------------------------------------------------
# V16 — getvar checks tolerate 'Variable not found'; the write pre-flight is present
# ------------------------------------------------------------------------------------------------
grep -qF 'Variable not found' "$PROTO" \
  && ok 16 "protocol declares 'Variable not found' as an accepted answer" \
  || fail 16 "$PROTO does not tolerate 'Variable not found' (false-stop risk, B16)"
grep -qF 'partition-size:boot_b' "$PROTO" \
  && grep -qF '0x4000000' "$PROTO" \
  && grep -qF '67108864' "$PROTO" \
  && grep -qF 'sha256sum' "$PROTO" \
  && ok 16 "write pre-flight present: partition-size:boot_b = 0x4000000, file = 67108864 B, sha256 checked" \
  || fail 16 "$PROTO lost the pre-flight write gate (partition-size/size/hash)"
grep -qE 'is-userspace.?=.?(yes|fastbootd)' "$PROTO" && grep -qiE 'STOP' "$PROTO" \
  && ok 16 "is-userspace=yes (fastbootd) is a STOP" \
  || fail 16 "$PROTO does not STOP on is-userspace=yes (fastbootd)"
note 16 "the runtime value of is-userspace on this LK is UNVERIFIED (SPEC.md §T); tolerating both non-fastbootd answers is the only safe reading until a Z0 run"

# ------------------------------------------------------------------------------------------------
# V17 — PROVED/MEASURED bootloader claims need evidence of the right kind (order needs disassembly)
# ------------------------------------------------------------------------------------------------
if grep -qF 'RE1_opencode_flash.md' "$SAFETY"; then
  ok 17 "the size/write order cites RE1 disassembly of the real binary"
else
  fail 17 "$SAFETY lost the RE1 disassembly citation for the size/write order"
fi
if grep -qF '**INFERRED (other device)** — never cite as a property of this bootloader' "$SAFETY"; then
  ok 17 "gemini-sourced claims keep the INFERRED (other device) label"
else
  fail 17 "$SAFETY lost the INFERRED (other device) label on gemini-sourced claims"
fi
grep -qiE 'PROVED' "$SAFETY" "$PROTO" \
  && fail 17 "the word PROVED appears in device-facing docs (strings-only existence must not be called proof of order)" \
  || ok 17 "no PROVED claim in the device-facing docs"
grep -qF 'from *this* check, run by you' "$PROTO" \
  && ok 17 "protocol derives the oversize protection from its own pre-flight, not from the LK's assumed order" \
  || fail 17 "$PROTO does not state that the size protection is the reader's own pre-flight check"

# ------------------------------------------------------------------------------------------------
# V18 — the first write is an identical-content rehearsal (T-1) gated on Z0 PASS + owner yes
# ------------------------------------------------------------------------------------------------
t1="$(sed -n '/^### T-1/,/^| T2b/p' "$PROTO")"
if [ -z "$t1" ]; then
  fail 18 "$PROTO lost the T-1 identical-content write rehearsal"
else
  printf '%s\n' "$t1" | grep -qi 'Z0 PASS' \
    && ok 18 "T-1 is gated on Z0 PASS" \
    || fail 18 "T-1 is not gated on Z0 PASS"
  printf '%s\n' "$t1" | grep -qiE "owner.*yes" \
    && ok 18 "T-1 requires the owner's explicit yes" \
    || fail 18 "T-1 lacks the owner-yes gate"
  printf '%s\n' "$t1" | grep -q 'sha256sum' \
    && ok 18 "T-1 verifies the backup hash before writing" \
    || fail 18 "T-1 lacks the backup hash check"
  printf '%s\n' "$t1" | grep -qi 'identical' \
    && ok 18 "T-1 writes identical content only" \
    || fail 18 "T-1 does not state identical content"
  printf '%s\n' "$t1" | grep -q 'flash boot_b' \
    && printf '%s\n' "$t1" | grep -q 'backup' \
    && ok 18 "T-1 names the backup-image flash command" \
    || fail 18 "T-1 does not name the backup-image flash command"
fi
grep -qF 'one and only write command' "$PROTO" \
  && fail 18 "$PROTO still claims a single write command (T-1 is the second)" \
  || ok 18 "no stale single-write sentence in $PROTO"

# ------------------------------------------------------------------------------------------------
# V19 — SAFETY bootloader-fallback rows cite the RE2/RE4 disassembly reports
# ------------------------------------------------------------------------------------------------
for token in 'RE4_codex_fallback.md' 'RE2_codex_bootmode.md' 'fcn.4c461724' '0x4c42b264'; do
  grep -qF "$token" "$SAFETY" \
    && ok 19 "$SAFETY cites $token" \
    || fail 19 "$SAFETY lost the disassembly citation: $token"
done
grep -qiE 'retry.*UNVERIFIED' "$SAFETY" \
  && ok 19 "retry mechanics stay labelled UNVERIFIED" \
  || fail 19 "retry mechanics lost the UNVERIFIED label"

# ------------------------------------------------------------------------------------------------
# V20 — is-userspace is never described as absent from the real binary
# ------------------------------------------------------------------------------------------------
bad20="$(grep -nEi 'is-userspace[^`]{0,90}(does not exist|do not exist|not exist|absent|missing|no such)' README.md docs/SAFETY.md docs/DEVICE-TEST-PROTOCOL.md docs/PLAN-AND-FINDINGS.pt-BR.md docs/KMI-GATES.md docs/BUILD.md 2>/dev/null || true)"
if [ -z "$bad20" ]; then
  ok 20 "no instruction presents is-userspace as absent from lk_b.img"
else
  fail 20 "absence claim about is-userspace: $(printf '%s' "$bad20" | head -1 | cut -c1-120)"
fi

# ------------------------------------------------------------------------------------------------
# V21 — Z0 runs a closed getvar allowlist; 'getvar all' and any 'oem' are forbidden there
# ------------------------------------------------------------------------------------------------
z0="$(sed -n '/^### Z0/,/^### T-1/p' "$PROTO")"
if [ -z "$z0" ]; then
  fail 21 "$PROTO lost the Z0 section the allowlist lives in"
else
  for v in product current-slot slot-count is-userspace unlocked max-download-size \
      partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a \
      slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage; do
    printf '%s\n' "$z0" | grep -qF "getvar $v" \
      && ok 21 "Z0 allowlist contains getvar $v" \
      || fail 21 "Z0 allowlist lost getvar $v"
  done
  printf '%s\n' "$z0" | grep -q 'getvar all' \
    && printf '%s\n' "$z0" | grep -qiE 'forbidden|PROIBIDO|outside this list' \
    && ok 21 "Z0 forbids 'getvar all'" \
    || fail 21 "Z0 does not forbid 'getvar all'"
  printf '%s\n' "$z0" | grep -q 'oem allow-wipe-userdata' \
    && ok 21 "Z0 names the oem wipe permission it refuses to touch" \
    || fail 21 "Z0 lost the 'oem allow-wipe-userdata' warning"
fi

# ------------------------------------------------------------------------------------------------
# V22 — Z0 PASS is powered-off key entry; adb reboot is documentary only
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -qi 'powered off' \
  && printf '%s\n' "$z0" | grep -q 'Vol' \
  && ok 22 "Z0 PASS requires powered-off key entry" \
  || fail 22 "Z0 PASS is not powered-off key entry"
printf '%s\n' "$z0" | grep -qF 'Z0.0 (optional' \
  && ok 22 "adb reboot bootloader is marked optional/documentary (Z0.0)" \
  || fail 22 "adb reboot bootloader is not marked optional (Z0.0)"

# ------------------------------------------------------------------------------------------------
# V23 — slot != b means power off by keys, never 'fastboot reboot'
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -qF 'never `fastboot reboot`' \
  && ok 23 "slot != b means power off by keys, never 'fastboot reboot'" \
  || fail 23 "Z0 lost the slot!=b power-off rule"

# ------------------------------------------------------------------------------------------------
# V24 — charger disconnected during Z0
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -qi 'charger disconnected' \
  && ok 24 "Z0 requires the charger disconnected" \
  || fail 24 "Z0 lost the charger-disconnected requirement"

# ------------------------------------------------------------------------------------------------
# V25 — 3-min no-adb procedure ends the day on second failure, no USB improvisation
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -q '3 min' \
  && printf '%s\n' "$z0" | grep -q 'second failure ends the day' \
  && printf '%s\n' "$z0" | grep -q 'no USB improvisation' \
  && ok 25 "Z0 no-adb procedure: 3 min, keys once, second failure ends the day" \
  || fail 25 "Z0 lost the no-adb procedure"

# ------------------------------------------------------------------------------------------------
# V26 — day baseline is the criterion, '~429' is reference only
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -E '429' | grep -qi 'reference' \
  && ok 26 "day baseline is the criterion, '~429' is reference only" \
  || fail 26 "Z0 lost the day-baseline rule"

# ------------------------------------------------------------------------------------------------
# V27 — the honest list of what Z0 does not prove is present
# ------------------------------------------------------------------------------------------------
printf '%s\n' "$z0" | grep -qi 'does not prove' \
  && printf '%s\n' "$z0" | grep -q 'UNVERIFIED' \
  && ok 27 "Z0 carries the honest list of what it does not prove" \
  || fail 27 "Z0 lost the honest list of what it does not prove"

# ------------------------------------------------------------------------------------------------
# V28 — every tools/*.sh is executable (index 100755 and on-disk +x)
# ------------------------------------------------------------------------------------------------
bad28=""
for f in tools/*.sh; do
  [ -x "$f" ] || bad28="$bad28 $f"
done
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  idxbad="$(git ls-files -s tools/*.sh | awk '$1 != "100755" {print $4}')"
  [ -z "$idxbad" ] || bad28="$bad28(index:$idxbad)"
fi
if [ -z "$bad28" ]; then
  ok 28 "every tools/*.sh is executable (index 100755, on-disk +x)"
else
  fail 28 "non-executable tools/*.sh:$bad28"
fi

# ------------------------------------------------------------------------------------------------
# V29 — SAFETY names exactly the measured LK table names; the 7 unprotected names say so
# ------------------------------------------------------------------------------------------------
names29="$(awk '!/^#/ && NF {print $2}' data/lk_tables.tsv)"
[ "$(printf '%s\n' "$names29" | wc -l)" -eq 14 ] \
  && ok 29 "data/lk_tables.tsv lists 14 table names" \
  || fail 29 "data/lk_tables.tsv does not list 14 names"
for n in $names29; do
  grep -qF "$n" "$SAFETY" \
    && ok 29 "SAFETY names table entry $n" \
    || fail 29 "SAFETY lost table name: $n"
done
for s in 'lk is NOT in either table' 'seccfg is NOT in either table' 'expdb is NOT in either table' \
         'misc is NOT in either table' 'boot_para is NOT in either table' 'vbmeta is NOT in either table' \
         'vendor_boot is NOT in either table'; do
  grep -qF "$s" "$SAFETY" \
    && ok 29 "SAFETY states: $s" \
    || fail 29 "SAFETY lost: $s"
done

# ------------------------------------------------------------------------------------------------
# V30 — no doc outside research orders 'getvar all' (only prohibitions may mention it)
# ------------------------------------------------------------------------------------------------
hits30="$(grep -rn 'getvar all' README.md docs/*.md 2>/dev/null || true)"
bad30="$(printf '%s\n' "$hits30" | grep -viE 'forbid|PROIBIDO|never run|not run|allowlist|instead' || true)"
if [ -z "$bad30" ]; then
  ok 30 "no executable 'getvar all' outside docs/research/"
else
  fail 30 "executable 'getvar all': $(printf '%s' "$bad30" | head -1 | cut -c1-120)"
fi

# ------------------------------------------------------------------------------------------------
# V31 — 'fastboot flash' count in the protocol == README number (2), target always boot_b
# ------------------------------------------------------------------------------------------------
nflash="$(grep -c 'fastboot flash' "$PROTO")"
[ "$nflash" -eq 2 ] \
  && ok 31 "protocol has exactly 2 'fastboot flash' commands (T-1, T3)" \
  || fail 31 "protocol has $nflash 'fastboot flash' commands, README affirms 2"
grep 'fastboot flash' "$PROTO" | grep -vq 'flash boot_b' \
  && fail 31 "a 'fastboot flash' targets something other than boot_b" \
  || ok 31 "every 'fastboot flash' targets boot_b"
grep -qF 'two protected writes of `boot_b` (T-1 backup, T3 kernel)' README.md \
  && ok 31 "README affirms two protected writes (T-1 backup, T3 kernel)" \
  || fail 31 "README lost the two-writes count"
grep -q 'command fastboot flash boot_b <path/to/backup/boot_b.img>' "$PROTO" \
  && ok 31 "T-1 block line keeps the guarded bypass form" \
  || fail 31 "T-1 block line lost the guarded bypass form"

# ------------------------------------------------------------------------------------------------
# V32 — T-1 comes after R3 (it depends on R3)
# ------------------------------------------------------------------------------------------------
t1line="$(grep -n '^### T-1' "$PROTO" | head -1 | cut -d: -f1)"
r3line="$(grep -n '^### R3' "$PROTO" | head -1 | cut -d: -f1)"
[ -n "$t1line" ] && [ -n "$r3line" ] && [ "$t1line" -gt "$r3line" ] \
  && ok 32 "T-1 section (line $t1line) comes after R3 (line $r3line)" \
  || fail 32 "T-1 is not after R3 (t1=$t1line r3=$r3line)"

# ------------------------------------------------------------------------------------------------
# V33 — research notes carry no machine paths (README documents the redaction)
# ------------------------------------------------------------------------------------------------
bad33="$(grep -rn '/tmp/\|/home/' docs/research/*.md 2>/dev/null | grep -v 'docs/research/README.md' || true)"
if [ -z "$bad33" ]; then
  ok 33 "no /tmp/ or /home/ paths in docs/research/ notes"
else
  fail 33 "machine paths in notes: $(printf '%s' "$bad33" | head -1 | cut -c1-120)"
fi

# ------------------------------------------------------------------------------------------------
# V8 — every fact row has a proof; the raw notes carry the warning
# ------------------------------------------------------------------------------------------------
# NB: [|] rather than \| — in ERE an escaped pipe is a literal pipe anyway, and this file's own
# V2 rule rejects the confusing form.
rows="$(grep -cE '^[|] *[0-9]+ *[|]' docs/PLAN-AND-FINDINGS.pt-BR.md)"
empty="$(awk -F'|' '/^[|] *[0-9]+ *[|]/ {p=$5; gsub(/^[ \t]+|[ \t]+$/,"",p); if (p=="") print NR}' docs/PLAN-AND-FINDINGS.pt-BR.md)"
if [ -n "$empty" ]; then
  fail 8 "linha(s) de fato sem coluna Prova em docs/PLAN-AND-FINDINGS.pt-BR.md: $(printf '%s' "$empty" | tr '\n' ' ')"
else
  ok 8 "$rows fact rows, all with a non-empty proof column"
fi
if grep -qE '\*\*They contain errors\.\*\*' docs/research/README.md && grep -qE 'UNVERIFIED' docs/research/README.md; then
  ok 8 "docs/research/README.md carries the 'contain errors' warning and the UNVERIFIED link table"
else
  fail 8 "docs/research/README.md lost the 'contain errors' warning or the UNVERIFIED link table"
fi
note 8 "that each individual FACT sentence in the raw notes has a source is NOT automatable (free prose); the proof column of the facts log is the enforced landing place"

if [ "$fails" -eq 0 ]; then
  echo "PASS protocol invariants (V3 V4 V5 V7 V8 V14 V15 V16 V17 V18 V19 V20 V21 V22 V23 V24 V25 V26 V27)"
  exit 0
fi
echo "FAIL $fails invariante(s) de protocolo"
exit 1
