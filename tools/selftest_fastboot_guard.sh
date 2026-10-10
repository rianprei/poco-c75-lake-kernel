#!/usr/bin/env bash
# selftest_fastboot_guard.sh — proves tools/fastboot_guard.sh enforces its exact
# allowlist using a FAKE fastboot earlier in PATH (never a real device).
# The stub records argv it receives; refusals must NEVER invoke the stub.
#
# usage: tools/selftest_fastboot_guard.sh   (read-only on the repo; exit 0 = all cases)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"
GUARD="$ROOT/tools/fastboot_guard.sh"

BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
STUBDIR="$BASE/stubbin"; mkdir -p "$STUBDIR"
STUBLOG="$BASE/stub.log"
cat > "$STUBDIR/fastboot" <<EOF
#!/usr/bin/env bash
# stub registra argv + (para o último arg, se arquivo) sha256 e modo: prova que o
# guard entregou a cópia verificada (U1), não o original.
last=""
for a in "\$@"; do last="\$a"; done
extra=""
if [ -f "\$last" ]; then
  extra=" sha=\$(sha256sum -- "\$last" | cut -d' ' -f1) mode=\$(stat -c%a -- "\$last")"
fi
printf '%s%s\n' "\$*""\$extra" >> "$STUBLOG"
if [ "\$1" = "getvar" ] && [ "\$2" = "current-slot" ]; then
  printf '%s\n' "\${FAKE_SLOT_LINE:-current-slot: b}" >&2
fi
if [ "\$1" = "getvar" ] && [ "\$2" = "is-userspace" ]; then
  printf '%s\n' "\${FAKE_USER_LINE:-is-userspace: no}" >&2
fi
if [ "\$1" = "getvar" ] && [ "\$2" = "partition-size:boot_b" ]; then
  printf '%s\n' "\${FAKE_PART_LINE:-partition-size:boot_b: 4000000}" >&2
fi
echo "FAKE-OKAY \$*"
exit 0
EOF
chmod +x "$STUBDIR/fastboot"
export PATH="$STUBDIR:$PATH"

# good files: ANDROID! magic + exact size; hashes file lists their sha256
GOODIMG="$BASE/good_boot_b.img"
BADHASH="$BASE/bad_boot_b.img"
SMALL="$BASE/small.img"
NOMAGIC="$BASE/nomagic.img"
python3 - "$GOODIMG" "$BADHASH" "$SMALL" "$NOMAGIC" <<'PY'
import sys
good, bad, small, nomagic = sys.argv[1:5]
open(good, 'wb').write(b'ANDROID!' + b'\0' * (67108864 - 8))
open(bad, 'wb').write(b'ANDROID!' + b'\1' * (67108864 - 8))
open(small, 'wb').write(b'ANDROID!' + b'\0' * 100)
open(nomagic, 'wb').write(b'NOTANDROID' + b'\0' * (67108864 - 10))
PY
HASHES="$BASE/allowed.sha256"
sha256sum "$GOODIMG" | cut -d' ' -f1 > "$HASHES"
export FASTBOOT_GUARD_HASHES="$HASHES"

pass=0; fail=0
# allowlisted: must run the stub (log grows) with exact argv
t_allow() { # <n> <label> <args...>
  local n="$1" label="$2"; shift 2
  local before after rc
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  "$GUARD" "$@" >/dev/null 2>&1; rc=$?
  after="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  printf '### [%s] %s\n' "$n" "$label"
  if [ "$rc" -eq 0 ] && [ "$after" -gt "$before" ]; then
    printf '    stub chamado, argv: %s\n  => OK\n\n' "$(tail -1 "$STUBLOG")"
    pass=$((pass + 1))
  else
    printf '    ESPERAVA stub chamado (rc=0); rc=%s log %s->%s\n  => FALHA\n\n' "$rc" "$before" "$after"
    fail=$((fail + 1))
  fi
}
# refused: stub must NOT run (log unchanged), exit 2
t_deny() { # <n> <label> <args...>
  local n="$1" label="$2"; shift 2
  local before after rc
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  "$GUARD" "$@" >/dev/null 2>&1; rc=$?
  after="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  printf '### [%s] %s\n' "$n" "$label"
  if [ "$rc" -ne 0 ] && [ "$after" -eq "$before" ]; then
    printf '    recusado (exit=%s), stub NÃO chamado\n  => OK\n\n' "$rc"
    pass=$((pass + 1))
  else
    printf '    ESPERAVA recusa sem stub; rc=%s log %s->%s\n  => FALHA\n\n' "$rc" "$before" "$after"
    fail=$((fail + 1))
  fi
}

: > "$STUBLOG"
t_allow 1 "devices passa" devices
t_allow 2 "reboot passa" reboot
for v in product current-slot slot-count is-userspace unlocked max-download-size \
    partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a \
    slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage; do
  t_allow "3-$v" "getvar $v passa" getvar "$v"
done
t_allow 4 "flash boot_b válido chama o stub" flash boot_b "$GOODIMG"

t_deny 5 "getvar all recusado" getvar all
t_deny 6 "getvar cpuid recusado" getvar cpuid
t_deny 7 "oem recusado" oem allow-wipe-userdata
t_deny 24 "oem unlock recusado" oem unlock
t_deny 25 "oem off-mode-charge recusado" oem off-mode-charge
t_deny 26 "update recusado" update
t_deny 8 "erase recusado" erase boot_b
t_deny 9 "format recusado" format boot_b
t_deny 10 "set_active recusado" set_active a
t_deny 11 "flashing recusado" flashing unlock
t_deny 12 "flash lk recusado" flash lk "$GOODIMG"
t_deny 13 "flash boot_a recusado" flash boot_a "$GOODIMG"
t_deny 14 "flash boot_b hash errado recusado" flash boot_b "$BADHASH"
t_deny 15 "flash boot_b tamanho errado recusado" flash boot_b "$SMALL"
t_deny 16 "flash boot_b sem ANDROID! recusado" flash boot_b "$NOMAGIC"
t_deny 17 "flash boot_b arquivo inexistente recusado" flash boot_b "$BASE/nope.img"
t_deny 18 "devices com arg extra recusado" devices extra
t_deny 19 "getvar sem nome recusado" getvar
t_deny 20 "sem args (uso) recusado"

# U1 TOCTOU: o stub deve receber a CÓPIA privada (mktemp, 0400), nunca o original
printf '### [21] flash usa cópia privada verificada (TOCTOU)\n'
GOODSUM="$(sha256sum "$GOODIMG" | cut -d' ' -f1)"
"$GUARD" flash boot_b "$GOODIMG" >/dev/null 2>&1
flashed="$(tail -1 "$STUBLOG" | awk '{print $3}')"
lastline="$(tail -1 "$STUBLOG")"
if [ -n "$flashed" ] && [ "$flashed" != "$GOODIMG" ] \
    && grep -qF "sha=$GOODSUM" <<<"$lastline" \
    && grep -qF "mode=400" <<<"$lastline" \
    && grep -q 'fastboot_guard\.' <<<"$flashed"; then
  printf '    stub recebeu cópia 0400 com hash permitido: %s\n  => OK\n\n' "$flashed"
  pass=$((pass + 1))
else
  printf '    ESPERAVA cópia privada 0400 com mesmo hash; stub recebeu: %s\n  => FALHA\n\n' "$lastline"
  fail=$((fail + 1))
fi

# U2: nomes hostis — espaço passa (se válido); traço inicial não vira flag
SPACEIMG="$BASE/sp ace.img"
DASHIMG="$BASE/-dash.img"
cp -- "$GOODIMG" "$SPACEIMG"
cp -- "$GOODIMG" "$DASHIMG"
t_allow 22 "arquivo com espaço passa" flash boot_b "$SPACEIMG"
t_allow 23 "arquivo com traço inicial passa (sem confusão de flag)" flash boot_b "$DASHIMG"

# V89: reboot reads current-slot and is-userspace first. Slot a, or
# is-userspace yes, refuses and the stub must not see a reboot argv.
v89_fail=0
v89_case() { # <label> <slot-line> <user-line> <pass|deny>
  local label="$1" slot_line="$2" user_line="$3" expect="$4"
  local before errf rc new
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  errf="$BASE/v89.err"
  FAKE_SLOT_LINE="$slot_line" FAKE_USER_LINE="$user_line" \
    "$GUARD" reboot >"$BASE/v89.out" 2>"$errf"
  rc=$?
  new="$(tail -n +"$((before + 1))" "$STUBLOG" 2>/dev/null || true)"
  printf '### V89 %s\n' "$label"
  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && [ "$new" = $'getvar current-slot\ngetvar is-userspace\nreboot' ]; then
      printf '    reboot depois dos dois getvar\n  => OK\n\n'
      return 0
    fi
  else
    if [ "$rc" -ne 0 ] && grep -qF 'desligue por teclas e encerre' "$errf" \
        && grep -qx 'getvar current-slot' <<<"$new" \
        && grep -qx 'getvar is-userspace' <<<"$new" \
        && ! grep -qx 'reboot' <<<"$new"; then
      printf '    recusado sem argv reboot\n  => OK\n\n'
      return 0
    fi
  fi
  printf '    ESPERAVA %s; rc=%s\n%s\n  => FALHA\n\n' "$expect" "$rc" "$new"
  v89_fail=$((v89_fail + 1))
}

v89_case "slot a recusa" "current-slot: a" "is-userspace: no" deny
v89_case "is-userspace yes recusa" "current-slot: b" "is-userspace: yes" deny
v89_case "slot b passa" "current-slot: b" "is-userspace: no" pass
v89_case "userspace Variable not found passa" "current-slot: b" "is-userspace: Variable not found" pass
v89_case "slot sem linha recusa" "no-slot-here" "is-userspace: no" deny

if [ "$v89_fail" -eq 0 ]; then
  echo 'V89 OK reboot interlock'
else
  echo 'V89 FAIL reboot interlock'
  fail=$((fail + v89_fail))
fi

# V102: flash reads current-slot and is-userspace before it writes.
# Slot a, is-userspace yes, or a missing slot line exits 2 and the log
# has no flash argv. Slot b with is-userspace no still flashes.
v102_fail=0
v102_case() { # <label> <slot-line> <user-line> <pass|deny>
  local label="$1" slot_line="$2" user_line="$3" expect="$4"
  local before errf rc new
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  errf="$BASE/v102.err"
  FAKE_SLOT_LINE="$slot_line" FAKE_USER_LINE="$user_line" \
    "$GUARD" flash boot_b "$GOODIMG" >"$BASE/v102.out" 2>"$errf"
  rc=$?
  new="$(tail -n +"$((before + 1))" "$STUBLOG" 2>/dev/null || true)"
  printf '### V102 %s\n' "$label"
  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && grep -q 'flash boot_b ' <<<"$new"; then
      printf '    flash depois do slot\n  => OK\n\n'
      return 0
    fi
  else
    if [ "$rc" -eq 2 ] && ! grep -q 'flash boot_b ' <<<"$new" \
        && grep -qx 'getvar current-slot' <<<"$new" \
        && grep -qx 'getvar is-userspace' <<<"$new"; then
      printf '    recusado sem flash\n  => OK\n\n'
      return 0
    fi
  fi
  printf '    ESPERAVA %s; rc=%s\n%s\n  => FALHA\n\n' "$expect" "$rc" "$new"
  v102_fail=$((v102_fail + 1))
}

v102_case "slot a recusa" "current-slot: a" "is-userspace: no" deny
v102_case "is-userspace yes recusa" "current-slot: b" "is-userspace: yes" deny
v102_case "slot sem linha recusa" "no-slot-here" "is-userspace: no" deny
v102_case "slot b passa" "current-slot: b" "is-userspace: no" pass

if [ "$v102_fail" -eq 0 ]; then
  echo 'V102 OK flash slot interlock'
else
  echo 'V102 FAIL flash slot interlock'
  fail=$((fail + v102_fail))
fi

# V98: partition-size is LK hex. Accept 4000000 / 0x4000000 / 0X4000000.
# Refuse 3ffffff, the decimal-looking token 67108864, empty, and
# Variable not found. A refusal still calls getvar and must not flash.
v98_fail=0
v98_case() { # <label> <part-line> <pass|deny>
  local label="$1" part_line="$2" expect="$3"
  local before errf rc new
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  errf="$BASE/v98.err"
  FAKE_PART_LINE="$part_line" \
    "$GUARD" flash boot_b "$GOODIMG" >"$BASE/v98.out" 2>"$errf"
  rc=$?
  new="$(tail -n +"$((before + 1))" "$STUBLOG" 2>/dev/null || true)"
  printf '### V98 %s\n' "$label"
  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && grep -qx 'getvar partition-size:boot_b' <<<"$new" \
        && grep -q 'flash boot_b ' <<<"$new"; then
      printf '    flash depois de partition-size\n  => OK\n\n'
      return 0
    fi
  else
    if [ "$rc" -ne 0 ] && grep -qF 'partition-size:boot_b recusado' "$errf" \
        && grep -qx 'getvar partition-size:boot_b' <<<"$new" \
        && ! grep -q 'flash boot_b ' <<<"$new"; then
      printf '    recusado sem flash\n  => OK\n\n'
      return 0
    fi
  fi
  printf '    ESPERAVA %s; rc=%s\n%s\n  => FALHA\n\n' "$expect" "$rc" "$new"
  v98_fail=$((v98_fail + 1))
}

v98_case "4000000 passa" "partition-size:boot_b: 4000000" pass
v98_case "0x4000000 passa" "partition-size:boot_b: 0x4000000" pass
v98_case "0X4000000 passa" "partition-size:boot_b: 0X4000000" pass
v98_case "Finished trailer ignorado" $'partition-size:boot_b: 4000000\nFinished. Total time: 0.001s' pass
v98_case "3ffffff recusa" "partition-size:boot_b: 3ffffff" deny
v98_case "67108864 é hex e recusa" "partition-size:boot_b: 67108864" deny
v98_case "vazio recusa" "partition-size:boot_b:" deny
v98_case "Variable not found recusa" "partition-size:boot_b: Variable not found" deny
v98_case "FAILED recusa" "FAILED (remote: Variable not found)" deny

# T-1: accept exactly flash boot_b when size, magic, the listed hash, and
# stub partition-size 4000000 all hold. Refuse any one of those changing.
# The audited backup image is used when it sits next to this checkout.
# A throwaway copy of the repo has no image there; the synthetic file still
# proves the same four gates.
t1_fail=0
t1_note() { printf '### T-1 %s\n%s\n' "$1" "$2"; }

t1_run() { # <label> <expect pass|deny> <part-line> <hashes-file> <image> [extra-arg...]
  local label="$1" expect="$2" part_line="$3" hashes="$4" image="$5"
  shift 5
  local before errf rc new
  before="$(wc -l < "$STUBLOG" 2>/dev/null || echo 0)"
  errf="$BASE/t1.err"
  FAKE_PART_LINE="$part_line" \
    "$GUARD" --hashes "$hashes" flash boot_b "$image" "$@" >"$BASE/t1.out" 2>"$errf"
  rc=$?
  new="$(tail -n +"$((before + 1))" "$STUBLOG" 2>/dev/null || true)"
  printf '### T-1 %s\n' "$label"
  if [ "$expect" = "pass" ]; then
    if [ "$rc" -eq 0 ] && grep -qx 'getvar partition-size:boot_b' <<<"$new" \
        && grep -q 'flash boot_b ' <<<"$new"; then
      printf '    aceito\n  => OK\n\n'
      return 0
    fi
  else
    if [ "$rc" -ne 0 ] && ! grep -q 'flash boot_b ' <<<"$new"; then
      printf '    recusado sem flash\n  => OK\n\n'
      return 0
    fi
  fi
  printf '    ESPERAVA %s; rc=%s\n%s\n  => FALHA\n\n' "$expect" "$rc" "$new"
  t1_fail=$((t1_fail + 1))
}

GOODSUM="$(sha256sum "$GOODIMG" | cut -d' ' -f1)"
SYN_HASHES="$BASE/t1_syn.sha256"
printf '%s\n' "$GOODSUM" > "$SYN_HASHES"
BAD_HASHES="$BASE/t1_bad.sha256"
printf '%s\n' '3890fb9664c6543a4939b18b3845f05995221672fb4af905d2367ef12b829fc0' > "$BAD_HASHES"
t1_run "sintético hash+size+magic+4000000" pass "partition-size:boot_b: 4000000" "$SYN_HASHES" "$GOODIMG"
t1_run "hash que não é o do arquivo recusa" deny "partition-size:boot_b: 4000000" "$BAD_HASHES" "$GOODIMG"
t1_run "partição 3ffffff recusa" deny "partition-size:boot_b: 3ffffff" "$SYN_HASHES" "$GOODIMG"
t1_run "partição 67108864 recusa" deny "partition-size:boot_b: 67108864" "$SYN_HASHES" "$GOODIMG"
t1_run "partição vazia recusa" deny "partition-size:boot_b:" "$SYN_HASHES" "$GOODIMG"
t1_run "partição Variable not found recusa" deny "partition-size:boot_b: Variable not found" "$SYN_HASHES" "$GOODIMG"
t1_run "magic errado recusa" deny "partition-size:boot_b: 4000000" "$SYN_HASHES" "$NOMAGIC"
t1_run "tamanho errado recusa" deny "partition-size:boot_b: 4000000" "$SYN_HASHES" "$SMALL"
t1_run "boot_a recusa" deny "partition-size:boot_b: 4000000" "$SYN_HASHES" "$GOODIMG" boot_a

T1_HASH='3890fb9664c6543a4939b18b3845f05995221672fb4af905d2367ef12b829fc7'
T1_DIR="$(cd "$ROOT/../lake-kernel/backup-2026-10-05" 2>/dev/null && pwd || true)"
T1_IMG=""
if [ -n "$T1_DIR" ]; then
  T1_IMG="$T1_DIR/boot_b.img"
fi
if [ -n "$T1_IMG" ] && [ -f "$T1_IMG" ]; then
  t1_got="$(sha256sum "$T1_IMG" | cut -d' ' -f1)"
  t1_sz="$(stat -c%s -- "$T1_IMG")"
  t1_mag="$(head -c 8 -- "$T1_IMG" || true)"
  if [ "$t1_got" = "$T1_HASH" ] && [ "$t1_sz" = "67108864" ] && [ "$t1_mag" = "ANDROID!" ]; then
    T1_HASHES="$BASE/t1_audited.sha256"
    printf '%s\n' "$T1_HASH" > "$T1_HASHES"
    t1_run "backup 3890fb96…829fc7 + 4000000" pass "partition-size:boot_b: 4000000" "$T1_HASHES" "$T1_IMG"
    t1_run "backup com hash trocado recusa" deny "partition-size:boot_b: 4000000" "$BAD_HASHES" "$T1_IMG"
    t1_run "backup com partição 3ffffff recusa" deny "partition-size:boot_b: 3ffffff" "$T1_HASHES" "$T1_IMG"
  else
    printf '### T-1 backup presente mas hash/tamanho/magic divergem\n  => FALHA\n\n'
    t1_fail=$((t1_fail + 1))
  fi
else
  echo 'T1-AUDITED skip'
fi

if [ "$v98_fail" -eq 0 ]; then
  echo 'V98 OK partition-size hex parse'
else
  echo 'V98 FAIL partition-size hex parse'
  fail=$((fail + v98_fail))
fi
if [ "$t1_fail" -eq 0 ]; then
  echo 'T-1 pronto: sim'
else
  echo 'T-1 pronto: não'
  fail=$((fail + t1_fail))
fi

printf 'GUARD-SELFTEST: %s passada(s), %s falha(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && { echo 'V66 OK fastboot guard behavioral selftest (fake fastboot, allow+deny+update+oem+TOCTOU)'; echo 'SELFTEST-GUARD PASS'; exit 0; } || { echo 'V66 FAIL fastboot guard behavioral selftest'; echo 'SELFTEST-GUARD FAIL'; exit 1; }
