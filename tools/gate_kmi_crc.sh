#!/usr/bin/env bash
# GATE-KMI-CRC: every CRC a vendor module requires from vmlinux must equal the new kernel's CRC.
# usage: gate_kmi_crc.sh <symvers of the NEW build> [reference symvers = stock official]
# Exit 0 = PASS (0 mismatches), 1 = FAIL. Read-only.
set -euo pipefail; export LC_ALL=C
NEW="${1:?symvers of the new build}"; HERE="$(cd "$(dirname "$0")" && pwd)"; REF="${2:-$HERE/../data/official-vmlinux.symvers}"; R="$HERE/data/vendor_required_crcs.txt"; T=$(mktemp -d)
awk -F'\t' '/^[[:space:]]+0x/ {gsub(/^[[:space:]]+/,"",$1); print $2"\t"$1}' "$R" | sort -u | sort -t$'\t' -k1,1 > $T/req
awk -F'\t' '$3=="vmlinux"{print $2"\t"$1}' "$NEW" | sort -u | sort -t$'\t' -k1,1 > $T/new
join -t$'\t' $T/req $T/new > $T/j
n=$(wc -l < $T/j); bad=$(awk -F'\t' '$2!=$3' $T/j | wc -l)
awk -F'\t' '$3=="vmlinux"{print $2}' "$REF" | sort -u > $T/refsyms
cut -f1 $T/req | sort -u > $T/reqsyms
# symbols the modules need that the STOCK vmlinux exports, but the NEW build does not
missing=$(comm -12 $T/reqsyms $T/refsyms | comm -23 - <(cut -f1 $T/new | sort -u) | wc -l)
echo "compared=$n mismatches=$bad missing_exports=$missing"
awk -F'\t' '$2!=$3{print "MISMATCH "$1" req="$2" new="$3}' $T/j | head -20
[ "$bad" -eq 0 ] && [ "$missing" -le 0 ] && echo PASS || { echo FAIL; exit 1; }
