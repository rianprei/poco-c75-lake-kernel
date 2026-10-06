# Safety

Flashing kernels can bootloop or permanently brick a device. These rules come from measurements on a real `lake` device, not from assumptions.

## Hard rules

1. **Never touch** `preloader`, `lk`, `seccfg`, `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`. BROM/mtkclient recovery is **blocked** on this device (SLA/DAA/SBC enabled, `DL forbidden 0xc0020004`, see mtkclient #219): a damaged preloader has no public recovery path other than an authorized Xiaomi service (`docs/PLAN-AND-FINDINGS.pt-BR.md` fact 41; `research/ANTIGRAVITY3_recovery_sweep.md` §1–2).
2. **Back up first, with hashes.** Dump every relevant partition read-only, compare the host hash to the on-device hash, and keep a copy on a *different* disk. Never publish `nvram`/`nvdata`/`persist` (they hold IMEI and calibration data). **A partition backup does not contain your data**: `userdata` is not in this project's backup (measured: no `userdata`/`data.img` entry in `backup-2026-10-05/SHA256SUMS.log`; `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 21; `research/REVIEW3_codex_fmea.md` §2 measurement M5), so copy your photos/apps somewhere else before testing — a wipe is permanent.
3. **Check what is in the other slot before switching slots.** On the audited device slot A held firmware *OS3.0.20.0* while slot B (running) was *OS3.0.306.0*. Switching to the other slot would have booted an old OS on top of newer user data. Do not use "the inactive slot" as a test slot without comparing the slot firmware (`avbtool info_image` on both `vbmeta` images). Note that you do not have to *choose* the other slot for it to be reached: a `boot_b` that the bootloader marks unbootable can make the LK fall back to slot A by itself — see [`DEVICE-TEST-PROTOCOL.md`](DEVICE-TEST-PROTOCOL.md) step T2b.
4. **Test in RAM first — if this bootloader supports it.** `fastboot boot <image>` is the mechanism designed to load a kernel without writing to flash, and a hang in a RAM boot is fixed by holding the power button. **Support on `lake` is UNKNOWN**: the MediaTek LK source contains `cmd_boot`, but this was never verified on this device (the public mirror is old and the runtime is untested) — `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 10 and `research/OPENCODE2_boot_safety.md` §1 both conclude "do not count on it". Treat the RAM path as a hypothesis: try it with the **stock-equivalent** image first, and if the bootloader answers `unknown command` (or any other `FAILED`), nothing was changed — stop and reassess, because without `fastboot boot` there is no low-risk test on this device.
5. **Never choose "factory reset"** on any screen during recovery. If a "data may be corrupt" screen appears, the only safe item is *Try again*.
6. **Do not flash images you did not build and verify**, including binaries from third-party kernel repositories (several claim to support this device with no boot evidence).

## What does *not* wipe your data (measured, so you do not panic)

A failed mount of `/data` does **not** format it. The device's own `fstab.mt6768` lists `/data` with `wait,check,formattable,latemount,checkpoint=fs,fileencryption=…v2,keydirectory=/metadata/…` and **no `wipe` flag** (no entry in the whole file has one). `formattable` means exactly that — the partition *may* be formatted by recovery, and a failed first-stage mount of a formattable partition is **logged and ignored**, not formatted (`system/core/init/first_stage_mount.cpp`; the device's own `fstab.mt6768` is quoted in `research/REVIEW3_codex_fmea.md` §2.1).

The legacy path that could format only does so when the partition is already blank or its encryption was interrupted — never because a partition full of data failed to mount (`system/core/fs_mgr/fs_mgr.cpp`, the `wiped = partition_wiped(...)` / `fs_mgr_do_format()` branch around lines 1632-1634 in the AOSP tree; the "wipe" decision requires `partition_wiped()` to be true, i.e. the partition is *already* wiped, or the encryption was interrupted). And the actual wipe path requires either a `--wipe_data` command written to the BCB or a human choosing *Factory data reset* (`bootable/recovery/recovery.cpp`).

Consequence for this project: the realistic data-loss vector is a **human** one (tapping the reset item on a corruption prompt), not a kernel that fails to mount `/data`. See `research/REVIEW3_codex_fmea.md` §2 for the full analysis and its citations.

## Why a modified boot image is plausibly accepted

On the audited device (bootloader unlocked, `verifiedbootstate=orange`) the Magisk-patched `init_boot_b` does **not** match the hash descriptor in `vbmeta_b` while `dtbo`, `vendor_boot` and the stock `init_boot_a` do (controls), and the device boots normally: the bootloader tolerates descriptor mismatches when unlocked. For the chained `boot` partition this is analogous but **unproven**.

**Unlocked is a requirement, not a detail.** A repacked image carries an unsigned AVB footer (`avbtool --algorithm NONE`, see [`BUILD.md`](BUILD.md) §5). On a **locked** device it will not pass verification at all — do not attempt this on a locked bootloader, and do not "unlock" a device to follow this project unless you accept that unlocking itself wipes user data.

## Recovery paths (when LK/preloader are intact)

| Path | Needs |
|---|---|
| `Vol− + Power` → fastboot → `fastboot flash boot_b <backup boot_b.img>` | unlocked bootloader, hash-verified backup |
| `Vol+ + Power` → stock recovery → `adb sideload` full OTA | OTA of the same region |
| `fastbootd` / Mi Flash with a fastboot ROM | matching fastboot ROM |

## Observability after a bad boot

`pstore/ramoops` is active on `lake` (parameters on the kernel command line; region injected by the bootloader), and MediaTek AEE/`mrdump` dumps to `expdb`. After returning to a working boot, read `/sys/fs/pstore/*` (readable by the `shell` user), `dmesg`, and `adb bugreport` (contains the kernel log, `console-ramoops` and `last_kmsg`) — none of which require root.
