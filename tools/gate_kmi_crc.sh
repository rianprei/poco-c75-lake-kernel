#!/usr/bin/env bash
# GATE-KMI-CRC: every CRC a vendor module requires from vmlinux must equal the new kernel's CRC.
#
# usage: gate_kmi_crc.sh <symvers of the NEW build> [reference symvers = stock official]
# Exit 0 = PASS (0 mismatches, 0 missing exports), 1 = FAIL, 2 = environment/input error.
# Read-only: only temporary files under $(mktemp -d) are written.
#
# Data (see docs/KMI-GATES.md):
#   data/modules_required_crcs.tsv  symbol<TAB>0xCRC<TAB>module_basename  (all 557 .ko, 20187 rows)
#   data/modules_inventory.tsv      module_basename<TAB>copies<TAB>vermagic (370 modules, 557 files)
set -euo pipefail; export LC_ALL=C
NEW="${1:?usage: gate_kmi_crc.sh <symvers of the NEW build> [reference symvers]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="${2:-$HERE/../data/official-vmlinux.symvers}"
REQ="$HERE/data/modules_required_crcs.tsv"
INV="$HERE/data/modules_inventory.tsv"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

[ -e "$NEW" ] || { echo "error: symvers not found: $NEW" >&2; exit 2; }   # an *empty* file is a legitimately useless build: it flows through and FAILs
[ -s "$REQ" ] || { echo "error: missing required-CRC data: $REQ" >&2; exit 2; }
[ -s "$REF" ] || { echo "error: missing reference symvers: $REF" >&2; exit 2; }

# --- corpus metrics (from the published inventory/CRC data, not from the build) ---------------
files=0; unique=0
if [ -s "$INV" ]; then
  unique=$(wc -l < "$INV")
  files=$(awk -F'\t' '{s+=$2} END{printf "%d", s+0}' "$INV")
fi

# --- required (symbol, crc), one row per distinct pair ----------------------------------------
awk -F'\t' 'NF>=3 {print $1 "\t" $2}' "$REQ" | sort -u > "$T/req"
cut -f1 "$T/req" | sort -u > "$T/reqsyms"
required=$(wc -l < "$T/reqsyms")
conflicting=$(cut -f1 "$T/req" | uniq -d | wc -l)   # symbols carrying >1 distinct CRC

# --- new kernel exports and reference kernel exports ------------------------------------------
awk -F'\t' '$3=="vmlinux" {print $2 "\t" $1}' "$NEW" | sort -u > "$T/new"
awk -F'\t' '$3=="vmlinux" {print $2}' "$REF" | sort -u > "$T/refsyms"
ref_exports=$(wc -l < "$T/refsyms")
# symbols the modules require that the reference (stock) kernel provides
comm -12 "$T/reqsyms" "$T/refsyms" > "$T/provided"
provided=$(wc -l < "$T/provided")

# --- compare -----------------------------------------------------------------------------------
join -t$'\t' "$T/req" "$T/new" > "$T/j"
compared=$(wc -l < "$T/j")
# materialise the failure lists first: piping into head would trip pipefail (SIGPIPE)
awk -F'\t' '$2!=$3 {print "MISMATCH " $1 " required=" $2 " new=" $3}' "$T/j" > "$T/mm"
cut -f1 "$T/new" | sort -u > "$T/exported"
comm -23 "$T/provided" "$T/exported" > "$T/missing"
mismatches=$(wc -l < "$T/mm")
# required + provided by stock, but not exported by the new build
missing=$(wc -l < "$T/missing")

echo "modules.files=$files modules.unique=$unique"
echo "symbols.required=$required symbols.reference_exports=$ref_exports symbols.reference_provides=$provided"
echo "compared=$compared mismatches=$mismatches missing_exports=$missing conflicting_crcs=$conflicting"
head -20 "$T/mm"
head -20 "$T/missing" | sed 's/^/MISSING_EXPORT /'
[ "$mismatches" -eq 0 ] && [ "$missing" -eq 0 ] && [ "$conflicting" -eq 0 ] \
  && { echo PASS; exit 0; } || { echo FAIL; exit 1; }
