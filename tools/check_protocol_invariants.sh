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
#   V26 day baseline is the criterion; '429 modules' is example only
#   V27 the honest list of what Z0 does not prove is present
#   V28 every tools/*.sh and scripts/*.sh is executable (index 100755, on-disk +x)
#   V29 SAFETY names the 14 measured LK table names (bidirectional vs data/lk_tables.tsv)
#   V30 no executable 'getvar all' outside docs/research/
#   V31 exactly two 'fastboot flash' command lines (T-1, T3), both boot_b
#   V32 T-1 comes after R3
#   V33 research notes carry no /tmp/ or /home/ paths
#   V34 the never-touch set covers all unprotected-but-critical partitions in both docs
#   V35 Z0 header: mandatory Z0 (Z0.1-Z0.3) writes nothing; Z0.0 writes only the boot reason
#   V36 SAFETY states the two protected writes (T-1 backup, T3 kernel)
#   V37 regex controls extended to all docs outside docs/research/ (check_regex_controls.sh)
#   V38 the Z0 allowlist is closed (no extra getvar, no oem)
#   V39 no stale single-write sentence; README affirms two protected writes
#   V40 V22/V26 exact phrase/line requirements (enforced in V22/V26)
#   V41 docs/research/README.md carries the "contain errors" warning + UNVERIFIED table
#   V42 'getvar all' outside research only in lines that forbid it (stricter V30 filter)
#   V43 Z0.4 exception: rollback index 0 means the LK CAN boot old slot A (RE4 D3)
#   V44 is-userspace text states the string exists in the LK getvar table
#   V45 protocol cites RE1 disassembly for the check-before-write order
#   V46 T-1.2 names the wrapper backup command; T2b lists six exact getvar commands inline
#   V47 all fastboot goes through the exact-allowlist wrapper (no bare/command forms)
#   V48 protect2 appears before protect1 in all device-facing docs (measured order)
#   V49 baseline text says "429 modules (example only); your number is your baseline"
#   V50 pstore is read on the next normal boot on a good kernel
#   V51 SAFETY "Never touch" is project policy, wider than the LK's measured tables
#   V52 slot firmware comparison "accept in writing" = type the exact phrase in the terminal
#   V53 abort criteria include the L1-L6 lacunae
#   V55 PROTO:NN/SAFETY:NN cross-references resolve to existing lines (existence only)
#   V56 on-device observation commands carry `adb shell` (bare uname/dmesg would read the host)
#   V57 residual risks table R1-R4 with mitigation + status is present
#   V58 fastboot_guard.sh carries the exact allowlist + write gates
#   V59 protocol invokes fastboot ONLY through the guard (no bare/command forms)
#   V60 fastboot captures merge stderr (fastboot answers on stderr)
#   V61 slot-retry-count is recorded, never a gate
#   V62 getvar answer policy (required / optional / accepted-absent) is present
#   V63 T-1.3 detects unexpected change (slot state, build, release)
#   V64 no generic RAM-boots-leave-flash-untouched sentence
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
boot_lines="$(grep -E 'fastboot boot' "$PROTO" || true)"
if grep -qiE 'UNKNOWN' <<<"$boot_lines"; then
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
# the string verification recipe must stay complete: image hash + file offset per key string
grep -qF '017da2dac658cbce05081974590ad86ab2f75b6f07b28b0dbe06fb7386e92635' "$SAFETY" \
  || fail 14 "$SAFETY lost the audited lk_b.img sha256 of the string verification recipe"
for o in '@659832' '@659396' '@657924' '@650996'; do
  grep -qF "$o" "$SAFETY" \
    || fail 14 "$SAFETY lost the string verification recipe offset $o"
done
ok 14 "SAFETY string verification recipe complete (image sha256 + 4 file offsets)"
if grep -qF 'INFERRED (other device)' "$PROTO" || grep -qF 'RE1_opencode_flash.md' "$PROTO"; then
  ok 14 "protocol labels LK check order (INFERRED other-device, or cites RE1 disassembly)"
else
  fail 14 "$PROTO states LK check order with neither INFERRED (other device) nor RE1 evidence"
fi
note 14 "the semantic truth (string really in lk_b.img) still needs the retained binary, but the recipe (image sha256 + 4 file offsets, greppable with grep -boa -F) is checked above; the quoted strings were grepped against /tmp/lk_b_strings.txt during the FIX7 review"

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
  grep -qi 'Z0 PASS' <<<"$t1" \
    && ok 18 "T-1 is gated on Z0 PASS" \
    || fail 18 "T-1 is not gated on Z0 PASS"
  grep -qiE "owner.*yes" <<<"$t1" \
    && ok 18 "T-1 requires the owner's explicit yes" \
    || fail 18 "T-1 lacks the owner-yes gate"
  grep -q 'sha256sum' <<<"$t1" \
    && ok 18 "T-1 verifies the backup hash before writing" \
    || fail 18 "T-1 lacks the backup hash check"
  grep -qi 'identical' <<<"$t1" \
    && ok 18 "T-1 writes identical content only" \
    || fail 18 "T-1 does not state identical content"
  grep -q 'flash boot_b' <<<"$t1" \
    && grep -q 'backup' <<<"$t1" \
    && ok 18 "T-1 names the backup-image flash command" \
    || fail 18 "T-1 does not name the backup-image flash command"
fi
# stale single-write sentences (README says two, protocol must not claim one)
for s in 'one and only write command' 'one protected write' 'single write' 'single-write'; do
  grep -qiF "$s" <<<"$t1" \
    && fail 18 "T-1 claims a single write: $s" \
    || true
done
# README must affirm two writes
grep -qF 'two protected writes of `boot_b` (T-1 backup, T3 kernel)' README.md \
  && ok 18 "README affirms two protected writes (T-1 backup, T3 kernel)" \
  || fail 18 "README lost the two-writes count"

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
# V21 — Z0 runs a CLOSED getvar allowlist; 'getvar all' and any 'oem' are forbidden there
# ------------------------------------------------------------------------------------------------
z0="$(sed -n '/^### Z0/,/^### T-1/p' "$PROTO")"
if [ -z "$z0" ]; then
  fail 21 "$PROTO lost the Z0 section the allowlist lives in"
else
  # 1. All 15 required names present
  for v in product current-slot slot-count is-userspace unlocked max-download-size \
      partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a \
      slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage; do
    grep -qF "getvar $v" <<<"$z0" \
      && ok 21 "Z0 allowlist contains getvar $v" \
      || fail 21 "Z0 allowlist lost getvar $v"
  done
  # 1b. Exact multiset (item 24): the 15 fenced Z0.3 lines, sorted, must equal the
  # allowlist exactly — catches duplicates that presence checks miss.
  z0fenced="$(grep -E '^  `tools/fastboot_guard.sh getvar [^`]+`$' <<<"$z0" | sort || true)"
  expected21="$(printf '%s\n' product current-slot slot-count is-userspace unlocked max-download-size partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage | sed 's|^|  `tools/fastboot_guard.sh getvar |;s|$|`|' | sort)"
  if [ "$z0fenced" = "$expected21" ]; then
    ok 21 "Z0.3 fenced lines match the 15-name allowlist exactly (no dupes, no extras)"
  else
    fail 21 "Z0.3 fenced lines differ from the 15-name allowlist: $(printf '%s' "$z0fenced" | head -1 | cut -c1-100)"
  fi
  # 2. No EXTRA getvar lines in Z0.3 (closed allowlist)
  extra="$(printf '%s\n' "$z0" | grep -E '^  `tools/fastboot_guard.sh getvar [^`]+`$' | grep -vE 'getvar (product|current-slot|slot-count|is-userspace|unlocked|max-download-size|partition-size:boot_b|slot-successful:a|slot-successful:b|slot-unbootable:a|slot-unbootable:b|slot-retry-count:a|slot-retry-count:b|battery-soc-ok|battery-voltage)' || true)"
  if [ -n "$extra" ]; then
    fail 21 "Z0.3 has extra getvar outside the 15-name allowlist: $(printf '%s' "$extra" | head -1)"
  else
    ok 21 "Z0.3 has no extra getvar beyond the 15-name closed allowlist"
  fi
  # 3. Forbidden: getvar all + any oem
  grep -q 'getvar all' <<<"$z0" \
    && grep -qiE 'forbidden|PROIBIDO|outside this list' <<<"$z0" \
    && ok 21 "Z0 forbids 'getvar all'" \
    || fail 21 "Z0 does not forbid 'getvar all'"
  grep -q 'oem allow-wipe-userdata' <<<"$z0" \
    && ok 21 "Z0 names the oem wipe permission it refuses to touch" \
    || fail 21 "Z0 lost the 'oem allow-wipe-userdata' warning"
fi

# ------------------------------------------------------------------------------------------------
# V22 — Z0 PASS is powered-off key entry; adb reboot is documentary only
# ------------------------------------------------------------------------------------------------
# Require the EXACT phrase "key-reached fastboot" + "Vol− + Power" in Z0.1/Z0.2
grep -qF 'key-reached fastboot' <<<"$z0" \
  && grep -qF 'Vol− + Power' <<<"$z0" \
  && ok 22 "Z0 PASS requires key-reached fastboot with Vol− + Power" \
  || fail 22 "Z0 PASS missing 'key-reached fastboot' + 'Vol− + Power' in Z0.1/Z0.2"
grep -qF 'Z0.0 (optional' <<<"$z0" \
  && ok 22 "adb reboot bootloader is marked optional/documentary (Z0.0)" \
  || fail 22 "adb reboot bootloader is not marked optional (Z0.0)"

# ------------------------------------------------------------------------------------------------
# V23 — slot != b means power off by keys, never 'fastboot reboot'
# ------------------------------------------------------------------------------------------------
grep -qF 'never `fastboot reboot`' <<<"$z0" \
  && ok 23 "slot != b means power off by keys, never 'fastboot reboot'" \
  || fail 23 "Z0 lost the slot!=b power-off rule"

# ------------------------------------------------------------------------------------------------
# V24 — charger disconnected during Z0
# ------------------------------------------------------------------------------------------------
grep -qi 'charger disconnected' <<<"$z0" \
  && ok 24 "Z0 requires the charger disconnected" \
  || fail 24 "Z0 lost the charger-disconnected requirement"

# ------------------------------------------------------------------------------------------------
# V25 — 3-min no-adb procedure ends the day on second failure, no USB improvisation
# ------------------------------------------------------------------------------------------------
grep -q '3 min' <<<"$z0" \
  && grep -q 'second failure ends the day' <<<"$z0" \
  && grep -q 'no USB improvisation' <<<"$z0" \
  && ok 25 "Z0 no-adb procedure: 3 min, keys once, second failure ends the day" \
  || fail 25 "Z0 lost the no-adb procedure"

# ------------------------------------------------------------------------------------------------
# V26 — day baseline is the criterion; '429 modules' is example only (RUNBOOK A9 / B48)
# ------------------------------------------------------------------------------------------------
line=$(printf '%s\n' "$z0" | grep -E '429' | head -1)
grep -qF 'example only' <<<"$line" \
  && grep -qF 'your number is your baseline' <<<"$line" \
  && ok 26 "day baseline is the criterion; 429 modules is example only" \
  || fail 26 "429 line lost 'example only' / 'your number is your baseline' (baseline must stay the criterion)"


# ------------------------------------------------------------------------------------------------
# V27 — the honest list of what Z0 does not prove is present
# ------------------------------------------------------------------------------------------------
grep -qi 'does not prove' <<<"$z0" \
  && grep -q 'UNVERIFIED' <<<"$z0" \
  && ok 27 "Z0 carries the honest list of what it does not prove" \
  || fail 27 "Z0 lost the honest list of what it does not prove"

# ------------------------------------------------------------------------------------------------
# V28 — every tools/*.sh and scripts/*.sh is executable (index 100755 and on-disk +x)
# ------------------------------------------------------------------------------------------------
bad28=""
for f in tools/*.sh scripts/*.sh; do
  [ -x "$f" ] || bad28="$bad28 $f"
done
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  idxbad="$(git ls-files -s tools/*.sh scripts/*.sh | awk '$1 != "100755" {print $4}')"
  [ -z "$idxbad" ] || bad28="$bad28(index:$idxbad)"
fi
if [ -z "$bad28" ]; then
  ok 28 "every tools/*.sh and scripts/*.sh is executable (index 100755, on-disk +x)"
else
  fail 28 "non-executable tools/*.sh or scripts/*.sh:$bad28"
fi

# ------------------------------------------------------------------------------------------------
# V29 — SAFETY table rows exactly match data/lk_tables.tsv (bidirectional, row-scoped)
# ------------------------------------------------------------------------------------------------
names29="$(awk '!/^#/ && NF {print $2}' data/lk_tables.tsv)"
[ "$(printf '%s\n' "$names29" | wc -l)" -eq 14 ] \
  && ok 29 "data/lk_tables.tsv lists 14 table names" \
  || fail 29 "data/lk_tables.tsv does not list 14 names"

# Build expected sets from TSV
controlled_expected="$(awk -F'\t' '$3=="controlled" {print $2}' data/lk_tables.tsv | sort)"
eraseforbid_expected="$(awk -F'\t' '$3=="erase-forbidden" {print $2}' data/lk_tables.tsv | sort)"

# Row-scoped: each name must sit on the line of its own table address
controlled29="$(grep -F '0x4c4bf8b0' "$SAFETY")"
eraseforbid29="$(grep -F '0x4c4bf8cc' "$SAFETY")"

# Extract names from SAFETY table rows
controlled29_names="$(printf '%s\n' "$controlled29" | sed -E 's/.*controlled table at `[^`]+`[^:]*: //; s/;.*//' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort)"
eraseforbid29_names="$(printf '%s\n' "$eraseforbid29" | sed -E 's/.*erase-forbidden table at `[^`]+`://; s/\(.*//' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | sort)"

# Bidirectional: SAFETY row must match TSV exactly (no extra, no missing)
for n in $controlled_expected; do
  grep -qwF "$n" <<<"$controlled29_names" \
    && ok 29 "controlled-table row has $n" \
    || fail 29 "controlled-table row missing expected name: $n"
done
for n in $controlled29_names; do
  grep -qwF "$n" <<<"$controlled_expected" \
    && ok 29 "controlled-table row has no extra: $n" \
    || fail 29 "controlled-table row has unexpected name: $n"
done
for n in $eraseforbid_expected; do
  grep -qwF "$n" <<<"$eraseforbid29_names" \
    && ok 29 "erase-forbidden row has $n" \
    || fail 29 "erase-forbidden row missing expected name: $n"
done
for n in $eraseforbid29_names; do
  grep -qwF "$n" <<<"$eraseforbid_expected" \
    && ok 29 "erase-forbidden row has no extra: $n" \
    || fail 29 "erase-forbidden row has unexpected name: $n"
done

# Unprotected names still checked
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
# Stricter: line must FORBID it (contain forbid/PROIBIDO/never/not run/allowlist/instead)
# and NOT be an executable ordering (e.g., "run getvar all")
hits30="$(grep -rn 'getvar all' README.md docs/*.md 2>/dev/null || true)"
bad30="$(printf '%s\n' "$hits30" | grep -viE 'forbid|PROIBIDO|never run|not run|allowlist|instead' || true)"
# Also reject lines that say "run getvar all" or "execute getvar all" even if they have allowlist
executable30="$(printf '%s\n' "$hits30" | grep -iE 'run.*getvar all|execute.*getvar all' || true)"
if [ -z "$bad30" ] && [ -z "$executable30" ]; then
  ok 30 "no executable 'getvar all' outside docs/research/"
else
  if [ -n "$bad30" ]; then
    fail 30 "executable 'getvar all': $(printf '%s' "$bad30" | head -1 | cut -c1-120)"
  fi
  if [ -n "$executable30" ]; then
    fail 30 "executable 'getvar all' despite allowlist mention: $(printf '%s' "$executable30" | head -1 | cut -c1-120)"
  fi
fi

# ------------------------------------------------------------------------------------------------
# V31 — wrapper flash lines == README number (2), target always boot_b
# ------------------------------------------------------------------------------------------------
# Only real commands inside ``` fenced code blocks count (item 23); table-cell
# mentions and prose are references, not commands. (No pipe into grep -q: V54.)
flines31="$(awk '/^```/{f=!f} f && /^tools\/fastboot_guard.sh flash/' "$PROTO" || true)"
nflash="$(printf '%s\n' "$flines31" | grep -c . || true)"
[ "$nflash" -eq 2 ] \
  && ok 31 "protocol has exactly 2 wrapper flash lines (T-1, T3)" \
  || fail 31 "protocol has $nflash wrapper flash lines, README affirms 2"
grep -qv 'flash boot_b' <<<"$flines31" \
  && fail 31 "a wrapper flash targets something other than boot_b" \
  || ok 31 "every wrapper flash targets boot_b"
grep -qF 'two protected writes of `boot_b` (T-1 backup, T3 kernel)' README.md \
  && ok 31 "README affirms two protected writes (T-1 backup, T3 kernel)" \
  || fail 31 "README lost the two-writes count"
grep -qF 'tools/fastboot_guard.sh flash boot_b <path/to/backup/boot_b.img>' "$PROTO" \
  && ok 31 "T-1 block line keeps the wrapper form" \
  || fail 31 "T-1 block line lost the wrapper form"

# ------------------------------------------------------------------------------------------------
# V32 — T-1 comes after R3 (it depends on R3)
# ------------------------------------------------------------------------------------------------
t1line="$(grep -n '^### T-1' "$PROTO" | head -1 | cut -d: -f1)"
r3line="$(grep -n '^### R3' "$PROTO" | head -1 | cut -d: -f1)"
[ -n "$t1line" ] && [ -n "$r3line" ] && [ "$t1line" -gt "$r3line" ] \
  && ok 32 "T-1 section (line $t1line) comes after R3 (line $r3line)" \
  || fail 32 "T-1 is not after R3 (t1=$t1line r3=$r3line)"

# ------------------------------------------------------------------------------------------------
# V33 — research notes carry no machine paths, identifiers or secret shapes
# (README documents the redaction). Item 27: ~/ and $HOME (username leaks via
# expansion), /var/tmp, /Users/, 15-digit runs (IMEI-shaped), secret shapes
# (tokens, private keys). Herestring form (V54-safe); bare usernames stay manual
# review (too fuzzy to grep without false positives).
bad33="$(grep -rn -E '/tmp/|/home/|~/|\$HOME|/var/tmp|/Users/|[0-9]{15}|ghp_|gho_|github_pat_|glpat-|AKIA|sk_live|xox[bpas]-|BEGIN .*PRIVATE KEY' docs/research/*.md 2>/dev/null | grep -v 'docs/research/README.md' || true)"
if [ -z "$bad33" ]; then
  ok 33 "no machine paths, identifiers or secret shapes in docs/research/ notes"
else
  fail 33 "machine paths in notes: $(printf '%s' "$bad33" | head -1 | cut -c1-120)"
fi

# ------------------------------------------------------------------------------------------------
# V34 — the never-touch set covers all unprotected-but-critical partitions, in both docs
# ------------------------------------------------------------------------------------------------
rule1="$(grep -F 'Never touch' "$SAFETY" | head -1)"
never="$(grep -A6 'NEVER type' "$PROTO")"
for n in preloader lk seccfg nvram nvdata nvcfg persist proinfo protect1 protect2 misc boot_para expdb; do
  grep -qwF "$n" <<<"$rule1" \
    && ok 34 "never-touch rule lists $n" \
    || fail 34 "never-touch rule lost: $n"
  grep -qwF "$n" <<<"$never" \
    && ok 34 "protocol NEVER list covers $n" \
    || fail 34 "protocol NEVER list lost: $n"
done

# ------------------------------------------------------------------------------------------------
# V35 — Z0 section header states mandatory Z0 writes nothing; Z0.0 writes only boot reason
# ------------------------------------------------------------------------------------------------
z0="$(sed -n '/^### Z0/,/^### T-1/p' "$PROTO")"
grep -qF 'mandatory Z0 (Z0.1' <<<"$z0" \
  && grep -qF 'writes nothing' <<<"$z0" \
  && grep -qF 'Z0.0 (optional' <<<"$z0" \
  && grep -qF 'writes only the Android boot reason' <<<"$z0" \
  && ok 35 "Z0 header states mandatory Z0 writes nothing; Z0.0 writes only boot reason" \
  || fail 35 "Z0 header missing mandatory/optional distinction or boot reason clarification"

# ------------------------------------------------------------------------------------------------
# V36 — SAFETY.md states two protected writes: T-1 backup and T3 kernel
# ------------------------------------------------------------------------------------------------
grep -qF 'two protected writes' "$SAFETY" \
  && grep -qF 'T-1' "$SAFETY" \
  && grep -qF 'T3' "$SAFETY" \
  && ok 36 "SAFETY states two protected writes (T-1 backup, T3 kernel)" \
  || fail 36 "SAFETY lost the two-writes statement"

# ------------------------------------------------------------------------------------------------
# V37 — V2 extended to all docs outside docs/research/
# ------------------------------------------------------------------------------------------------
# (enforced in check_regex_controls.sh, which emits V37 FAIL/OK; run_all_checks.sh reads
# RC[V37] from that script's output — this note only documents the split)
note 37 "V37: regex controls extended to README/SAFETY/BUILD/KMI-GATES/PROTOCOL in check_regex_controls.sh (V37 FAIL/OK signal there)"

# ------------------------------------------------------------------------------------------------
# V38 — Z0 allowlist is CLOSED: no extra getvar, no oem
# ------------------------------------------------------------------------------------------------
# Already checked in V21; confirm no extra getvar in Z0.3
z0="$(sed -n '/^### Z0/,/^### T-1/p' "$PROTO")"
extra="$(printf '%s\n' "$z0" | grep -E '^  `tools/fastboot_guard.sh getvar [^`]+`$' | grep -vE 'getvar (product|current-slot|slot-count|is-userspace|unlocked|max-download-size|partition-size:boot_b|slot-successful:a|slot-successful:b|slot-unbootable:a|slot-unbootable:b|slot-retry-count:a|slot-retry-count:b|battery-soc-ok|battery-voltage)' || true)"
if [ -n "$extra" ]; then
  fail 38 "Z0.3 has extra getvar outside the 15-name allowlist: $(printf '%s' "$extra" | head -1)"
else
  ok 38 "Z0.3 has no extra getvar beyond the 15-name closed allowlist"
fi

# ------------------------------------------------------------------------------------------------
# V39 — No stale single-write sentence; README affirms two writes; no stale suite ranges
# ------------------------------------------------------------------------------------------------
for s in 'one and only write command' 'one protected write' 'single write' 'single-write'; do
  grep -riF "$s" README.md "$PROTO" "$SAFETY" 2>/dev/null | grep -v 'two protected writes' \
    && fail 39 "Stale single-write sentence found: $s" \
    || true
done
# Stale suite descriptions (fixed ranges from older rounds; README must stay range-free)
for s in 'V1–V9' 'V14–V17' '14 sabotage' 'V1..V9'; do
  grep -rF "$s" README.md 2>/dev/null \
    && fail 39 "Stale suite description in README: $s" \
    || true
done
grep -qF 'two protected writes of `boot_b` (T-1 backup, T3 kernel)' README.md \
  && ok 39 "No stale single-write sentence; README affirms two protected writes" \
  || fail 39 "README lost the two-writes count"

# ------------------------------------------------------------------------------------------------
# V40 — V22/V26 require exact phrase/line (not loose tokens)
# ------------------------------------------------------------------------------------------------
# V22 already checks for exact "key-reached fastboot" + "Vol− + Power" (done in V22)
# V26 already checks for "429" line with "reference" + "baseline.*criterion" (done in V26)
# V40's own signal: SPEC.md's V40 row must name the same exact phrase V22 enforces.
# (Row matched by id, never by hard-coded line number — line numbers shift on every edit.
#  Single awk, no grep -E pipe: the V2 `\|` ban and the V54 pipe-into-grep -q ban both apply.)
awk '/^\| V40 \|/ && /key-reached fastboot/ {found=1} END {exit !found}' SPEC.md \
  && ok 40 "SPEC V40 names the exact phrase V22 enforces (key-reached fastboot)" \
  || fail 40 "SPEC V40 does not name the exact phrase V22 enforces (key-reached fastboot)"

# ------------------------------------------------------------------------------------------------
# V41 — docs/research/README.md has "contain errors" warning + UNVERIFIED table
# ------------------------------------------------------------------------------------------------
grep -qE '\*\*They contain errors\.\*\*' docs/research/README.md \
  && grep -qE 'UNVERIFIED' docs/research/README.md \
  && ok 41 "docs/research/README.md has 'contain errors' warning and UNVERIFIED table" \
  || fail 41 "docs/research/README.md missing 'contain errors' warning or UNVERIFIED table"

# ------------------------------------------------------------------------------------------------
# V42 — V30 stricter: getvar all line must FORBID, not just mention allowlist
# ------------------------------------------------------------------------------------------------
# (Already enforced in V30 with stricter filter)
ok 42 "V41: V30 stricter filter enforced in V30"

# ------------------------------------------------------------------------------------------------
# V43 — Z0.4 exception states rollback index 0 means LK CAN boot old slot A
# ------------------------------------------------------------------------------------------------
grep -qF 'rollback index 0' "$PROTO" \
  && grep -qF 'can boot old slot A' "$PROTO" \
  && grep -qF 'do not boot' "$PROTO" \
  && ok 43 "Z0.4 exception states rollback index 0 means LK can boot old slot A" \
  || fail 43 "Z0.4 exception missing rollback index 0 / LK can boot old slot A"

# ------------------------------------------------------------------------------------------------
# V44 — is-userspace text states string EXISTS in LK getvar table
# ------------------------------------------------------------------------------------------------
grep -qF 'string `is-userspace` **exists**' "$PROTO" \
  && ok 44 "is-userspace text states string exists in LK getvar table" \
  || fail 44 "is-userspace text missing 'string exists in LK getvar table'"

# ------------------------------------------------------------------------------------------------
# V45 — Protocol cites RE1 for check-before-write order + inline r2 reproducer
# ------------------------------------------------------------------------------------------------
grep -qF '0x4c4367d2' "$PROTO" \
  && grep -qF '0x4c436834' "$PROTO" \
  && grep -qF 'RE1_opencode_flash.md' "$PROTO" \
  && grep -qF 'r2 -a arm -b 16 -m 0x4c3ffe00' "$PROTO" \
  && ok 45 "Protocol cites RE1 disassembly for check-before-write order (0x4c4367d2 precedes 0x4c436834) with inline r2 reproducer" \
  || fail 45 "Protocol missing RE1 citation or inline r2 reproducer for check-before-write order"

# ------------------------------------------------------------------------------------------------
# V46 — T-1.2 names the backup command (indirect ref to the two-write block, V31
# dedup); T2b lists six getvar commands inline
# ------------------------------------------------------------------------------------------------
t12="$(grep '^| T-1.2 |' "$PROTO" || true)"
grep -qF 'tools/fastboot_guard.sh flash boot_b <path/to/backup/boot_b.img>' <<<"$t12" \
  && ok 46 "T-1.2 names the wrapper backup-image flash command" \
  || fail 46 "T-1.2 missing the wrapper backup-image flash command"
grep -qF 'slot-successful:a' "$PROTO" \
  && grep -qF 'slot-successful:b' "$PROTO" \
  && grep -qF 'slot-retry-count:a' "$PROTO" \
  && grep -qF 'slot-retry-count:b' "$PROTO" \
  && grep -qF 'slot-unbootable:a' "$PROTO" \
  && grep -qF 'slot-unbootable:b' "$PROTO" \
  && ok 46 "T2b lists six exact getvar commands inline" \
  || fail 46 "T2b missing inline getvar commands"

# ------------------------------------------------------------------------------------------------
# V47 — all fastboot goes through the exact-allowlist wrapper; no `command fastboot`
# ------------------------------------------------------------------------------------------------
bad47="$(grep -rnF 'command fastboot' README.md "$PROTO" "$SAFETY" docs/BUILD.md docs/KMI-GATES.md 2>/dev/null || true)"
if [ -z "$bad47" ]; then
  ok 47 "no 'command fastboot' instruction in device-facing docs (wrapper-only)"
else
  fail 47 "bare 'command fastboot' instruction: $(printf '%s' "$bad47" | head -1 | cut -c1-120)"
fi
grep -qF 'BLOQUEADO pelo fastboot_guard' "$PROTO" \
  && grep -qF 'tools/fastboot_guard.sh flash boot_b <path/to/backup/boot_b.img>' "$PROTO" \
  && grep -qF 'tools/fastboot_guard.sh flash boot_b boot_b_new.img' "$PROTO" \
  && ok 47 "protocol documents the wrapper refusal + exactly the two gated flashes" \
  || fail 47 "protocol lost the wrapper refusal or the two gated flashes"
grep -qF '`tools/fastboot_guard.sh flash boot_b <backup boot_b.img>`' "$SAFETY" \
  && ok 47 "SAFETY recovery path uses the wrapper form" \
  || fail 47 "SAFETY recovery path lost the wrapper form"

# ------------------------------------------------------------------------------------------------
# V48 — protect2 before protect1 in all device-facing docs
# ------------------------------------------------------------------------------------------------
for f in "$PROTO" "$SAFETY" README.md; do
  # Find the line with protect1/protect2 and check order
  if grep -qF 'protect1' "$f" && grep -qF 'protect2' "$f"; then
    pos1=$(grep -b -o 'protect1' "$f" | head -1 | cut -d: -f1)
    pos2=$(grep -b -o 'protect2' "$f" | head -1 | cut -d: -f1)
    if [ "$pos1" -lt "$pos2" ]; then
      fail 48 "$f: protect1 appears before protect2 (measured order is protect2 then protect1)"
    fi
  fi
done
ok 48 "protect2 appears before protect1 in all device-facing docs"

# ------------------------------------------------------------------------------------------------
# V49 — Baseline modules text says "429 modules (example only); your number is your baseline"
# ------------------------------------------------------------------------------------------------
grep -qF '429 modules (example only)' "$PROTO" \
  && grep -qF 'your number is your baseline' "$PROTO" \
  && ok 49 "Baseline modules text says 429 (example only); your number is your baseline" \
  || fail 49 "Baseline modules text missing 'example only' or 'your number is your baseline'"

# ------------------------------------------------------------------------------------------------
# V50 — Protocol states when/how to read pstore: next normal boot on good kernel
# ------------------------------------------------------------------------------------------------
grep -qF 'next normal boot' "$PROTO" \
  && grep -qF 'on a good kernel' "$PROTO" \
  && ok 50 "Protocol states when/how to read pstore: next normal boot on good kernel" \
  || fail 50 "Protocol missing pstore reading guidance (next normal boot on good kernel)"

# ------------------------------------------------------------------------------------------------
# V51 — SAFETY.md "Never touch" list states it's project policy, wider than LK tables
# ------------------------------------------------------------------------------------------------
grep -qF 'project policy' "$SAFETY" \
  && grep -qF 'wider than' "$SAFETY" \
  && ok 51 "SAFETY.md Never touch list states it is project policy, wider than LK tables" \
  || fail 51 "SAFETY.md Never touch list missing project policy / wider than LK tables"

# ------------------------------------------------------------------------------------------------
# V52 — Slot firmware comparison "accept in writing" = type specific phrase
# ------------------------------------------------------------------------------------------------
grep -qF 'I accept that slot A is older firmware OS3.0.20.0 and fallback would boot old OS over new data' "$PROTO" \
  && ok 52 "Slot firmware comparison accept in writing = type specific phrase" \
  || fail 52 "Slot firmware comparison accept in writing missing specific phrase"

# ------------------------------------------------------------------------------------------------
# V53 — Abort criteria table includes L1-L6 lacunae
# ------------------------------------------------------------------------------------------------
grep -qF 'L1' "$PROTO" && grep -qF 'L2' "$PROTO" && grep -qF 'L3' "$PROTO" \
  && grep -qF 'L4' "$PROTO" && grep -qF 'L5' "$PROTO" && grep -qF 'L6' "$PROTO" \
  && ok 53 "Abort criteria table includes L1-L6 lacunae" \
  || fail 53 "Abort criteria table missing L1-L6 lacunae"

# ------------------------------------------------------------------------------------------------
# V8 — every fact row has a proof; the raw notes carry the warning
# ------------------------------------------------------------------------------------------------
# NB: [|] rather than \| — in ERE an escaped pipe is a literal pipe anyway, and this file's own
# V2 rule rejects the confusing form.
rows="$(grep -cE '^[|] *[0-9]+ *[|]' docs/PLAN-AND-FINDINGS.pt-BR.md)"
if [ "$rows" -lt 10 ]; then
  fail 8 "facts log has only $rows data rows (minimum 10)"
else
  ok 8 "$rows fact rows present (>= 10)"
fi
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
# device-dump citations must carry their verification boundary: a proof cell naming
# audit/<...> or backup-2026-10-05/<...> (retained dumps, not in this repo) is ⊥ unless the
# same cell says "retained" or "not published".
python3 - <<'PY'
import re, sys
bad = 0
for i, line in enumerate(open('docs/PLAN-AND-FINDINGS.pt-BR.md'), 1):
    if not re.match(r'^\| *[0-9]+ *\|', line):
        continue
    cells = line.split('|')
    if len(cells) < 6:
        continue
    proof = cells[4]
    if re.search(r'(?:audit/|backup-2026-10-05/)', proof) and not re.search(r'retained|not published', proof):
        bad += 1
        print(f'V8 FAIL docs/PLAN-AND-FINDINGS.pt-BR.md:{i} prova cita dump retido sem fronteira de verificação: {proof.strip()[:100]}')
if bad == 0:
    print('V8 OK every device-dump proof citation carries its verification boundary (retained/not published)')
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fail 8 "proof column cites a retained dump without its verification boundary"
note 8 "that each individual FACT sentence in the raw notes has a source is NOT automatable (free prose); the proof column of the facts log is the enforced landing place"

# ------------------------------------------------------------------------------------------------
# V56 — on-device observation commands carry `adb shell` (bare uname/dmesg would read the host)
# ------------------------------------------------------------------------------------------------
for cmd in 'adb shell uname -r' "adb shell 'cat /proc/modules'" 'adb shell dmesg > baseline_dmesg.txt' 'adb shell ls -l /sys/fs/pstore'; do
  grep -qF "$cmd" "$PROTO" \
    && ok 56 "protocol runs on-device observation via: $cmd" \
    || fail 56 "protocol lost on-device form: $cmd (bare command would read the host)"
done

# ------------------------------------------------------------------------------------------------
# V55 — PROTO:NN / SAFETY:NN cross-references resolve to existing lines
# ------------------------------------------------------------------------------------------------
python3 - "$PROTO" "$SAFETY" <<'PY'
import re, sys
proto_lines = open(sys.argv[1]).read().splitlines()
safety_lines = open(sys.argv[2]).read().splitlines()
bad = 0
for path, lines, other, olines in ((sys.argv[1], proto_lines, 'SAFETY', safety_lines),
                                   (sys.argv[2], safety_lines, 'SAFETY', safety_lines)):
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r'PROTO:(\d+)', line):
            n = int(m.group(1))
            if not 1 <= n <= len(proto_lines):
                bad += 1
                print(f'V55 FAIL {path}:{i} dangling PROTO:{n} (protocol has {len(proto_lines)} lines)')
        for m in re.finditer(r'SAFETY:(\d+)', line):
            n = int(m.group(1))
            if not 1 <= n <= len(safety_lines):
                bad += 1
                print(f'V55 FAIL {path}:{i} dangling SAFETY:{n} (SAFETY.md has {len(safety_lines)} lines)')
if bad == 0:
    print('V55 OK every PROTO:NN/SAFETY:NN cross-reference resolves to an existing line')
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fails=$((fails + 1))
note 55 "existence only: whether the cited line is TOPICALLY related stays a human review (this round: userdata = SAFETY:8, verified by reading)"

# ------------------------------------------------------------------------------------------------
# V57 — Residual risks table R1-R4 with mitigation + status is present
# ------------------------------------------------------------------------------------------------
for r in R1 R2 R3 R4; do
  grep -qF "| $r |" "$PROTO" \
    || fail 57 "protocol lost the residual risks table row $r (mitigation + status)"
done
grep -qF '### Residual risks' "$PROTO" \
  && ok 57 "protocol carries the consolidated residual risks table (R1-R4 with mitigation + status)" \
  || fail 57 "protocol lost the consolidated residual risks table"

# ------------------------------------------------------------------------------------------------
# V58 — fastboot_guard.sh carries the exact allowlist + write gates
# ------------------------------------------------------------------------------------------------
GUARD="tools/fastboot_guard.sh"
[ -f "$GUARD" ] || fail 58 "tools/fastboot_guard.sh missing"
grep -qF 'devices|reboot)' "$GUARD" \
  && ok 58 "guard allowlist keeps devices + reboot" \
  || fail 58 "guard allowlist lost devices/reboot"
for v in product current-slot slot-count is-userspace unlocked max-download-size \
    partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a \
    slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage; do
  grep -qF "$v" "$GUARD" \
    && ok 58 "guard allowlist keeps getvar $v" \
    || fail 58 "guard allowlist lost getvar $v"
done
for g in '67108864' 'ANDROID!' 'FASTBOOT_GUARD_HASHES' 'flash boot_b'; do
  grep -qF "$g" "$GUARD" \
    && ok 58 "guard write gate keeps: $g" \
    || fail 58 "guard lost write gate: $g"
done

# ------------------------------------------------------------------------------------------------
# V59 — protocol orders fastboot ONLY through the guard (no bare/command instruction)
# ------------------------------------------------------------------------------------------------
# Instruction shapes: a fenced command at line start, or `run`/`rode` + command.
# Prose mentions (symptom labels, LK table, rollback notes) are not instructions.
bad59="$(grep -nE '^\s*`(command )?fastboot (devices|reboot|getvar|flash|erase|format|oem|flashing|set_active)|run `fastboot (devices|reboot|getvar|flash|erase|format|oem)|rode `fastboot (devices|reboot|getvar|flash|erase|format|oem)' "$PROTO" "$SAFETY" 2>/dev/null || true)"
if [ -z "$bad59" ]; then
  ok 59 "no bare/command fastboot instruction in protocol/SAFETY (wrapper-only)"
else
  fail 59 "bare/command fastboot instruction: $(printf '%s' "$bad59" | head -1 | cut -c1-120)"
fi
grep -qF 'tools/fastboot_guard.sh' "$PROTO" \
  && ok 59 "protocol routes fastboot through tools/fastboot_guard.sh" \
  || fail 59 "protocol lost the wrapper route"

# ------------------------------------------------------------------------------------------------
# V60 — fastboot captures merge stderr (fastboot answers on stderr)
# ------------------------------------------------------------------------------------------------
for anchor in '2>&1 | tee z0_fastboot_before.txt' '2>&1 | tee t2b_readout.txt' 'fastboot answers on stderr'; do
  grep -qF "$anchor" "$PROTO" \
    && ok 60 "protocol captures stderr via: $anchor" \
    || fail 60 "protocol lost stderr capture: $anchor"
done

# ------------------------------------------------------------------------------------------------
# V61 — slot-retry-count is recorded, never a gate
# ------------------------------------------------------------------------------------------------
grep -qiF 'informational only' "$PROTO" \
  && grep -qiF 'retry-count:b' "$PROTO" \
  && ok 61 "retry-count:b is informational only (0 legitimate)" \
  || fail 61 "retry-count:b informational wording lost"
grep -qF 'slot-successful:b` shows `yes' "$PROTO" \
  && grep -qF 'slot-unbootable:b` shows `no' "$PROTO" \
  && ok 61 "gate is successful:b=yes AND unbootable:b=no" \
  || fail 61 "successful/unbootable gate wording lost"

# ------------------------------------------------------------------------------------------------
# V62 — getvar answer policy (required / optional / accepted-absent) is present
# ------------------------------------------------------------------------------------------------
grep -qF 'Getvar answer policy' "$PROTO" \
  && grep -qF 'accepted-absent' "$PROTO" \
  && grep -qF 'required' "$PROTO" \
  && ok 62 "protocol carries the required/optional/accepted-absent getvar policy" \
  || fail 62 "protocol lost the getvar answer policy"

# ------------------------------------------------------------------------------------------------
# V63 — T-1.3 detects unexpected change (slot state, build, release)
# ------------------------------------------------------------------------------------------------
t13="$(sed -n '/^| T-1.3/,/ |$/p' "$PROTO")"
grep -qF 'slot-successful:b' <<<"$t13" \
  && grep -qF 'slot-unbootable:b' <<<"$t13" \
  && grep -qF 'adb shell uname -r' <<<"$t13" \
  && grep -qF 'adb shell getprop ro.build.version.incremental' <<<"$t13" \
  && ok 63 "T-1.3 re-checks slot state, build line and kernel release" \
  || fail 63 "T-1.3 lost the change-detection criteria"

# ------------------------------------------------------------------------------------------------
# V64 — no generic RAM-boots-leave-flash-untouched sentence
# ------------------------------------------------------------------------------------------------
if grep -qiF 'RAM boots leave flash untouched' "$PROTO" \
  || grep -qiF 'RAM boots não tocam flash' "$PROTO"; then
  fail 64 "generic RAM-boots-leave-flash sentence back in protocol"
else
  ok 64 "no generic RAM sentence in protocol"
fi

if [ "$fails" -eq 0 ]; then
  echo "PASS protocol invariants (V3 V4 V5 V7 V8 V14 V15 V16 V17 V18 V19 V20 V21 V22 V23 V24 V25 V26 V27 V28 V29 V30 V31 V32 V33 V34 V35 V36 V37 V38 V39 V40 V41 V42 V43 V44 V45 V46 V47 V48 V49 V50 V51 V52 V53 V55 V56 V57 V58 V59 V60 V61 V62 V63 V64)"
  exit 0
fi
echo "FAIL $fails invariante(s) de protocolo"
exit 1
