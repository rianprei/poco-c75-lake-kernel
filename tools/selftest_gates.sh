#!/usr/bin/env bash
# selftest_gates.sh — self-test of gate_kmi_crc.sh: 1 positive + 3 negative (sabotage) cases.
# Host-only, read-only on the repo: every sabotage happens on a copy under a fresh mktemp -d.
#
# usage: tools/selftest_gates.sh
# Exit 0 = SELFTEST PASS, 1 = SELFTEST FAIL.
set -euo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate_kmi_crc.sh"
REF="${REF:-$HERE/../data/official-vmlinux.symvers}"
REQ="$HERE/data/modules_required_crcs.tsv"
SYM="${SYM:-mutex_lock}"            # a symbol the modules require and stock exports
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

[ -s "$REF" ] || { echo "missing reference symvers: $REF" >&2; exit 1; }
[ -s "$REQ" ] || { echo "missing data: $REQ" >&2; exit 1; }
awk -F'\t' -v s="$SYM" '$1==s {found=1} END {exit !found}' "$REQ" \
  || { echo "precondition: $SYM is not a required symbol in $REQ" >&2; exit 1; }
REQ_CRC="$(awk -F'\t' -v s="$SYM" '$2==s && $3=="vmlinux" {print $1; exit}' "$REF")"
[ -n "$REQ_CRC" ] || { echo "precondition: $SYM is not exported by $REF" >&2; exit 1; }

fails=0
run_case() { # <label> <expected_exit> <grep -E pattern> <symvers>
  local label="$1" want="$2" pat="$3" file="$4" out rc
  out="$("$GATE" "$file" 2>&1)" && rc=0 || rc=$?
  printf '%s\n' "$out" | sed 's/^/    /'
  if [ "$rc" -eq "$want" ] && grep -qE "$pat" <<<"$out"; then
    echo "  => OK   [$label] exit=$rc, casou /$pat/"
  else
    echo "  => FALHA [$label] exit=$rc (esperado $want), padrão /$pat/ ausente"
    fails=$((fails + 1))
  fi
  echo
}

echo "### [1/4] POSITIVO: symvers de referência (stock oficial do Google)"
run_case "positivo" 0 '^PASS$' "$REF"

echo "### [2/4] NEGATIVO (i): 1 CRC exigido corrompido ($SYM: $REQ_CRC -> 0xdeadbeef)"
sed -E "s/^0x[0-9a-fA-F]+\t${SYM}\t/0xdeadbeef\t${SYM}\t/" "$REF" > "$WORK/bad_crc.symvers"
run_case "crc-sabotado" 1 "MISMATCH ${SYM} required=$REQ_CRC new=0xdeadbeef" "$WORK/bad_crc.symvers"

echo "### [3/4] NEGATIVO (ii): 1 export exigido removido do symvers ($SYM)"
grep -v -P "\t${SYM}\t" "$REF" > "$WORK/dropped.symvers"
run_case "export-removido" 1 "^MISSING_EXPORT ${SYM}$" "$WORK/dropped.symvers"

echo "### [4/4] NEGATIVO (iii): symvers vazio"
: > "$WORK/empty.symvers"
run_case "symvers-vazio" 1 "compared=0 .*missing_exports=2309" "$WORK/empty.symvers"

if [ "$fails" -eq 0 ]; then
  echo "SELFTEST PASS (positivo PASS + 3 negativos FAIL)"
else
  echo "SELFTEST FAIL ($fails caso(s) fora do esperado)"
  exit 1
fi
