# poco-c75-lake-kernel

**rebuild-reproducible, gate-verified build of the Android GKI 6.6.89 kernel used by the POCO C75 4G / Redmi 14C 4G (`lake`, MediaTek MT6768/MT6769) — with host-side gates recommended before any device write. `tools/fastboot_guard.sh` checks three words, size, sha256, magic, and `partition-size:boot_b`; it does not check those gate results. Device boot is not yet tested. All verification below is host-verified; hardware behavior is hardware-unverified and booting remains boot-unproven until a real device run is logged.**

**rebuild-reproducible** means the control build matches stock symvers, config, and Image size. It does not mean a bit-identical Image. `common` is pinned by a tag; that tag's SHA is recorded and not enforced.

![status](https://img.shields.io/badge/status-experimental-orange) ![kernel](https://img.shields.io/badge/kernel-6.6.89--android15--8-blue) ![soc](https://img.shields.io/badge/SoC-MT6768%2FMT6769-lightgrey) ![license](https://img.shields.io/badge/license-MIT-green)

> [!WARNING]
> **Not boot-tested yet.** Two kinds of check live here: host gates, re-runnable from this repo, and read-only measurements of one audited device. Those device numbers need the unpublished dump. No image from this project has been booted on hardware at the time of writing, so **no flashable images are published**. Flashing a kernel can bootloop or brick a device. Read [`docs/SAFETY.md`](docs/SAFETY.md) first. You are responsible for your device.
>
> **Every device measurement below is device-specific:** they were taken on one audited POCO C75 4G (`lake`, slot `_b`, `OS3.0.306.0`, bootloader **unlocked**, `verifiedbootstate=orange`). Different firmware, a different slot or a **locked** bootloader can change the outcome — re-measure before trusting any number here on your device.

## Why this exists

Xiaomi has not published kernel source for the `lake` device, and community kernels for it are mostly unverified claims. This project started from a different question: *what kernel is the device actually running?* The answer turned out to be much better than expected.

## Key findings (measured on the audited device except where the Evidence column says otherwise; log in [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md))

| Finding | Evidence |
|---|---|
| The device runs **Google's unmodified GKI** kernel: its `Image` is byte-identical to the public CI build `13771415` (`android15-6.6-2025-06_r12`, commit `5a0ffb447c1d…`). The device Image dump is unpublished. | `cmp` + sha256 `a023b4fd…bbaca`, recorded in `docs/PLAN-AND-FINDINGS.pt-BR.md` |
| The kernel **config is exactly known**: `zcat /proc/config.gz` (the decompressed text) is byte-identical to Google's build `.config`. The gzip bytes themselves hash differently. | sha256 of the plain text `9b544345…eb19ec` |
| All device-specific code lives outside the GKI kernel: closed vendor modules (557 `.ko` files = 370 distinct modules), plus device tree/DTBO, firmware blobs, boot metadata and userspace — this project tracks the `.ko` interface; DTBO, firmware, boot metadata, and userspace are out of scope | `modinfo` / ELF parsing — `tools/data/modules_inventory.tsv` |
| The host CRC gate checks the **2309 symbols the modules require** from vmlinux (CRC, presence, export_type, namespace): 0 mismatches on the reference symvers. The other stock exports (8795 - 2309) are not compared. Full symvers identity is a `cmp` of the control build only ([`docs/BUILD.md`](docs/BUILD.md) §2); the cert build has no such `cmp` recorded here. Whether the closed modules load on a device is not yet tested. | `tools/gate_kmi_crc.sh` on all 557 `.ko`: `compared=2309` `mismatches=0` |
| A rebuilt kernel has a new ephemeral signing key. With `CONFIG_MODULE_SIG_PROTECT`, a module the kernel cannot verify loses `sig_ok` when it imports a protected symbol. In this inventory those imports are Wi-Fi only (`cfg80211.ko`, `mac80211.ko`). Bluetooth on a device was not measured. **Fix:** embed Google's public module-signing certificate via `CONFIG_SYSTEM_TRUSTED_KEYS`. | source analysis + controlled signature experiment |
| The vermagic *version string* does **not** need to match (`same_magic()` ignores it when modules carry CRCs). | `common/kernel/module/version.c` |

## What is verified, and what is not

| Gate | Result |
|---|---|
| Source manifest lists 36 projects (`grep -c '<project' manifests/manifest_13771415.xml`). 35 revisions are SHA-checked at the end of sync. `common` is pinned by the mutable tag `android15-6.6-2025-06_r12`; the resolved SHA is written to the sync record and is not enforced. clang `r510928`. | ✅ for the 35 SHA pins; tag pin recorded, not enforced |
| Control build (no changes): `vmlinux.symvers` byte-identical to Google's, measured per PLAN fact 60 | ✅ command in [`docs/BUILD.md`](docs/BUILD.md) §2 |
| Control build: `.config` identical to the device config | ✅ |
| Cert build: only difference vs stock config is `CONFIG_SYSTEM_TRUSTED_KEYS` | ✅ |
| Per-symbol CRC gate against **all 557 vendor `.ko` (370 unique modules)**: 4138 symbols required, 2309 provided by the kernel | ✅ 0 mismatches, 0 missing — `tools/gate_kmi_crc.sh` |
| Host: `tools/verify_modsig.sh --selftest` checks official `can.ko` against the **official** Image and rejects a one-byte change. It does not verify a locally built Image. The cert-build command is [`docs/BUILD.md`](docs/BUILD.md) §4 (`dist_cert/Image` against `official/can.ko`); no result of that command is stored in this repo. | ✅ for the official pair only |
| Gate self-test: 1 positive + 4 sabotage cases (corrupted CRC, dropped export, empty symvers, export_type mismatch) and 1 exact-key case (a symbol that differs only by a prefix does not match: `mutex_lock` vs `mutex_lockX`) | ✅ `tools/selftest_gates.sh` |
| Documentation invariants (§V, one executable check per row). A planted defect makes its check FAIL; the clean tree PASSes. `tools/selftest_backprop.sh` prints that flip as FAIL->PASS. | ✅ `tools/run_all_checks.sh` |
| Boot-image repack refuses truncated input, non-gzip kernel, `ramdisk_size != 0`, existing output, oversize image, and drops the GKI signature block only with `--drop-signature`. Published tests: `tests/test_repack_boot.py` (11). The author's 32-case harness (PLAN fact 57) is **not** published. | ✅ `tests/test_repack_boot.py` via `tools/selftest_python.sh` |
| **Image boots on a real `lake` device** | ❌ **not yet tested** |
| Wi-Fi / Bluetooth / modem / camera working with the new kernel | ❌ not yet tested |

The rebuilt `Image` is **not** byte-identical to Google's (the ephemeral signing key and version banner change the layout). The host check of the module interface is the 2309 symbols the modules require, not every export.

## Repository layout

```
SPEC.md      bug registry (§B), testable invariants (§V), what is still unproven (§T)
docs/        BUILD, KMI gates, SAFETY, device test protocol, measured-facts plan, research notes
tests/       fixtures (dmesg_bad/clean, sha256sums_bad/clean) and tests/test_*.py (repack, dump_modcrcs, modsig)
tools/       gate_kmi_crc.sh, selftest_gates.sh, dump_modcrcs.py, verify_modsig.sh, repack_boot_v2.py, fetch_official_artifacts.sh,
             fastboot_guard.sh, run_all_checks.sh, check_docs_numbers.sh, check_regex_controls.sh, check_protocol_invariants.sh,
             check_destructive_ops.sh, check_sigpipe.sh, check_config_table.sh, check_build_claims.sh,
             selftest_fetch.sh, selftest_fetch_publish.sh, selftest_fastboot_guard.sh, selftest_python.sh, selftest_backprop.sh
patches/     Kleaf + common patches that embed the Google module-signing certificate
certs/       Google GKI module-signing certificate (public)
manifests/   official CI manifest + pinned variant used here
data/        official vmlinux.symvers, KMI symbol lists, config safety table
tools/data/  per-module required CRCs (all 557 .ko) and the module inventory
scripts/     build.sh (exact commands used)
.github/     workflows/host-checks.yml — host-only CI (syntax, invariants, sabotage). It does not sync or build the kernel.
```

## Quick start (host only — nothing touches a device)

```bash
# 1. fetch public Google artifacts (no login; sha256-checked) and self-test the signature tooling
tools/fetch_official_artifacts.sh Image can.ko   # → official/{Image,can.ko}, hashes verified
tools/verify_modsig.sh --selftest                # → SELFTEST PASS

# 2. self-test the KMI gate itself (1 positive + 4 sabotage cases + 1 exact-key case) and the doc invariants
tools/selftest_gates.sh                          # → SELFTEST PASS
tools/run_all_checks.sh                          # → PASS (all §V invariants + gate self-test; see SPEC.md)
tools/selftest_backprop.sh                       # → each §V check catches its own defect; the CRC gate's own selftest is tools/selftest_gates.sh

# 3. get the pinned source (≈12 GB) and build — environment variables and clean/record are in docs/BUILD.md
scripts/build.sh sync
scripts/build.sh control     # unmodified build → must match Google's symvers/config
scripts/build.sh cert        # patched build with Google's cert embedded

# 4. check the 2309 required symbols against the cert-build symvers
tools/gate_kmi_crc.sh "$HOME/lake-build/out/dist_cert/vmlinux.symvers"
# → modules.files=557 modules.unique=370
#   symbols.required=4138 symbols.reference_exports=8795 symbols.reference_provides=2309
#   compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0
#   export_type_mismatches=0 namespace_mismatches=0
#   PASS
```

Requirements: Linux x86-64, 80 GiB free disk (the script requires 83886080 KiB), 12+ GB RAM (6 cores recommended), `git`, `python3`, `curl`, `openssl`, `avbtool`, `unpack_bootimg` (AOSP mkbootimg; used when checking a repacked image), and Google's `repo` launcher (needed by `scripts/build.sh sync`, see [`docs/BUILD.md`](docs/BUILD.md)).

## Customizing

You can change anything that does not alter the exported kernel interface. Every change is a new build that must pass the gates in [`docs/KMI-GATES.md`](docs/KMI-GATES.md); the device-facing route (recovery rehearsal Z0, read-only checks, two protected writes of `boot_b` (T-1 backup, T3 kernel)) is defined in [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md) — there is **no RAM-boot step**: the legacy `fastboot boot` path was discarded because a v2 image carries no `androidboot.*`/`slot_suffix`, and a slot-less boot could mount the old system of slot A over the current data. What *cannot* be changed by kernel options alone: anything implemented in the closed vendor modules (CPU/GPU DVFS tables, thermal policy, overclocking). `data/config_safety_table.csv` lists config options by risk.

> [!IMPORTANT]
> **Unlocked bootloader required.** `tools/repack_boot_v2.py` replaces the kernel and regenerates the AVB footer **unsigned** (`--footer-algorithm NONE`, the tool default, which avbtool receives as `--algorithm NONE`; `--rollback-index 0`, also the default; `--drop-signature` drops Google's 16 KiB GKI signature block, which cannot be re-signed). Such an image is only acceptable on a device whose bootloader is **unlocked** (`verifiedbootstate=orange`, e.g. the audited device). On a **locked** bootloader this image was not measured. Reading AVB suggests an unsigned footer would fail verification; that reading is untested. Do not flash it, and do not unlock a device to follow this project unless you accept that unlocking itself erases user data. The route from a host-approved image to a written partition is in [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md).

## Documentation

- [`docs/BUILD.md`](docs/BUILD.md) — reproducing the builds
- [`docs/KMI-GATES.md`](docs/KMI-GATES.md) — the verification gates and why they exist
- [`docs/SAFETY.md`](docs/SAFETY.md) — rules that protect the device
- [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md) — the (not yet executed) hardware test plan
- [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md) — full measured-facts log (Portuguese)
- [`docs/research/`](docs/research/README.md) — raw research notes (**contain errors, read the index first**)

## Resumo em português

Kernel GKI 6.6.89 do POCO C75 4G (`lake`): o aparelho roda o GKI oficial do Google sem modificações. Este repositório reconstrói, a partir do fonte público, um kernel cuja interface de módulos o gate compara (557 arquivos `.ko` fechados, 370 módulos únicos; 4138 símbolos exigidos, 2309 fornecidos pelo kernel, 0 divergências no host) e cuja config de texto acompanha o stock. A Image não é byte-idêntica. O certificado público do Google entra no contrato de assinatura verificado no host. Isso não prova que os módulos carregam no aparelho. **Ainda não foi testado no aparelho** — nenhuma imagem é publicada.

## License

Original tooling and docs: MIT. Patches and data derived from AOSP/Linux keep their upstream licenses — see [`NOTICE.md`](NOTICE.md).
