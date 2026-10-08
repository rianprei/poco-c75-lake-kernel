#!/usr/bin/env bash
# selftest_fetch.sh — V9 (invariant): the URL tools/fetch_official_artifacts.sh would request must
# be exactly the one the docs promise, for the same file names. This is the check that was missing
# when a "fetch is broken" finding (BUG B9) was produced by testing a *different* URL than the
# script uses: here the script itself (via --dry-run) is the source of the URL.
#
# Confirmed pattern: https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest/<file>
#
# usage: tools/selftest_fetch.sh      (no network; prints V9 PASS|FAIL lines)
# Structural URL check only (item 41). This is not a network smoke test, and the
# default suite does not download artifacts.
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
FETCH="$ROOT/tools/fetch_official_artifacts.sh"
BASE='https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest'
fails=0
for f in can.ko Image vmlinux.symvers; do
  want="$BASE/$f"
  got="$("$FETCH" --dry-run "$f" 2>&1 | head -1)"
  if [ "$got" = "$want" ]; then
    printf 'V9 OK   --dry-run %s -> %s\n' "$f" "$got"
  else
    printf 'V9 FAIL --dry-run %s -> %s (esperado %s)\n' "$f" "${got:-<vazio>}" "$want"
    fails=$((fails + 1))
  fi
done
# BUILD_INFO lives under view/ in the viewer, exactly as the script maps it
got="$("$FETCH" --dry-run BUILD_INFO 2>&1 | head -1)"
[ "$got" = "$BASE/view/BUILD_INFO" ] && printf 'V9 OK   --dry-run BUILD_INFO -> %s\n' "$got" \
  || { printf 'V9 FAIL --dry-run BUILD_INFO -> %s (esperado %s)\n' "${got:-<vazio>}" "$BASE/view/BUILD_INFO"; fails=$((fails + 1)); }
# no side effects: the dry-run must not create the destination directory
[ -e "$ROOT/official" ] && { printf 'V9 FAIL --dry-run criou %s\n' "$ROOT/official"; fails=$((fails + 1)); } \
  || printf 'V9 OK   --dry-run não criou %s\n' "$ROOT/official"
if [ "$fails" -eq 0 ]; then
  echo "V9 PASS dry-run URL pattern == documented viewer URL ($BASE)"
  exit 0
fi
echo "V9 FAIL $fails divergência(s) de URL"
exit 1
