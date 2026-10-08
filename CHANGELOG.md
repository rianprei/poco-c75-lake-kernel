# Changelog

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
  synthetic 6-matrix; repack fatal post-conditions + strict ELF parsing + unit tests;
  fetch traversal/atomic/partial/magic hardening; build.sh state machine + provenance.
- Docs: controlled safety vocabulary (host-verified / rebuild-reproducible /
  hardware-unverified / boot-unproven); FACTS log + raw/ separation; config-table
  gate columns; glossary GKI-signature/AVB-footer/VBMeta/verified-boot/module-signing.

## 0.1.0-experimental (2026-10-05)

First public snapshot. **Host-side verified only; not boot-tested on hardware.**

- Reproducible build recipe for the Google GKI `android15-6.6-2025-06_r12` kernel (6.6.89) used by POCO C75 4G (`lake`), pinned to the official CI manifest.
- Patches to embed the Google GKI module-signing certificate (`CONFIG_SYSTEM_TRUSTED_KEYS`) so stock `system_dlkm` modules keep `sig_ok=true`.
- Offline gates: `vmlinux.symvers` identity, per-symbol CRC check, config diff, certificate check.
- Boot image repack tool (kernel swap, AVB footer regeneration) with in-code refusal checks (truncated input, non-gzip kernel, ramdisk, existing output, oversize, GKI signature block).
- Research notes and a measured-facts plan (`docs/PLAN-AND-FINDINGS.pt-BR.md`).
- No boot images are published.

## 0.1.1 (2026-10-06)

Everything below is host-side; still not boot-tested on hardware. Supersedes the numbers of 0.1.0.

- CRC data now covers **all 557 `.ko` of the device = 370 distinct modules** (`tools/data/modules_required_crcs.tsv`, 20187 rows; `tools/data/modules_inventory.tsv`, 370 rows / 557 copies). The 0.1.0 data covered only the 215 `vendor_dlkm` modules, which is where the old "1573 kernel symbols" came from.
- `tools/gate_kmi_crc.sh` rewritten over the new data; it now reports the corpus size and three failure modes:
  `modules.files=557 modules.unique=370`, `symbols.required=4138`, `symbols.reference_exports=8795`, `symbols.reference_provides=2309`, `compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0` → `PASS` on `data/official-vmlinux.symvers`, `dist_control` and `dist_cert`.
- New `tools/selftest_gates.sh`: 1 positive + 3 sabotage cases (corrupted CRC of a required symbol, dropped export, empty symvers), all on `mktemp -d` copies → `SELFTEST PASS`.
- `tools/dump_modcrcs.py` rewritten (deterministic output, `--inventory` mode, slot-prefix normalisation); `tools/data/vendor_required_crcs.txt` and `tools/data/kmi_need_from_kernel.txt` removed as superseded.
- `tools/fetch_official_artifacts.sh` hardened: browser User-Agent, 3 attempts with backoff, explicit error with the manual URL when `artifactUrl` is absent, and sha256 verification of `Image`/`can.ko`.
- `tools/verify_modsig.sh` no longer writes to a hard-coded scratch directory: temporary workdirs come from `mktemp -d` and are removed by an `EXIT` trap.

## 0.1.2 (2026-10-06)

Backprop pass: every real error found so far became a machine-checked invariant, so it cannot return silently. Host-side only; still **not boot-tested on hardware**.

- New `SPEC.md`: bug registry (§B, B1–B13 with date, root cause and the invariant that prevents it), invariants V1–V9 (§V, testable phrasing + the file that protects each), open tasks (§T: boot on `lake`, `fastboot boot`, A/B fallback, Wi-Fi/BT, thermal stress, `pstore` after a panic) and the convergence criterion for the adversarial review (two consecutive rounds with no new concrete finding).
- New checks (all read-only, `mktemp` only): `tools/check_docs_numbers.sh` (V1: documented corpus numbers must equal `tools/gate_kmi_crc.sh` output and `tools/data/*.tsv`), `tools/check_regex_controls.sh` (V2: every documented `grep -E` needs a positive *and* a negative control; `\|` inside `-E` is rejected), `tools/check_protocol_invariants.sh` (V3/V4/V5/V7/V8), `tools/check_destructive_ops.sh` (V6), `tools/selftest_fetch.sh` (V9), plus `tools/run_all_checks.sh` (summary per invariant, exit ≠ 0 on failure) and `tools/selftest_backprop.sh` (10 sabotage cases, each proven FAIL→PASS).
- New fixtures `tests/fixtures/dmesg_bad.txt`, `dmesg_clean.txt`, `sha256sums_bad.txt`, `sha256sums_clean.txt` as the controls those checks run against.
- Real defects the new checks exposed and that are now fixed: the protocol's dmesg acceptance had no runnable command (B10, command block added, with its own host-side controls); six absence claims in `SAFETY.md`/`DEVICE-TEST-PROTOCOL.md` rested on a single observation (B11, each now cites two independent sources); `tools/verify_modsig.sh` used `grep -i "serial\|issuer"` (B12, now `-iE`); `KMI-GATES.md` asserted the protected-exports set with no source (B13, now cites `android/abi_gki_protected_exports_aarch64` and facts 37).
- `tools/fetch_official_artifacts.sh` gained `--dry-run`, which prints the viewer URL it would request and writes nothing — the URL V9 verifies is the script's own, not a copy.
