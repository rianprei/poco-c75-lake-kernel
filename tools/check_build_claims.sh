#!/usr/bin/env bash
# check_build_claims.sh — V79–V88. Docs and scripts say what the commands do.
# usage: tools/check_build_claims.sh
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"
fails=0
bad() { printf '%s\n' "$1"; fails=$((fails + 1)); }
ok() { printf '%s\n' "$1"; }
need() { # <id> <file> <fixed string>
  if grep -qF -- "$3" "$2"; then return 0; fi
  bad "V$1 FAIL missing in $2: $3"
  return 1
}
forbid() { # <id> <file> <fixed string>
  if grep -qF -- "$3" "$2"; then
    bad "V$1 FAIL forbidden in $2: $3"
    return 1
  fi
  return 0
}

# V79 — cms diagnostic must not mask openssl.
# No pipe into grep -q (V54). A missing diag line is an empty hit, not a pass-by-mask.
hit79="$(grep -n 'diag_out=' tools/verify_modsig.sh)" || hit79=""
case "$hit79" in
  *'|| true'*) bad "V79 FAIL cms diagnostic masks openssl" ;;
  *) ok "V79 OK cms diagnostic reports openssl failure" ;;
esac

# V80 — checkout action is a full SHA, not a moving tag.
yml=".github/workflows/host-checks.yml"
if [ ! -f "$yml" ]; then
  bad "V80 FAIL workflow missing"
elif grep -qE 'uses:[[:space:]]*actions/checkout@v[0-9]' "$yml"; then
  bad "V80 FAIL actions/checkout is a moving tag"
elif ! grep -qE 'uses:[[:space:]]*actions/checkout@[0-9a-f]{40}' "$yml"; then
  bad "V80 FAIL actions/checkout is not pinned to a 40-hex SHA"
else
  ok "V80 OK actions/checkout pinned by SHA"
fi

# V81 — commands, units, and env flags a reader can copy.
v81=0
need 81 README.md '--footer-algorithm' || v81=1
need 81 docs/BUILD.md '--footer-algorithm' || v81=1
need 81 docs/BUILD.md 'avbtool info_image --image' || v81=1
need 81 README.md 'unpack_bootimg' || v81=1
need 81 docs/BUILD.md 'unpack_bootimg' || v81=1
need 81 docs/BUILD.md '| `WORK` |' || v81=1
need 81 docs/BUILD.md '| `CPUS` |' || v81=1
need 81 docs/BUILD.md '| `RAM_MB` |' || v81=1
need 81 docs/BUILD.md '| `REPO_NO_VERIFY` |' || v81=1
need 81 docs/BUILD.md "skips the repo launcher's GPG check" || v81=1
need 81 docs/BUILD.md 'scripts/build.sh clean' || v81=1
need 81 README.md '80 GiB' || v81=1
need 81 docs/BUILD.md '80 GiB' || v81=1
need 81 scripts/build.sh '83886080' || v81=1
forbid 81 README.md '~80 GB' || v81=1
forbid 81 docs/BUILD.md '~80 GB' || v81=1
[ "$v81" -eq 0 ] && ok "V81 OK build commands, disk units, and env flags match the script"

# V82 — the CRC gate, the tag pin, and --selftest are not wider than the command.
v82=0
forbid 82 README.md 'exactly the same symbols and CRCs' || v82=1
forbid 82 docs/KMI-GATES.md 'exactly the same symbols and CRCs' || v82=1
need 82 README.md 'does not verify a locally built Image' || v82=1
forbid 82 docs/KMI-GATES.md 'the gate enforces everything vmlinux provides' || v82=1
for doc in README.md docs/BUILD.md docs/KMI-GATES.md; do
  forbid 82 "$doc" '36/36' || v82=1
  need 82 "$doc" 'export_type_mismatches=0' || v82=1
  need 82 "$doc" 'namespace_mismatches=0' || v82=1
  if grep -qx 'exit=0' "$doc"; then
    bad "V82 FAIL $doc presents exit=0 as script output"
    v82=1
  fi
  forbid 82 "$doc" '3 negatives' || v82=1
  forbid 82 "$doc" 'remaining 6486' || v82=1
  forbid 82 "$doc" 'remaining 1819' || v82=1
done
need 82 README.md 'recorded and not enforced' || v82=1
need 82 docs/KMI-GATES.md 'recorded and not enforced' || v82=1
need 82 README.md 'does not mean a bit-identical Image' || v82=1
need 82 docs/KMI-GATES.md 'not a bit-identical Image' || v82=1
need 82 docs/KMI-GATES.md '6486' || v82=1
[ "$v82" -eq 0 ] && ok "V82 OK gate, tag pin, and selftest claims match the commands"

# V83 — config hash, 1573, kCFI cite, diff locale, vocabulary, repack tests.
v83=0
need 83 README.md 'zcat /proc/config.gz' || v83=1
need 83 README.md 'gzip bytes themselves hash differently' || v83=1
need 83 docs/KMI-GATES.md 'not byte-identical to `/proc/config.gz`' || v83=1
need 83 docs/KMI-GATES.md 'calc_eff_hook' || v83=1
need 83 docs/KMI-GATES.md 'was not recomputed' || v83=1
need 83 docs/KMI-GATES.md 'docs/AUDIT-CODEX.md' || v83=1
forbid 83 docs/KMI-GATES.md '(fact 50)' || v83=1
need 83 docs/KMI-GATES.md 'LC_ALL=C' || v83=1
need 83 docs/KMI-GATES.md '$HOME/lake-build' || v83=1
need 83 docs/KMI-GATES.md 'data/official-kernel_aarch64.config' || v83=1
need 83 docs/KMI-GATES.md 'tests/test_repack_boot.py' || v83=1
need 83 docs/KMI-GATES.md '32-case harness is not published' || v83=1
need 83 docs/KMI-GATES.md 'does not download that tar' || v83=1
need 83 docs/KMI-GATES.md "does not record the tar" || v83=1
need 83 docs/BUILD.md 'same_magic()' || v83=1
need 83 docs/BUILD.md 'common-android15-6.6-2025-06' || v83=1
forbid 83 docs/BUILD.md 'That is harmless' || v83=1
need 83 CONTRIBUTING.md 'strip serial' || v83=1
need 83 CONTRIBUTING.md 'IMEI' || v83=1
need 83 CONTRIBUTING.md 'MEASURED' || v83=1
need 83 CONTRIBUTING.md 'host-verified' || v83=1
need 83 README.md 'host-approved' || v83=1
need 83 README.md 'FAIL->PASS' || v83=1
for doc in README.md docs/BUILD.md docs/KMI-GATES.md CHANGELOG.md CONTRIBUTING.md; do
  for n in 64 65 42 45 44 43; do
    forbid 83 "$doc" "item $n" || v83=1
  done
done
[ "$v83" -eq 0 ] && ok "V83 OK config, corpus split, cites, and contributor rules match the repo"

# V84 — build.sh states 80 GiB and does not mask a failure.
v84=0
need 84 scripts/build.sh '80 GiB' || v84=1
need 84 scripts/build.sh '83886080' || v84=1
if grep -qF '|| true' scripts/build.sh; then
  bad "V84 FAIL scripts/build.sh masks a command"
  v84=1
fi
[ "$v84" -eq 0 ] && ok "V84 OK build.sh names 80 GiB and does not mask failures"

# V86 — copy-paste commands must name both cmp operands, keep "is not set"
# lines, and must not truncate an audited TSV.
v86=0
for doc in README.md docs/BUILD.md docs/KMI-GATES.md CHANGELOG.md CONTRIBUTING.md; do
  forbid 86 "$doc" "grep -v '^#'" || v86=1
  forbid 86 "$doc" '> tools/data/modules_required_crcs.tsv' || v86=1
  forbid 86 "$doc" '> tools/data/modules_inventory.tsv' || v86=1
  forbid 86 "$doc" 'cmp vmlinux.symvers' || v86=1
done
need 86 docs/KMI-GATES.md 'cmp <new vmlinux.symvers> data/official-vmlinux.symvers' || v86=1
need 86 docs/BUILD.md 'cmp "$HOME/lake-build/out/dist_control/vmlinux.symvers" data/official-vmlinux.symvers' || v86=1
need 86 docs/KMI-GATES.md 'only if the dump exits 0' || v86=1
need 86 docs/KMI-GATES.md '&& mv "$tmpc" tools/data/modules_required_crcs.tsv' || v86=1
need 86 docs/KMI-GATES.md '&& mv "$tmpi" tools/data/modules_inventory.tsv' || v86=1
[ "$v86" -eq 0 ] && ok "V86 OK config diff, symvers cmp, and TSV regen match the failure modes"

# V87 — claims stay inside what was measured.
v87=0
for doc in README.md docs/BUILD.md docs/SAFETY.md; do
  need 87 "$doc" 'this image was not measured' || v87=1
  forbid 87 "$doc" 'does not pass verification' || v87=1
  forbid 87 "$doc" 'does not pass AVB verification' || v87=1
  forbid 87 "$doc" 'will not pass verification' || v87=1
done
need 87 docs/KMI-GATES.md 'common/kernel/module/version.c' || v87=1
need 87 README.md 'common/kernel/module/version.c' || v87=1
need 87 docs/BUILD.md 'common/kernel/module/version.c' || v87=1
need 87 docs/KMI-GATES.md 'The TSV has no directory column' || v87=1
need 87 docs/KMI-GATES.md 'join of the symbols the 557 modules require with the symvers file passed' || v87=1
need 87 docs/KMI-GATES.md 'a conflicting CRC, an export_type mismatch, or a namespace mismatch' || v87=1
need 87 docs/KMI-GATES.md 'positive control on the reference symvers' || v87=1
need 87 docs/KMI-GATES.md '# ---' || v87=1
need 87 README.md 'recommended before any device write' || v87=1
need 87 README.md 'does not check those gate results' || v87=1
need 87 README.md 'unpublished dump' || v87=1
need 87 README.md 'device Image dump is unpublished' || v87=1
need 87 README.md 'Wi-Fi only' || v87=1
need 87 docs/BUILD.md 'Wi-Fi only' || v87=1
need 87 README.md 'PLAN fact 60' || v87=1
need 87 README.md 'mutex_lockX' || v87=1
need 87 README.md "CRC gate's own selftest" || v87=1
need 87 README.md 'não é byte-idêntica' || v87=1
forbid 87 README.md 'prove compatibility' || v87=1
forbid 87 README.md 'see below' || v87=1
forbid 87 README.md 'Everything here is verified on the host' || v87=1
forbid 87 README.md 'breaking Wi-Fi/Bluetooth' || v87=1
forbid 87 README.md 'reproduz esse kernel' || v87=1
forbid 87 README.md "all CRCs equal Google's" || v87=1
forbid 87 docs/KMI-GATES.md "all CRCs equal Google's" || v87=1
need 87 docs/BUILD.md 'certs/google_gki_ab13771415_modsign_cert.pem' || v87=1
need 87 docs/BUILD.md 'Fetch `official/can.ko` before the verify commands below.' || v87=1
need 87 docs/BUILD.md 'no Image certificate validates the module signer' || v87=1
need 87 docs/BUILD.md 'gzip -c Image > KERNEL_GZ' || v87=1
need 87 docs/BUILD.md 'magic is not `1f8b`' || v87=1
need 87 docs/BUILD.md 'Algorithm and rollback index live in this blob' || v87=1
need 87 docs/BUILD.md 'independent of the four above' || v87=1
need 87 docs/BUILD.md 'no comparison command is recorded in this repo' || v87=1
need 87 docs/BUILD.md 'scripts/build.sh control' || v87=1
forbid 87 docs/BUILD.md 'independent of the three above' || v87=1
forbid 87 docs/BUILD.md 'no cert: proves the need' || v87=1
forbid 87 docs/BUILD.md 'algorithm and rollback index' || v87=1
python3 - <<'PY'
import sys
text = open('docs/BUILD.md', encoding='utf-8').read()
fetch = text.find('tools/fetch_official_artifacts.sh Image can.ko')
verify = text.find('tools/verify_modsig.sh $HOME/lake-build/out/dist_cert/Image')
if fetch < 0 or verify < 0 or fetch > verify:
    print('V87 FAIL fetch of official/can.ko is not before verify_modsig')
    sys.exit(1)
PY
[ $? -eq 0 ] || v87=1
[ "$v87" -eq 0 ] && ok "V87 OK measured claims stay inside the recorded evidence"

# V88 — first-build instructions and changelog paths.
v88=0
need 88 CONTRIBUTING.md 'ro.product.device' || v88=1
need 88 CONTRIBUTING.md 'z0_fastboot_before.txt' || v88=1
need 88 CONTRIBUTING.md 't2b_readout.txt' || v88=1
need 88 CONTRIBUTING.md 't2b_post_readout.txt' || v88=1
need 88 CONTRIBUTING.md 'baseline_modules.txt' || v88=1
need 88 CONTRIBUTING.md 'baseline_dmesg.txt' || v88=1
need 88 CONTRIBUTING.md '/sys/fs/pstore' || v88=1
need 88 CONTRIBUTING.md 'docs/SAFETY.md' || v88=1
need 88 CONTRIBUTING.md 'bootloop' || v88=1
need 88 CONTRIBUTING.md './tools/run_all_checks.sh' || v88=1
need 88 CONTRIBUTING.md './tools/selftest_backprop.sh' || v88=1
need 88 CONTRIBUTING.md 'tools/selftest_gates.sh' || v88=1
need 88 CONTRIBUTING.md 'INFERRED' || v88=1
need 88 CONTRIBUTING.md 'UNKNOWN' || v88=1
need 88 CHANGELOG.md 'tools/dump_modcrcs.py` parses ELF strictly' || v88=1
need 88 CHANGELOG.md 'tests/fixtures/sha256sums_clean.txt' || v88=1
need 88 CHANGELOG.md 'docs/SAFETY.md' || v88=1
need 88 CHANGELOG.md 'scripts/build.sh` state machine' || v88=1
need 88 CHANGELOG.md '557 vendor' || v88=1
forbid 88 CHANGELOG.md '.ko` of the device' || v88=1
python3 - <<'PY'
import sys
lines = open('CHANGELOG.md', encoding='utf-8').read().splitlines()
want = ['## 0.2.2 ', '## 0.2.1 ', '## 0.2.0 ', '## 0.1.2 ', '## 0.1.1 ', '## 0.1.0-experimental']
idx = []
for key in want:
    found = next((i for i, line in enumerate(lines) if line.startswith(key)), -1)
    idx.append(found)
if any(i < 0 for i in idx) or idx != sorted(idx):
    print('V88 FAIL changelog headings are not descending')
    sys.exit(1)
PY
[ $? -eq 0 ] || v88=1
[ "$v88" -eq 0 ] && ok "V88 OK contributor route and changelog paths are explicit"

if [ "$fails" -eq 0 ]; then
  exit 0
fi
exit 1
