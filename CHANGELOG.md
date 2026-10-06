# Changelog

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
- `tools/verify_modsig.sh` no longer writes to a hard-coded `/tmp/opencode`: temporary workdirs come from `mktemp -d` and are removed by an `EXIT` trap.
