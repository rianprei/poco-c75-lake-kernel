# poco-c75-lake-kernel

**Reproducible, gate-verified build of the Android GKI 6.6.89 kernel used by the POCO C75 4G / Redmi 14C 4G (`lake`, MediaTek MT6768/MT6769) — with the tooling to customize it safely.**

![status](https://img.shields.io/badge/status-experimental-orange) ![kernel](https://img.shields.io/badge/kernel-6.6.89--android15--8-blue) ![soc](https://img.shields.io/badge/SoC-MT6768%2FMT6769-lightgrey) ![license](https://img.shields.io/badge/license-MIT-green)

> [!WARNING]
> **Not boot-tested yet.** Everything here is verified on the host (offline gates). No image from this project has been booted on hardware at the time of writing, so **no flashable images are published**. Flashing a kernel can bootloop or brick a device. Read [`docs/SAFETY.md`](docs/SAFETY.md) first. You are responsible for your device.
>
> **Every device measurement below is device-specific:** they were taken on one audited POCO C75 4G (`lake`, slot `_b`, `OS3.0.306.0`, bootloader **unlocked**, `verifiedbootstate=orange`). Different firmware, a different slot or a **locked** bootloader can change the outcome — re-measure before trusting any number here on your device.

## Why this exists

Xiaomi has not published kernel source for the `lake` device, and community kernels for it are mostly unverified claims. This project started from a different question: *what kernel is the device actually running?* The answer turned out to be much better than expected.

## Key findings (all measured on the audited device, see [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md))

| Finding | Evidence |
|---|---|
| The device runs **Google's unmodified GKI** kernel: its `Image` is byte-identical to the public CI build `13771415` (`android15-6.6-2025-06_r12`, commit `5a0ffb447c1d…`). | `cmp` + sha256 `a023b4fd…bbaca` |
| The kernel **config is exactly known**: Google's build `.config` is byte-identical to `/proc/config.gz` of the device. | sha256 `9b544345…eb19ec` |
| All device-specific code lives in **closed vendor modules** (557 `.ko` files = 370 distinct modules: 342 ramdisk files from `vendor_boot` + 215 in `vendor_dlkm`, 17 names in both), not in the kernel. | `modinfo` / ELF parsing — `tools/data/modules_inventory.tsv` |
| A rebuilt kernel exports **exactly the same symbols and CRCs** as stock, so the closed modules keep loading. | `vmlinux.symvers` byte-identical to Google's; gate on all 557 `.ko`: 2309 kernel symbols compared, 0 mismatches |
| A rebuilt kernel has a new ephemeral signing key, so Google-signed GKI modules (`rfkill`, `libarc4`, `bluetooth`, …) would lose `sig_ok` and be refused as *protected exports* — breaking Wi-Fi/Bluetooth. **Fix:** embed Google's public module-signing certificate via `CONFIG_SYSTEM_TRUSTED_KEYS`. | source analysis + controlled signature experiment |
| The vermagic *version string* does **not** need to match (`same_magic()` ignores it when modules carry CRCs). | `kernel/module/version.c` |

## What is verified, and what is not

| Gate | Result |
|---|---|
| Source pinned to the official manifest (36/36 projects — `grep -c '<project' manifests/manifest_13771415.xml` — clang `r510928`) | ✅ |
| Control build (no changes): `vmlinux.symvers` byte-identical to Google's | ✅ |
| Control build: `.config` identical to the device config | ✅ |
| Cert build: only difference vs stock config is `CONFIG_SYSTEM_TRUSTED_KEYS` | ✅ |
| Per-symbol CRC gate against **all 557 vendor `.ko` (370 unique modules)**: 4138 symbols required, 2309 provided by the kernel | ✅ 0 mismatches, 0 missing — `tools/gate_kmi_crc.sh` |
| Google-signed module verifies against the new image; fails against the build without the cert | ✅ `tools/verify_modsig.sh --selftest` |
| Gate self-test: 1 positive + 3 sabotage cases (corrupted CRC, dropped export, empty symvers) | ✅ `tools/selftest_gates.sh` |
| Boot-image repack tool refuses truncated input, non-gzip kernel, `ramdisk_size != 0`, existing output, oversize image, and drops the GKI signature block only with `--drop-signature` | ✅ checks in `tools/repack_boot_v2.py` (the author's 32-case harness is **not** published) |
| **Image boots on a real `lake` device** | ❌ **not yet tested** |
| Wi-Fi / Bluetooth / modem / camera working with the new kernel | ❌ not yet tested |

The rebuilt `Image` is **not** byte-identical to Google's (the ephemeral signing key and version banner change the layout); the *interface to the modules* is.

## Repository layout

```
docs/        BUILD, KMI gates, SAFETY, device test protocol, measured-facts plan, research notes
tools/       gate_kmi_crc.sh, selftest_gates.sh, dump_modcrcs.py, verify_modsig.sh, repack_boot_v2.py, fetch_official_artifacts.sh
patches/     Kleaf + common patches that embed the Google module-signing certificate
certs/       Google GKI module-signing certificate (public)
manifests/   official CI manifest + pinned variant used here
data/        official vmlinux.symvers, per-module required CRCs (all 557 .ko), KMI symbol lists, config safety table
scripts/     build.sh (exact commands used)
```

## Quick start (host only — nothing touches a device)

```bash
# 1. fetch public Google artifacts (no login; sha256-checked) and self-test the signature tooling
tools/fetch_official_artifacts.sh Image can.ko   # → official/{Image,can.ko}, hashes verified
tools/verify_modsig.sh --selftest                # → SELFTEST PASS

# 2. self-test the KMI gate itself (1 positive + 3 sabotage cases) — no build needed
tools/selftest_gates.sh                          # → SELFTEST PASS

# 3. get the pinned source (≈12 GB) and build — see docs/BUILD.md for every flag
scripts/build.sh sync
scripts/build.sh control     # unmodified build → must match Google's symvers/config
scripts/build.sh cert        # patched build with Google's cert embedded

# 4. prove compatibility with the closed vendor modules before anything else
tools/gate_kmi_crc.sh "$HOME/lake-build/out/dist_cert/vmlinux.symvers"
# → modules.files=557 modules.unique=370
#   symbols.required=4138 symbols.reference_exports=8795 symbols.reference_provides=2309
#   compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0 / PASS
```

Requirements: Linux x86-64, ~80 GB free disk, 12+ GB RAM (6 cores recommended), `git`, `python3`, `curl`, `openssl`, `avbtool`, and Google's `repo` launcher (needed by `scripts/build.sh sync`, see [`docs/BUILD.md`](docs/BUILD.md)).

## Customizing

You can change anything that does not alter the exported kernel interface. Every change is a new build that must pass the gates in [`docs/KMI-GATES.md`](docs/KMI-GATES.md) and be tested **in RAM (`fastboot boot`) before anything is written**. What *cannot* be changed by kernel options alone: anything implemented in the closed vendor modules (CPU/GPU DVFS tables, thermal policy, overclocking). `data/config_safety_table.csv` lists config options by risk.

> [!IMPORTANT]
> **Unlocked bootloader required.** `tools/repack_boot_v2.py` replaces the kernel and regenerates the AVB footer **unsigned** (`--algorithm NONE`, and `--drop-signature` drops Google's 16 KiB GKI signature block, which cannot be re-signed). Such an image is only acceptable on a device whose bootloader is **unlocked** (`verifiedbootstate=orange`, e.g. the audited device). On a **locked** device it does not pass verification — do not flash it, and do not unlock a device to follow this project unless you accept that unlocking itself erases user data. The route from a tested image to a written partition is in [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md).

## Documentation

- [`docs/BUILD.md`](docs/BUILD.md) — reproducing the builds
- [`docs/KMI-GATES.md`](docs/KMI-GATES.md) — the verification gates and why they exist
- [`docs/SAFETY.md`](docs/SAFETY.md) — rules that protect the device
- [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md) — the (not yet executed) hardware test plan
- [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md) — full measured-facts log (Portuguese)
- [`docs/research/`](docs/research/README.md) — raw research notes (**contain errors, read the index first**)

## Resumo em português

Kernel GKI 6.6.89 do POCO C75 4G (`lake`): o aparelho roda o GKI oficial do Google sem modificações, e este repositório reproduz esse kernel a partir do fonte público, embute o certificado do Google para que os módulos assinados continuem carregando, e traz os "gates" que provam a compatibilidade com os 557 arquivos `.ko` fechados (370 módulos únicos; 4138 símbolos exigidos, 2309 fornecidos pelo kernel, 0 divergências). **Ainda não foi testado no aparelho** — nenhuma imagem é publicada.

## License

Original tooling and docs: MIT. Patches and data derived from AOSP/Linux keep their upstream licenses — see [`NOTICE.md`](NOTICE.md).
