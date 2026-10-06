#!/usr/bin/env bash
# check_docs_numbers.sh — V1 (invariant): every corpus number quoted in README.md and
# docs/KMI-GATES.md must equal the value the repository itself produces (SPEC.md §V/V1).
#
# Reference values come from two independent places:
#   * tools/gate_kmi_crc.sh data/official-vmlinux.symvers   (the gate's own metrics)
#   * the data files it reads (tools/data/*.tsv)
# and those two are cross-checked against each other first, so a doc number can only be right by
# agreeing with real data. This is what would have caught the 2026-10-06 "557 vs 215" mismatch (B1).
#
# Two kinds of quoting are enforced:
#   (a) the gate metric block ("modules.files=557 …") must appear in BOTH docs with the gate's values;
#   (b) every prose claim ("all 557 `.ko`", "370 distinct modules", "4138 symbols required", …) must
#       appear at least once across the docs and carry the right value.
# Device-dump-only numbers (342 ramdisk / 215 vendor_dlkm / 17 both / vermagic groups / kCFI counts /
# 429 baseline) cannot be reproduced offline and are listed as NOTES, not asserted — see SPEC.md §V1.
#
# usage: tools/check_docs_numbers.sh      (read-only; prints V1 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; cd "$ROOT"
fails=0
note() { printf 'V1 NOTE %s\n' "$1"; }
bad()  { printf 'V1 FAIL %s\n' "$1"; fails=$((fails + 1)); }

# --- 1. values straight from the gate -----------------------------------------------------------
gate_out="$(bash tools/gate_kmi_crc.sh data/official-vmlinux.symvers 2>&1)" || true
num() { printf '%s\n' "$gate_out" | grep -oE "(^| )$1=[0-9]+" | head -1 | cut -d= -f2; }
files="$(num 'modules\.files')";        unique="$(num 'modules\.unique')"
required="$(num 'symbols\.required')";  refexp="$(num 'symbols\.reference_exports')"
provides="$(num 'symbols\.reference_provides')"; compared="$(num 'compared')"
mismatches="$(num 'mismatches')"; missing="$(num 'missing_exports')"; conflicting="$(num 'conflicting_crcs')"
for pair in files:"$files" unique:"$unique" required:"$required" refexp:"$refexp" provides:"$provides" \
            compared:"$compared" mismatches:"$mismatches" missing:"$missing" conflicting:"$conflicting"; do
  [ -n "${pair#*:}" ] || { bad "gate_kmi_crc.sh não produziu ${pair%%:*} — gate quebrado, V1 não pode ser avaliado"; echo 'V1 FAIL'; exit 1; }
done

# --- 2. cross-check gate output against the published data files --------------------------------
rows_req="$(wc -l < tools/data/modules_required_crcs.tsv | tr -d ' ')"
sym_req="$(cut -f1 tools/data/modules_required_crcs.tsv | sort -u | wc -l | tr -d ' ')"
inv_rows="$(wc -l < tools/data/modules_inventory.tsv | tr -d ' ')"
copies="$(awk -F'\t' '{s+=$2} END{printf "%d", s+0}' tools/data/modules_inventory.tsv)"
other_modules=$((required - provides))
[ "$sym_req" = "$required" ] || bad "símbolos distintos no TSV de CRCs = $sym_req, mas symbols.required = $required"
[ "$inv_rows" = "$unique" ]  || bad "linhas de modules_inventory.tsv = $inv_rows, mas modules.unique = $unique"
[ "$copies" = "$files" ]     || bad "soma de copies em modules_inventory.tsv = $copies, mas modules.files = $files"
[ "$rows_req" -gt "$sym_req" ] || bad "TSV de CRCs com $rows_req linhas <= $sym_req símbolos distintos (arquivo truncado?)"

# --- 3a. the gate metric block, in both docs, with the gate's values -----------------------------
expect() { # <label> <expected> <file> <grep -P pattern> [global]
  local label="$1" want="$2" file="$3" pat="$4" global="${5:-}" found=0 got
  while IFS= read -r got; do
    found=$((found + 1))
    [ "$got" = "$want" ] || bad "$file: $label = $got, mas o repo produz $want"
  done < <(grep -oP "$pat" "$file" 2>/dev/null || true)
  [ "$found" -gt 0 ] || [ -n "$global" ] || bad "$file: nenhuma declaração de '$label' (número citado sumiu do texto)"
}
for doc in README.md docs/KMI-GATES.md; do
  expect "modules.files="                    "$files"        "$doc" 'modules\.files=\K[0-9]+'
  expect "modules.unique="                   "$unique"       "$doc" 'modules\.unique=\K[0-9]+'
  expect "symbols.required="                 "$required"     "$doc" 'symbols\.required=\K[0-9]+'
  expect "symbols.reference_exports="        "$refexp"       "$doc" 'symbols\.reference_exports=\K[0-9]+'
  expect "symbols.reference_provides="       "$provides"     "$doc" 'symbols\.reference_provides=\K[0-9]+'
  expect "compared="                         "$compared"     "$doc" 'compared=\K[0-9]+'
  expect "mismatches="                       "$mismatches"   "$doc" 'mismatches=\K[0-9]+'
  expect "missing_exports="                  "$missing"      "$doc" 'missing_exports=\K[0-9]+'
  expect "conflicting_crcs="                 "$conflicting"  "$doc" 'conflicting_crcs=\K[0-9]+'
done

# --- 3b. prose claims: each pattern must be used somewhere, and only with the right value --------
for pat_label in \
  "arquivos .ko do corpus|$files|(?<=\*\*|all |the |\()[0-9]+(?= \`?\.ko)" \
  "módulos distintos|$unique|[0-9]+(?= (distinct|unique) modules)" \
  "módulos únicos (pt-BR)|$unique|[0-9]+(?= módulos únicos)" \
  "símbolos exigidos|$required|[0-9]+(?= (symbols required|distinct symbols are imported))" \
  "símbolos exigidos (pt-BR)|$required|[0-9]+(?= símbolos exigidos)" \
  "símbolos fornecidos|$provides|[0-9]+(?= (provided by the kernel|come from the kernel))" \
  "símbolos fornecidos (pt-BR)|$provides|[0-9]+(?= fornecidos pelo kernel)" \
  "símbolos de outros módulos|$other_modules|remaining \K[0-9]+" \
  "linhas do TSV de CRCs|$rows_req|\(\K[0-9]+(?= rows, sorted)" \
  "linhas do inventário|$inv_rows|\(\K[0-9]+(?= rows, \`copies\`)" \
  "soma de copies citada|$copies|sums to \K[0-9]+" ; do
  IFS='|' read -r label want pat <<<"$pat_label"
  found=0
  for doc in README.md docs/KMI-GATES.md; do
    while IFS= read -r got; do
      found=$((found + 1))
      [ "$got" = "$want" ] || bad "$doc: $label = $got, mas o repo produz $want"
    done < <(grep -oP "$pat" "$doc" 2>/dev/null || true)
  done
  [ "$found" -gt 0 ] || bad "nenhuma citação de '$label' nos docs (o número sumiu, ou o padrão mudou)"
done

# --- 4. explicitly out of scope (device-dump-only numbers, SPEC.md §V/V1) ------------------------
note "not cross-checkable offline (device dump not published; see SPEC.md §V/V1): 342 ramdisk +"
note "215 vendor_dlkm + 17 in both; vermagic groups 193/170/7; 101|68 kCFI counts; 429 baseline modules"

if [ "$fails" -eq 0 ]; then
  echo "V1 PASS docs numbers == gate/data ($files files, $unique modules, $required required, $provides provided)"
  exit 0
fi
echo "V1 FAIL $fails divergência(s) entre docs e o repo"
exit 1
