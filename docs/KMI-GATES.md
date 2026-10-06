# Verification gates

A custom kernel is only acceptable if the **closed vendor modules still load**. These gates prove it offline, before any device is involved. All are scripted and have positive *and* negative (sabotage) tests.

## Why the vendor modules are the constraint

On `lake` the kernel image is Google's GKI; everything device-specific (display, modem, Wi-Fi, camera, DVFS, thermal…) lives in **557 `.ko` files** (153 loaded early from the `vendor_boot` ramdisk, the rest in `vendor_dlkm`). They are prebuilt against Google's exported symbols and are **not** recompiled. They depend on the kernel through three mechanisms:

1. **Exported symbols + CRCs** (`CONFIG_MODVERSIONS`). A module imports `symbol` with an expected CRC. If the kernel's CRC differs → `disagrees about version of symbol`; if the symbol is trimmed away → `Unknown symbol`.
2. **kCFI** (`CONFIG_CFI_CLANG`). The modules are compiled with kernel CFI; the kernel must keep it enabled (101 of 215 `vendor_dlkm` modules carry `__kcfi_typeid_*`). *Do not copy kernels that turn CFI off — those target devices whose modules are built without it.*
3. **Module signing / protected exports** (`CONFIG_MODULE_SIG_PROTECT`). See [`BUILD.md`](BUILD.md) §3.

The release string in the vermagic is **not** a constraint: `same_magic()` (kernel/module/version.c) skips the first token when the module has CRCs. Only the remainder (`SMP preempt mod_unload modversions aarch64`) must match.

## The gates

| Gate | What it proves | How |
|---|---|---|
| **G-CONFIG** | the build config equals the stock config (or differs only in intended lines) | `diff <(sort .config) <(sort config.stock)` |
| **G-SYMVERS** | exported symbol set and all CRCs equal Google's | `cmp vmlinux.symvers` |
| **G-CRC** | every CRC any of the 557 modules requires from the kernel equals the new kernel's | `tools/gate_kmi_crc.sh <new vmlinux.symvers>` |
| **G-EXPORTS** | no symbol the modules need (and stock exports) is missing | same script (`missing_exports`) |
| **G-CERT** | the Google-signed GKI modules verify against the new image | `tools/verify_modsig.sh` |
| **G-REPACK** | the boot image changed only where intended | `tools/repack_boot_v2.py` test suite |

`tools/gate_kmi_crc.sh` extracts `(symbol, CRC)` pairs from every module's `__versions` section (`tools/dump_modcrcs.py`), joins them with the new kernel's `vmlinux.symvers`, and fails on any mismatch or missing export. Measured on this project: **1573 symbols compared, 0 mismatches, 0 missing**. Sabotage tests: corrupting the CRC of `mutex_lock` → `FAIL` naming the symbol; dropping an export → `FAIL`.

## Inter-module symbols

4138 distinct symbols are imported by the modules: 1573 come from the kernel and are covered above; the rest are exported by *other vendor modules* (e.g. `mtk_cmdq_drv_ext`, `mediatek_drm`) and are unaffected by rebuilding the kernel. Nine symbols (`arc4_*`, `rfkill_*`) are *protected exports* provided by Google-signed GKI modules — the reason for the certificate in the cert build.
