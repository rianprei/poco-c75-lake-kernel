# Third-party notices

This repository contains original tooling and documentation (MIT, see `LICENSE`) plus small pieces derived from upstream projects. Each keeps its upstream license:

| Path | Origin | License |
|---|---|---|
| `patches/0001-*.patch` | Modifies `kernel/build` (Kleaf), AOSP | Apache-2.0 |
| `patches/0002-*.patch` | Modifies `common/BUILD.bazel` of the Android Common Kernel | GPL-2.0-only |
| `patches/system_trusted_key.patch` | Combined reference copy of the two patches above (not applied by any script — see `patches/README.md`) | Apache-2.0 + GPL-2.0-only |
| `manifests/manifest_13771415.xml` | Official AOSP kernel build manifest (public CI artifact) | Apache-2.0 |
| `data/official-vmlinux.symvers` | Public artifact of Google's GKI build 13771415 (derived from the Linux kernel) | GPL-2.0-only |
| `data/official-kernel_aarch64.config` | Public artifact: the `.config` of Google's GKI build 13771415 (derived from `gki_defconfig` + Kconfig) | GPL-2.0-only |
| `certs/google_gki_ab13771415_modsign_cert.pem` | Public X.509 certificate embedded in that build's kernel image (public key only, no private material) | n/a |
| `data/kmi_abi_union_r12.txt` | Symbol names from `android/abi_gki_aarch64*` in the kernel tree | GPL-2.0-only |
| `data/kmi_need_not_in_abi.txt` | Symbol names required by the device's own modules, as extracted for the ABI comparison | GPL-2.0-only |
| `data/config_safety_table.csv` | Risk table for config options, quoting the AOSP/GKI documentation and `gki_defconfig` | Apache-2.0 (quotations) |
| `tools/data/modules_required_crcs.tsv`, `tools/data/modules_inventory.tsv` | Derived data: symbol names, CRC values, module file names and vermagic strings from the device's own modules (no module code) | n/a (factual data) |

No proprietary binary (vendor modules, firmware, partition dumps, boot images) is included. `tools/data/modules_required_crcs.tsv` and `tools/data/modules_inventory.tsv` are derived data (symbol names, CRC values, module file names and vermagic strings) extracted with `tools/dump_modcrcs.py` from the device's own modules; they contain no module code.

"Xiaomi", "POCO", "Redmi", "MediaTek" and "Android" are trademarks of their owners; this project is not affiliated with them.
