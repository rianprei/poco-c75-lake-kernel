#!/usr/bin/env bash
# fastboot_guard.sh — exact-allowlist wrapper around the real fastboot.
#
# Why this exists (SPEC.md §B): a shell `fastboot()` denylist function is weak —
# `command fastboot`, an absolute path, or a fresh shell bypasses it silently.
# This wrapper inverts the model: only argv forms on the allowlist below are
# ever executed; everything else is refused with exit 2 and the real fastboot
# is never invoked. The protocol uses ONLY this wrapper (never bare fastboot,
# never `command fastboot`).
#
# Allowlist (exact text):
#   devices
#   reboot   — only after this script reads current-slot and is-userspace (V89)
#   getvar <one of the 15 Z0.3 names>
#   flash boot_b <file>   — ONLY if all write gates hold (see below)
#
# Write gates for `flash boot_b <file>` (all must hold, else refuse):
#   1. exactly 3 words: flash, boot_b, <file>
#   2. <file> exists, is a regular file, size == 67108864 bytes
#   3. sha256(<file>) is listed in the hashes file ($FASTBOOT_GUARD_HASHES
#      or --hashes FILE): the backup hash recorded by the operator, or the
#      T3 image hash from its SHA256SUMS
#   4. first 8 bytes of <file> are "ANDROID!" (boot magic)
#   5. getvar partition-size:boot_b parses with lk_parse_size (LK hex, optional
#      0x/0X prefix) and that integer equals the copied file's size
#   6. getvar current-slot value is exactly b (a missing current-slot line refuses)
#   7. getvar is-userspace is not exactly yes
#
# usage: tools/fastboot_guard.sh [--hashes FILE] <fastboot args...>
#   FASTBOOT_BIN overrides the real fastboot binary (default: `command fastboot`,
#   which bypasses shell functions/aliases; tests put a fake first in PATH).
# Exit: 0/real-fastboot-status on allowlisted commands; 2 when refused or on
# usage errors (the real fastboot is NOT executed on refusal).
set -uo pipefail; export LC_ALL=C
# shellcheck source=lk_size.sh
. "$(cd "$(dirname "$0")" && pwd)/lk_size.sh"

# Private copy dir (TOCTOU): created per flash, removed on EXIT (trap, V6-clean).
GDIR=""
cleanup_guard() { if [ -n "$GDIR" ] && [ -d "$GDIR" ]; then rm -rf "$GDIR"; fi; }
trap cleanup_guard EXIT

HASHES_FILE="${FASTBOOT_GUARD_HASHES:-}"
FASTBOOT_BIN="${FASTBOOT_BIN:-fastboot}"

usage() {
  echo "uso: tools/fastboot_guard.sh [--hashes FILE] <fastboot args...>" >&2
  echo "     FASTBOOT_GUARD_HASHES=FILE (hashes sha256 permitidos, um por linha)" >&2
  exit 2
}

if [ "${1:-}" = "--hashes" ]; then
  [ $# -ge 2 ] || usage
  HASHES_FILE="$2"; shift 2
fi
[ $# -ge 1 ] || usage

refuse() { # <reason...> -> stderr + exit 2, real fastboot never runs
  echo "BLOQUEADO pelo fastboot_guard: $*" >&2
  exit 2
}

# --- exact getvar allowlist (the 15 Z0.3 names) ----------------------------------------------
is_allowlisted_getvar() { # <name> -> 0 yes / 1 no
  case "$1" in
    product|current-slot|slot-count|is-userspace|unlocked|max-download-size|partition-size:boot_b|\
slot-successful:a|slot-successful:b|slot-unbootable:a|slot-unbootable:b|\
slot-retry-count:a|slot-retry-count:b|battery-soc-ok|battery-voltage)
      return 0 ;;
    *) return 1 ;;
  esac
}

cmd="$1"; shift
case "$cmd" in
  devices|reboot)
    [ $# -eq 0 ] || refuse "extra args after '$cmd'"
    ;;
  getvar)
    [ $# -eq 1 ] || refuse "getvar needs exactly one variable name"
    is_allowlisted_getvar "$1" || refuse "getvar '$1' fora da allowlist (15 nomes do Z0.3)"
    ;;
  flash)
    # write path: flash boot_b <file> + all gates, nothing else.
    # TOCTOU (U1): the file is copied to a private mktemp dir (mode 0400) FIRST;
    # every check below reads the COPY, and the COPY is what gets flashed.
    # A concurrent change to the original after the check cannot affect the write.
    [ $# -eq 2 ] || refuse "flash precisa de exatamente: flash boot_b <arquivo>"
    [ "$1" = "boot_b" ] || refuse "flash só em boot_b (pedido: '$1')"
    file="$2"
    [ -f "$file" ] || refuse "arquivo inexistente ou não-regular: '$file'"
    GDIR="$(mktemp -d "${TMPDIR:-/tmp}/fastboot_guard.XXXXXX")" || refuse "mktemp falhou"
    IMG="$GDIR/image.bin"
    cp -- "$file" "$IMG" 2>/dev/null || refuse "não consegui copiar '$file'"
    chmod 0400 "$IMG" || refuse "chmod 0400 falhou"
    size="$(stat -c%s -- "$IMG" 2>/dev/null || echo -1)"
    [ "$size" = "67108864" ] || refuse "tamanho $size != 67108864 em '$file'"
    magic="$(head -c 8 -- "$IMG" 2>/dev/null || true)"
    [ "$magic" = "ANDROID!" ] || refuse "sem magic ANDROID! nos primeiros 8 bytes de '$file'"
    [ -n "$HASHES_FILE" ] || refuse "sem arquivo de hashes (--hashes FILE ou FASTBOOT_GUARD_HASHES)"
    [ -f "$HASHES_FILE" ] || refuse "arquivo de hashes inexistente: '$HASHES_FILE'"
    sum="$(sha256sum -- "$IMG" | cut -d' ' -f1)"
    grep -qxF "$sum" -- "$HASHES_FILE" || refuse "sha256 $sum de '$file' não está em '$HASHES_FILE'"
    # from here on, flash the verified COPY (original may change freely)
    set -- boot_b "$IMG"
    ;;
  *)
    refuse "comando '$cmd' fora da allowlist (devices, reboot, getvar <15 nomes>, flash boot_b <arquivo hash-verificado>)"
    ;;
esac

# allowlisted: run the real fastboot binary from PATH (type -P ignores shell
# functions/aliases, so a stale fastboot() denylist cannot shadow it; the PATH
# stub in tests resolves here). No exec: the private copy dir is removed after.
bin="$(type -P "$FASTBOOT_BIN")" || refuse "binário fastboot não encontrado no PATH"
# V98-PARTSIZE
# File gates above already refused a bad image without calling getvar.
# A flash that reached here has size 67108864. Read partition-size:boot_b
# and accept it only when lk_parse_size yields that same integer.
# Lake LK prints hex with no prefix (measured 2026-10-09: 4000000).
if [ "$cmd" = "flash" ]; then
  part_out="$("$bin" getvar partition-size:boot_b 2>&1 || true)"
  if grep -qF 'FAILED (' <<<"$part_out"; then
    refuse "partition-size:boot_b recusado"
  fi
  part_val="$(printf '%s\n' "$part_out" | sed -n 's/.*partition-size:boot_b:[[:space:]]*//p' | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
  part_dec="$(lk_parse_size "$part_val" 2>/dev/null || true)"
  if [ -z "$part_dec" ] || [ "$part_dec" != "$size" ]; then
    refuse "partition-size:boot_b recusado"
  fi
fi
# V98-PARTSIZE-END
# V102-FLASH-INTERLOCK
# Same rule as the reboot interlock, on the write path. Read both getvars
# before flash. Refuse unless current-slot is exactly b and is-userspace is
# not exactly yes. A missing slot line refuses. Exit 2. flash is not sent.
if [ "$cmd" = "flash" ]; then
  slot_out="$("$bin" getvar current-slot 2>&1 || true)"
  user_out="$("$bin" getvar is-userspace 2>&1 || true)"
  slot_val="$(printf '%s\n' "$slot_out" | sed -n 's/.*current-slot:[[:space:]]*//p' | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
  user_val="$(printf '%s\n' "$user_out" | sed -n 's/.*is-userspace:[[:space:]]*//p' | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
  if [ "$slot_val" != "b" ] || [ "$user_val" = "yes" ]; then
    echo "desligue por teclas e encerre" >&2
    exit 2
  fi
fi
# V102-FLASH-INTERLOCK-END
# V89-REBOOT-INTERLOCK
# reboot stays allowlisted, but it boots the current slot. Read both getvars
# before that argv is sent. Refuse unless the slot value is exactly b and
# is-userspace is not exactly yes. A missing slot line refuses. An empty
# is-userspace value is not yes.
if [ "$cmd" = "reboot" ]; then
  slot_out="$("$bin" getvar current-slot 2>&1 || true)"
  user_out="$("$bin" getvar is-userspace 2>&1 || true)"
  slot_val="$(printf '%s\n' "$slot_out" | sed -n 's/.*current-slot:[[:space:]]*//p' | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
  user_val="$(printf '%s\n' "$user_out" | sed -n 's/.*is-userspace:[[:space:]]*//p' | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
  if [ "$slot_val" != "b" ] || [ "$user_val" = "yes" ]; then
    echo "desligue por teclas e encerre" >&2
    exit 2
  fi
fi
# V89-REBOOT-INTERLOCK-END
"$bin" "$cmd" "$@"
rc=$?
exit "$rc"
