# Changelog

## 0.2.7 (2026-10-10)

- The pstore cold-boot gate no longer requires `console-ramoops-0`.
  It checks the registered backend (`ramoops`, cmdline
  `ramoops.mem_address=0x4d010000`, console_size and pmsg_size greater
  than 0). An empty folder after a cold boot is recorded (MEASURED
  2026-10-10). Empty after a warm restart stops before T3. Empty after
  a real crash uses `dmesg` and `adb bugreport` (V113).
- Suite: invariants V1–V113 (V10–V13 are aliases) plus the CRC gate
  self-test (114 checks). Sabotage 148/148.

## 0.2.6 (2026-10-10)

- The slot compare is unchanged. `current-slot` is exactly b after trailing
  space and CR are removed (whitespace after the colon is not part of the
  value, so a leading space is still b). `_b`, `B`, `bb`, `a`, and an empty
  value are refused, on flash and on reboot (V112).
- Suite: invariants V1–V112 (V10–V13 are aliases) plus the CRC gate
  self-test (113 checks). Sabotage 147/147.

## 0.2.5 (2026-10-10)

- `tools/fastboot_guard.sh flash` reads `current-slot` and `is-userspace`
  before it writes. Slot other than `b`, `is-userspace` `yes`, or a missing
  slot line exits 2 and does not call `flash` (V102). Write gates 6 and 7
  name that rule. The protocol says the wrapper re-checks both on every flash.
- The second-disk copy blocks T-1.1, not only T3. The copy is `cp` plus
  `sha256sum -c` on the destination. For this owner it is MEASURED
  2026-10-09: 44/44 on a separate physical disk (V103, V111).
- A guard refusal is not a mid-write. A drop with no `OKAY` is not intact
  bytes. T-1.3b does not gate `slot-retry-count:b`. The measured stock
  `uname -r` is the T-1.3a reference. Host guard files come before the adb
  baseline, and the cable comes off before Z0.1. The new-image hash is a
  T3-day line. An isolated Z0 is what exits through Z0.6 (V104–V110).
- Suite: invariants V1–V111 (V10–V13 are aliases) plus the CRC gate
  self-test (112 checks). Sabotage 146/146. Case 71 replaces every
  `slot-unbootable:b` on the T-1.3 rows, because the pass cell repeats it.

## 0.2.4 (2026-10-09)

- `lk_parse_size` is the one LK size parser: optional `0x`/`0X`, then hex.
  `4000000` and `0x4000000` are 67108864. The all-digit token `67108864` is
  hex 1729136740, not that byte count. `tools/fastboot_guard.sh` reads
  `partition-size:boot_b` and flashes only when the parsed integer equals
  the file size (V98).
- Z0 on 2026-10-09 is logged: `partition-size:boot_b` was `4000000`,
  `max-download-size` was `0x8000000`, `is-userspace` was `no`, slot A was
  `unbootable=yes` / `successful=no` / retry 0, and `slot-retry-count:b`
  was 1. "Does not fall to A" stays INFERRED. Risk remains (V100, V101).
- Key entry is: power off, disconnect the cable, hold Vol− + Power until
  FASTBOOT, release, then reconnect the cable (V99).
- Suite: invariants V1–V101 (V10–V13 are aliases) plus the CRC gate
  self-test (102 checks). Sabotage 136/136.

## 0.2.3 (2026-10-09)

- `tools/fastboot_guard.sh reboot` reads `current-slot` and `is-userspace`
  before it sends `reboot`. Slot other than `b`, or `is-userspace` `yes`,
  exits 2 and prints `desligue por teclas e encerre` (V89). The fastboot
  binary does not receive `reboot` on that refusal.
- Z0.6 re-applies Z0.4 before a retry reboot. The abort preamble does not
  reboot when current-slot is not b. "Any other answer" names the PASS
  predicates. `slot-successful:a` and `slot-unbootable:a` are record-only.
  Absence is the string `Variable not found` with no `FAILED (` in that
  answer. An empty Z0.2 ends the day with no other cable. Z0.5 stops when
  the capture lacks one answer per allowlist name. `max-download-size` is
  decimal or `0x` hex, both in bytes. The two Z0 PASS lines name lake,
  slot `_b`, OS3.0.306.0, and the day baseline (V90–V97).
- Suite: invariants V1–V97 (V10–V13 are aliases) plus the CRC gate self-test
  (98 checks). Sabotage 131/131.

## 0.2.2 (2026-10-08)

- Host gates now fail closed on a gate that exits non-zero (V77), on a curl
  error in the artifact viewer (V78), and on a masked cms diagnostic (V79).
  `actions/checkout` in the host workflow is pinned by commit SHA (V80).
  The fastboot guard selftest sends `update` and two `oem` forms (V66).
  The modsig matrix is 8/8 and includes an expired certificate and a
  not-yet-valid certificate (V67). Python tests treat ResourceWarning text
  as failure and run `run_fuzz.py` when that file exists (V65). A missing
  required doc is V85. `scripts/build.sh` names 80 GiB (83886080 KiB).
- Docs match the commands: `--footer-algorithm`, `avbtool info_image --image`,
  `unpack_bootimg`, `clean`, and `WORK` / `CPUS` / `RAM_MB` / `REPO_NO_VERIFY`
  (the last one skips the repo launcher GPG check). The CRC gate covers the
  2309 symbols the modules require. `common` is pinned by tag; that SHA is
  recorded and not enforced. The config hash is the decompressed text.
  CONTRIBUTING names both status vocabularies and says to strip serial
  numbers and IMEI from a bugreport before pasting.
- Documented config diffs no longer drop `# CONFIG_ is not set` lines.
  Symvers `cmp` names both files. TSV regeneration writes a temp file and
  moves it only after a zero exit and the expected line count.
  CONTRIBUTING names where raw logs stay, the three sabotage commands, and
  `ro.product.device`.
- Suite: invariants V1–V88 (V10–V13 are aliases) plus the CRC gate self-test
  (89 checks). Sabotage 121/121.

## 0.2.1 (2026-10-07)

- Fetch publish gate (V76, B90): a requested artifact name is one basename;
  the body is staged privately and moved into `official/` only after the
  type/size check and any pinned sha256. A rejected body is not a candidate.
  Status words are `DOWNLOADED` plus `HASH-VERIFIED` or `UNVERIFIED`.
  Sabotage cases 96–98. The KMI self-test also plants an `export_type` mismatch.
- Suite at this point: invariants V1–V76 (V10–V13 aliases), sabotage 102/102.
- Config-table fonte URLs: a trailing `:line` made six googlesource links 404.
  The line number now sits beside the file URL. `gates_status` stays UNVERIFIED;
  `tree_check` stays NEEDS-TREE-CHECK.

## 0.2.0 (2026-10-07) — maintainer round (FIX8–FIX13 + MISSION)

Host-side only; still not boot-tested on hardware. Backprop registry now B1–B89 (§B),
invariants V1–V75 (§V; V10–V13 are aliases), sabotage suite 99 cases
(`SELFTEST-BACKPROP PASS`, 99/99).

- Device protocol: T-1 identical-content rehearsal before any write (FIX8); Z0 closed
  allowlist + key-entry criterion + slot-mismatch/no-adb/baseline rules (FIX9); real LK
  partition tables (FIX10); never-touch completeness + bidirectional table check (FIX11/11b);
  REVIEW9/10 + runbook findings (FIX12); residual-risks table (FIX13); exact-allowlist
  `tools/fastboot_guard.sh` wrapper, retry-as-informational, getvar policy, stderr captures,
  T-1.3 change detection (MISSION/FIX14). One class per getvar (`slot-successful` /
  `slot-unbootable` required; `is-userspace` is the only accepted-absent;
  `max-download-size` is threshold-if-present). Order is T2b-pre, then T3, then
  T2b-post; T3 pass is `OKAY`, not the 30 min stress. L2/L3/L4 name a stop or a
  wrapper rollback. `fastboot boot` stays UNKNOWN and is not a stop criterion.
- Gates: fail-closed runner; export_type/namespace identity; modsig signer-compare +
  synthetic 6-matrix; repack fatal post-conditions + unit tests;
  `tools/dump_modcrcs.py` parses ELF strictly;
  fetch traversal/atomic/partial/magic hardening; `scripts/build.sh` state machine + provenance.
- Docs: controlled safety vocabulary (host-verified / rebuild-reproducible /
  hardware-unverified / boot-unproven); FACTS log + raw/ separation; config-table
  gate columns; glossary GKI-signature/AVB-footer/VBMeta/verified-boot/module-signing.

## 0.1.2 (2026-10-06)

Backprop pass: every real error found so far became a machine-checked invariant, so it cannot return silently. Host-side only; still **not boot-tested on hardware**.

- New `SPEC.md`: bug registry (§B, B1–B13 with date, root cause and the invariant that prevents it), invariants V1–V9 (§V, testable phrasing + the file that protects each), open tasks (§T: boot on `lake`, `fastboot boot`, A/B fallback, Wi-Fi/BT, thermal stress, `pstore` after a panic) and the convergence criterion for the adversarial review (two consecutive rounds with no new concrete finding).
- New checks (all read-only, `mktemp` only): `tools/check_docs_numbers.sh` (V1: documented corpus numbers must equal `tools/gate_kmi_crc.sh` output and `tools/data/*.tsv`), `tools/check_regex_controls.sh` (V2: every documented `grep -E` needs a positive *and* a negative control; `\|` inside `-E` is rejected), `tools/check_protocol_invariants.sh` (V3/V4/V5/V7/V8), `tools/check_destructive_ops.sh` (V6), `tools/selftest_fetch.sh` (V9), plus `tools/run_all_checks.sh` (summary per invariant, exit ≠ 0 on failure) and `tools/selftest_backprop.sh` (10 sabotage cases, each proven FAIL→PASS).
- New fixtures `tests/fixtures/dmesg_bad.txt`, `tests/fixtures/dmesg_clean.txt`, `tests/fixtures/sha256sums_bad.txt`, `tests/fixtures/sha256sums_clean.txt` as the controls those checks run against.
- Real defects the new checks exposed and that are now fixed: the protocol's dmesg acceptance had no runnable command (B10, command block added, with its own host-side controls); six absence claims in `docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md` rested on a single observation (B11, each now cites two independent sources); `tools/verify_modsig.sh` used `grep -i "serial\|issuer"` (B12, now `-iE`); `docs/KMI-GATES.md` asserted the protected-exports set with no source (B13, now cites `android/abi_gki_protected_exports_aarch64` and facts 37).
- `tools/fetch_official_artifacts.sh` gained `--dry-run`, which prints the viewer URL it would request and writes nothing — the URL V9 verifies is the script's own, not a copy.

## 0.1.1 (2026-10-06)

Everything below is host-side; still not boot-tested on hardware. Supersedes the numbers of 0.1.0.

- CRC data now covers **all 557 vendor `.ko` files (ramdisk + vendor_dlkm) = 370 distinct modules** (`tools/data/modules_required_crcs.tsv`, 20187 rows; `tools/data/modules_inventory.tsv`, 370 rows / 557 copies). System_dlkm GKI modules are outside that corpus. The 0.1.0 data covered only the 215 `vendor_dlkm` modules, which is where the old "1573 kernel symbols" came from.
- `tools/gate_kmi_crc.sh` rewritten over the new data; it now reports the corpus size and three failure modes:
  `modules.files=557 modules.unique=370`, `symbols.required=4138`, `symbols.reference_exports=8795`, `symbols.reference_provides=2309`, `compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0` → `PASS` on `data/official-vmlinux.symvers`. Control and cert build trees are not published in this repo.
- New `tools/selftest_gates.sh`: 1 positive + 3 sabotage cases (corrupted CRC of a required symbol, dropped export, empty symvers), all on `mktemp -d` copies → `SELFTEST PASS`.
- `tools/dump_modcrcs.py` rewritten (deterministic output, `--inventory` mode, slot-prefix normalisation); `tools/data/vendor_required_crcs.txt` and `tools/data/kmi_need_from_kernel.txt` removed as superseded.
- `tools/fetch_official_artifacts.sh` hardened: browser User-Agent, 3 attempts with backoff, explicit error with the manual URL when `artifactUrl` is absent, and sha256 verification of `Image`/`can.ko`.
- `tools/verify_modsig.sh` no longer writes to a hard-coded scratch directory: temporary workdirs come from `mktemp -d` and are removed by an `EXIT` trap.

## 0.1.0-experimental (2026-10-05)

First public snapshot. **Host-side verified only; not boot-tested on hardware.**

- Reproducible build recipe for the Google GKI `android15-6.6-2025-06_r12` kernel (6.6.89) used by POCO C75 4G (`lake`), pinned to the official CI manifest.
- Patches to embed the Google GKI module-signing certificate (`CONFIG_SYSTEM_TRUSTED_KEYS`) so stock `system_dlkm` modules keep `sig_ok=true` (intended effect; not verified on a device).
- Offline gates: `vmlinux.symvers` identity, per-symbol CRC check, config diff, certificate check.
- Boot image repack tool (kernel swap, AVB footer regeneration) with in-code refusal checks (truncated input, non-gzip kernel, ramdisk, existing output, oversize, GKI signature block).
- Research notes and a measured-facts plan (`docs/PLAN-AND-FINDINGS.pt-BR.md`).
- No boot images are published.
