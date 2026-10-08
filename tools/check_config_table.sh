#!/usr/bin/env bash
# check_config_table.sh — V70: data/config_safety_table.csv hygiene (items 66-70).
# - no absolute-risk language (SEGURO/ARRISCADO/PROIBIDO as categories, "sem risco",
#   "panic imediato", schedutil "hispeed_freq" knob claim);
# - every row carries gates_status + tree_check (UNVERIFIED/NEEDS-TREE-CHECK default).
# Read-only; prints V70 PASS|FAIL lines.
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"
CSV="data/config_safety_table.csv"
fails=0
ok() { echo "V70 OK $1"; }
fail() { echo "V70 FAIL $1"; fails=$((fails + 1)); }

[ -f "$CSV" ] || { fail "$CSV missing"; echo "V70 FAIL"; exit 1; }
hdr="$(head -1 "$CSV")"
grep -q 'gates_status' <<<"$hdr" || fail "header lacks gates_status column"
grep -q 'tree_check' <<<"$hdr" || fail "header lacks tree_check column"
for s in SEGURO ARRISCADO PROIBIDO 'sem risco' 'panic imediato'; do
  if grep -qF "$s" "$CSV"; then
    fail "absolute language present: $s"
  fi
done
grep -qF 'hispeed_freq/' "$CSV" && fail "schedutil hispeed_freq knob claim back in table" || true
grep -qF 'NÃO é knob' "$CSV" || fail "schedutil correction note missing"
python3 - "$CSV" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1], encoding='utf-8')))
bad = 0
if len(rows) < 10:
    print(f'V70 FAIL only {len(rows)} data rows (minimum 10)')
    bad += 1
for i, r in enumerate(rows, 2):
    if not (r.get('gates_status') or '').strip():
        print(f'V70 FAIL line {i}: empty gates_status'); bad += 1
    if not (r.get('tree_check') or '').strip():
        print(f'V70 FAIL line {i}: empty tree_check'); bad += 1
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fails=$((fails + 1))
if [ "$fails" -eq 0 ]; then
  ok "config table: no absolute language, gate columns present"
  exit 0
fi
echo "V70 FAIL config table hygiene"
exit 1
