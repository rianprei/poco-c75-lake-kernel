#!/usr/bin/env bash
# lk_parse_size — one parser for an LK size token.
#
# Measured on the audited lake, 2026-10-09: `partition-size:boot_b` answered
# `4000000` with no prefix. That token is hex. `0x4000000` and `0X4000000`
# are the same number (67108864). A decimal reading would make `4000000`
# mean 4194304, so a token of only digits is still hex. `67108864` is legal
# hex (0x67108864 = 1729136740) and is not the byte count 67108864.
# `max-download-size` uses the same function: measured `0x8000000` = 134217728.
#
# Prints the integer in decimal. Returns 1 on empty, on non-hex, on a bare
# `0x`, and on more than 8 hex digits. Callers compare the integer; this
# function does not know the 67108864 gate.
lk_parse_size() {
  local v="${1-}" hex n
  v="${v//$'\r'/}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  case "$v" in
    0x*|0X*) hex="${v:2}" ;;
    *) hex="$v" ;;
  esac
  case "$hex" in
    ''|*[!0-9A-Fa-f]*) return 1 ;;
  esac
  n="${#hex}"
  if [ "$n" -lt 1 ] || [ "$n" -gt 8 ]; then
    return 1
  fi
  printf '%s\n' "$((16#$hex))"
}
