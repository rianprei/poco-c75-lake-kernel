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

printf 'GUARD-SELFTEST: %s passada(s), %s falha(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && { echo 'V66 OK fastboot guard behavioral selftest (fake fastboot, allow+deny+update+oem+TOCTOU)'; echo 'SELFTEST-GUARD PASS'; exit 0; } || { echo 'V66 FAIL fastboot guard behavioral selftest'; echo 'SELFTEST-GUARD FAIL'; exit 1; }
