# poco-c75-lake-kernel

**Reproducible, gate-verified build of the Android GKI 6.6.89 kernel used by the POCO C75 4G / Redmi 14C 4G (`lake`, MediaTek MT6768/MT6769) — with the tooling to customize it safely.**

![status](https://img.shields.io/badge/status-experimental-orange) ![kernel](https://img.shields.io/badge/kernel-6.6.89--android15--8-blue) ![soc](https://img.shields.io/badge/SoC-MT6768%2FMT6769-lightgrey) ![license](https://img.shields.io/badge/license-MIT-green)

> [!WARNING]
> **Not boot-tested yet.** Everything here is verified on the host (offline gates). No image from this project has been booted on hardware at the time of writing, so **no flashable images are published**. Flashing a kernel can bootloop or brick a device. Read [`docs/SAFETY.md`](docs/SAFETY.md) first. You are responsible for your device.

## Why this exists

Xiaomi has not published kernel source for the `lake` device, and community kernels for it are mostly unverified claims. This project started from a different question: *what kernel is the device actually running?* The answer turned out to be much better than expected.

## Key findings (all measured, see [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md))

| Finding | Evidence |
|---|---|
| The device runs **Google's unmodified GKI** kernel: its `Image` is byte-identical to the public CI build `13771415` (`android15-6.6-2025-06_r12`, commit `5a0ffb447c1d…`). | `cmp` + sha256 `a023b4fd…bbaca` |
| The kernel **config is exactly known**: Google's build `.config` is byte-identical to `/proc/config.gz` of the device. | sha256 `9b544345…eb19ec` |
| All device-specific code lives in **closed vendor modules** (557 `.ko` files: 153 in the `vendor_boot` ramdisk, the rest in `vendor_dlkm`), not in the kernel. | `modinfo` / ELF parsing |
| A rebuilt kernel exports **exactly the same symbols and CRCs** as stock, so the closed modules keep loading. | `vmlinux.symvers` identical, 0 CRC mismatches |
| A rebuilt kernel has a new ephemeral signing key, so Google-signed GKI modules (`rfkill`, `libarc4`, `bluetooth`, …) would lose `sig_ok` and be refused as *protected exports* — breaking Wi-Fi/Bluetooth. **Fix:** embed Google's public module-signing certificate via `CONFIG_SYSTEM_TRUSTED_KEYS`. | source analysis + controlled signature experiment |
| The vermagic *version string* does **not** need to match (`same_magic()` ignores it when modules carry CRCs). | `kernel/module/version.c` |

## What is verified, and what is not

| Gate | Result |
|---|---|
| Source pinned to the official manifest (36/36 projects, clang `r510928`) | ✅ |
| Control build (no changes): `vmlinux.symvers` byte-identical to Google's | ✅ |
| Control build: `.config` identical to the device config | ✅ |
| Cert build: only difference vs stock config is `CONFIG_SYSTEM_TRUSTED_KEYS` | ✅ |
| Per-symbol CRC gate against all 557 vendor modules (1573 kernel symbols) | ✅ 0 mismatches |
| Google-signed module verifies against the new image; fails against the build without the cert | ✅ |
| Boot-image repack tool: 32 adversarial test cases | ✅ |
| **Image boots on a real `lake` device** | ❌ **not yet tested** |
| Wi-Fi / Bluetooth / modem / camera working with the new kernel | ❌ not yet tested |

The rebuilt `Image` is **not** byte-identical to Google's (the ephemeral signing key and version banner change the layout); the *interface to the modules* is.

## Repository layout

```
docs/        BUILD, KMI gates, SAFETY, device test protocol, measured-facts plan, research notes
tools/       gate_kmi_crc.sh, dump_modcrcs.py, verify_modsig.sh, repack_boot_v2.py, fetch_official_artifacts.sh
patches/     Kleaf + common patches that embed the Google module-signing certificate
certs/       Google GKI module-signing certificate (public)
manifests/   official CI manifest + pinned variant used here
data/        official vmlinux.symvers, KMI symbol lists, config safety table
scripts/     build.sh (exact commands used)
```

## Quick start (host only — nothing touches a device)

```bash
# 1. fetch public Google artifacts (no login) and self-test the signature tooling
tools/fetch_official_artifacts.sh && tools/verify_modsig.sh --selftest

# 2. get the pinned source (≈12 GB) and build — see docs/BUILD.md for every flag
scripts/build.sh sync
scripts/build.sh control     # unmodified build → must match Google's symvers/config
scripts/build.sh cert        # patched build with Google's cert embedded

# 3. prove compatibility with the closed vendor modules before anything else
tools/gate_kmi_crc.sh "$HOME/lake-build/out/dist_cert/vmlinux.symvers"
```

Requirements: Linux x86-64, ~80 GB free disk, 12+ GB RAM (6 cores recommended), `git`, `python3`, `curl`, `openssl`, `avbtool`.

## Customizing

You can change anything that does not alter the exported kernel interface. Every change is a new build that must pass the gates in [`docs/KMI-GATES.md`](docs/KMI-GATES.md) and be tested **in RAM (`fastboot boot`) before anything is written**. What *cannot* be changed by kernel options alone: anything implemented in the closed vendor modules (CPU/GPU DVFS tables, thermal policy, overclocking). `data/config_safety_table.csv` lists config options by risk.

## Documentation

- [`docs/BUILD.md`](docs/BUILD.md) — reproducing the builds
- [`docs/KMI-GATES.md`](docs/KMI-GATES.md) — the verification gates and why they exist
- [`docs/SAFETY.md`](docs/SAFETY.md) — rules that protect the device
- [`docs/DEVICE-TEST-PROTOCOL.md`](docs/DEVICE-TEST-PROTOCOL.md) — the (not yet executed) hardware test plan
- [`docs/PLAN-AND-FINDINGS.pt-BR.md`](docs/PLAN-AND-FINDINGS.pt-BR.md) — full measured-facts log (Portuguese)
- [`docs/research/`](docs/research/README.md) — raw research notes (**contain errors, read the index first**)

## Resumo em português

Kernel GKI 6.6.89 do POCO C75 4G (`lake`): o aparelho roda o GKI oficial do Google sem modificações, e este repositório reproduz esse kernel a partir do fonte público, embute o certificado do Google para que os módulos assinados continuem carregando, e traz os "gates" que provam a compatibilidade com os 557 módulos fechados. **Ainda não foi testado no aparelho** — nenhuma imagem é publicada.

## License

Original tooling and docs: MIT. Patches and data derived from AOSP/Linux keep their upstream licenses — see [`NOTICE.md`](NOTICE.md).
