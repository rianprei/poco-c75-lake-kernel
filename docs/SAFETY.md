# Safety

Flashing kernels can bootloop or permanently brick a device. These rules come from measurements on a real `lake` device, not from assumptions.

## Hard rules

1. **Never touch** `preloader`, `lk`, `seccfg`, `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`. BROM/mtkclient recovery is **blocked** on this device (SLA/DAA/SBC enabled, `DL forbidden 0xc0020004`, see mtkclient #219): a damaged preloader has no public recovery path other than an authorized Xiaomi service.
2. **Back up first, with hashes.** Dump every relevant partition read-only, compare the host hash to the on-device hash, and keep a copy on a *different* disk. Never publish `nvram`/`nvdata`/`persist` (they hold IMEI and calibration data).
3. **Check what is in the other slot before switching slots.** On the audited device slot A held firmware *OS3.0.20.0* while slot B (running) was *OS3.0.306.0*. Switching to the other slot would have booted an old OS on top of newer user data. Do not use "the inactive slot" as a test slot without comparing the slot firmware (`avbtool info_image` on both `vbmeta` images).
4. **Test in RAM first.** `fastboot boot <image>` loads a kernel without writing anything; a hang is fixed by holding the power button. Its support on `lake` is **unknown** (the MediaTek LK source has the command; it is unverified on this device). If it is missing, nothing was changed — stop and reassess.
5. **Never choose "factory reset"** on any screen during recovery.
6. **Do not flash images you did not build and verify**, including binaries from third-party kernel repositories (several claim to support this device with no boot evidence).

## Why a modified boot image is plausibly accepted

On the audited device (bootloader unlocked, `verifiedbootstate=orange`) the Magisk-patched `init_boot_b` does **not** match the hash descriptor in `vbmeta_b` while `dtbo`, `vendor_boot` and the stock `init_boot_a` do (controls), and the device boots normally: the bootloader tolerates descriptor mismatches when unlocked. For the chained `boot` partition this is analogous but **unproven**.

## Recovery paths (when LK/preloader are intact)

| Path | Needs |
|---|---|
| `Vol− + Power` → fastboot → `fastboot flash boot_b <backup boot_b.img>` | unlocked bootloader, hash-verified backup |
| `Vol+ + Power` → stock recovery → `adb sideload` full OTA | OTA of the same region |
| `fastbootd` / Mi Flash with a fastboot ROM | matching fastboot ROM |

## Observability after a bad boot

`pstore/ramoops` is active on `lake` (parameters on the kernel command line; region injected by the bootloader), and MediaTek AEE/`mrdump` dumps to `expdb`. After returning to a working boot, read `/sys/fs/pstore/*` (readable by the `shell` user), `dmesg`, and `adb bugreport` (contains the kernel log, `console-ramoops` and `last_kmsg`) — none of which require root.
