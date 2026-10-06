# Changelog

## 0.1.0-experimental (2026-10-05)

First public snapshot. **Host-side verified only; not boot-tested on hardware.**

- Reproducible build recipe for the Google GKI `android15-6.6-2025-06_r12` kernel (6.6.89) used by POCO C75 4G (`lake`), pinned to the official CI manifest.
- Patches to embed the Google GKI module-signing certificate (`CONFIG_SYSTEM_TRUSTED_KEYS`) so stock `system_dlkm` modules keep `sig_ok=true`.
- Offline gates: `vmlinux.symvers` identity, per-symbol CRC check against 557 vendor modules, config diff, certificate check.
- Boot image repack tool (kernel swap, AVB footer regeneration) with 32-case adversarial test suite.
- Research notes and a measured-facts plan (`docs/PLAN-AND-FINDINGS.pt-BR.md`).
- No boot images are published.
