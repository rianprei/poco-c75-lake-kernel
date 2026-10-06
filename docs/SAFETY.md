# Safety

Flashing kernels can bootloop or permanently brick a device. These rules come from measurements on a real `lake` device, not from assumptions.

## Hard rules

1. **Never touch** `preloader`, `lk`, `seccfg`, `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`. BROM/mtkclient recovery is **blocked** on this device (SLA/DAA/SBC enabled, `DL forbidden 0xc0020004`, see mtkclient #219): a damaged preloader has no public recovery path other than an authorized Xiaomi service (`docs/PLAN-AND-FINDINGS.pt-BR.md` fact 41; `research/ANTIGRAVITY3_recovery_sweep.md` §1–2).
2. **Back up first, with hashes.** Dump every relevant partition read-only, compare the host hash to the on-device hash, and keep a copy on a *different* disk. Never publish `nvram`/`nvdata`/`persist` (they hold IMEI and calibration data). **A partition backup does not contain your data**: `userdata` is not in this project's backup (measured: no `userdata`/`data.img` entry in `backup-2026-10-05/SHA256SUMS.log`; `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 21; `research/REVIEW3_codex_fmea.md` §2 measurement M5), so copy your photos/apps somewhere else before testing — a wipe is permanent.
3. **Check what is in the other slot before switching slots.** On the audited device slot A held firmware *OS3.0.20.0* while slot B (running) was *OS3.0.306.0*. Switching to the other slot would have booted an old OS on top of newer user data. Do not use "the inactive slot" as a test slot without comparing the slot firmware (`avbtool info_image` on both `vbmeta` images). Note that you do not have to *choose* the other slot for it to be reached: a `boot_b` that the bootloader marks unbootable can make the LK fall back to slot A by itself — see [`DEVICE-TEST-PROTOCOL.md`](DEVICE-TEST-PROTOCOL.md) step T2b.
4. **No RAM test in this protocol.** `fastboot boot <image>` would load a kernel without writing to flash, but its support on `lake` is **UNKNOWN** — two independent sources agree there is no evidence either way: the LK source and the real binary contain `cmd_boot` (`docs/SAFETY.md` LK table; never observed running here, `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 10). The **legacy v2-image RAM-boot was discarded outright** — it carries no `androidboot.*` (not even `slot_suffix`), and with no evidence that the LK injects them, the system could mount the old slot-A system over current data. `docs/DEVICE-TEST-PROTOCOL.md` has no `fastboot boot` step; its only write is the single protected T3 command.
5. **Never choose "factory reset"** on any screen during recovery. If a "data may be corrupt" screen appears, the only safe item is *Try again*.
6. **Do not flash images you did not build and verify**, including binaries from third-party kernel repositories (several claim to support this device with no boot evidence).

## What does *not* wipe your data (measured, so you do not panic)

A failed mount of `/data` does **not** format it. The device's own `fstab.mt6768` lists `/data` with `wait,check,formattable,latemount,checkpoint=fs,fileencryption=…v2,keydirectory=/metadata/…` and **no `wipe` flag** (no entry in the whole file has one). `formattable` means exactly that — the partition *may* be formatted by recovery, and a failed first-stage mount of a formattable partition is **logged and ignored**, not formatted (`system/core/init/first_stage_mount.cpp`; the device's own `fstab.mt6768` is quoted in `research/REVIEW3_codex_fmea.md` §2.1).

The legacy path that could format only does so when the partition is already blank or its encryption was interrupted — never because a partition full of data failed to mount (`system/core/fs_mgr/fs_mgr.cpp`, the `wiped = partition_wiped(...)` / `fs_mgr_do_format()` branch around lines 1632-1634 in the AOSP tree; the "wipe" decision requires `partition_wiped()` to be true, i.e. the partition is *already* wiped, or the encryption was interrupted). And the actual wipe path requires either a `--wipe_data` command written to the BCB or a human choosing *Factory data reset* (`bootable/recovery/recovery.cpp`).

Consequence for this project: the realistic data-loss vector is a **human** one (tapping the reset item on a corruption prompt), not a kernel that fails to mount `/data`. See `research/REVIEW3_codex_fmea.md` §2 for the full analysis and its citations.

## What we verified in the real bootloader (and what we did not)

Source: `strings -n 5 backup-2026-10-05/lk_b.img` run on the audited device's **real bootloader binary** during the 2026-10-06 review (the binary itself is retained with the other device dumps and is not published; the dump was also cached in a reviewer scratch dir at review time). Strings prove that a message **exists in the binary** — they do not prove when the code reaches it. Anything about *order of checks* or *runtime behaviour* that was taken from LK code of a **different** device (dguidipc/gemini-lk, MT6797) is labelled INFERRED (other device) and must not be cited as a property of this bootloader.

| Claim | Evidence in the real `lk_b.img` | Status |
|---|---|---|
| The LK refuses images larger than the target partition | `size too large, space small. image length[0x%llx], partition max size[0x%llx]` | MEASURED (string exists) — the *order* of this check relative to the write is **INFERRED (other device)**; the protocol therefore checks the size itself (pre-flight `0x4000000` / 67108864 B) instead of relying on it |
| Erasing `boot`/`preloader` is refused by the LK | `Forbidden to erase boot/preloader partition.` | MEASURED (string exists; runtime reachability UNVERIFIED until Z0-style rehearsal is logged) |
| Downloading to protected partitions is refused | `download for partition '%s' is not allowed`, `Flashing is not allowed for Controlled Partitions`, `failed to get download permission for partition '%s'` | MEASURED (strings exist) |
| Erasing controlled partitions is refused | `Erasing is not allowed for Controlled Partitions` | MEASURED (string exists) |
| Formatting protected partitions is refused | `format for partition '%s' is not allowed`, `failed to get format permission for partition '%s'` | MEASURED (strings exist) |
| Flashing the preloader requires auth | `flash preloader is not permitted.`, `Preloader auth failed!`, `Image platform not match with device!` | MEASURED (strings exist) |
| The protected-name set includes `preloader*`, `nvram`, `nvdata`, `persist`, `seccfg`, `proinfo`, `expdb` | those exact names appear in the binary's partition-name tables | MEASURED (names exist) — **`lk`, `misc` and `boot_para` do NOT appear explicitly** in any denylist-like list; do not assume they are protected (or unprotected) without a test |
| `boot`/`boot_b` are writable targets (not in the protected set) | `boot_b` appears as a partition name; no protected-list membership | MEASURED (absence from the name lists) — the protocol still writes **only** `boot_b`, once |
| `fastboot getvar is-userspace` answers `no` on this LK | the string `is-userspace` **does exist** in the binary's getvar table, but its runtime value on this device was never read | UNVERIFIED — the protocol accepts `no` **or `Variable not found`**; only `yes` (fastbootd) is a STOP |
| `fastboot boot` works on this bootloader | `cmd_boot` string exists (`cmd_boot,boot_hdr = NULL`); the message `not support flash` known from a reference LK does **not** exist here | UNVERIFIED — existence of the string is not support; no RAM-boot step in the protocol |
| The LK tests size before writing, allowlist before download, etc. | code from dguidipc/gemini-lk (MT6797), **not** this binary | **INFERRED (other device)** — never cite as a property of this bootloader |
| Reaching fastboot with `Vol− + Power` on a device whose `boot_b` is bad | never exercised (device untouched) | UNVERIFIED — that is exactly what the mandatory **Z0** rehearsal in `docs/DEVICE-TEST-PROTOCOL.md` tests, risk-free, before any write |

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
