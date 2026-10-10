# Device test protocol (Z0 logged 2026-10-09; T-1 and T3 not yet executed)

> Status: **Z0 logged 2026-10-09.** T-1 and T3 are planned, not run. Measured Z0 values are in the results section at the end of this file.

Images are built and verified on the host (`docs/BUILD.md`). Order matters — each step is only attempted if the previous one passed. Only two steps write anything to flash, and both are explicit below (T-1 rewrites identical bytes, T3 writes the new kernel); everything else writes nothing.

This protocol is written for the **audited device** (POCO C75 4G `lake`, slot `_b`, `OS3.0.306.0`, bootloader unlocked/`orange`). Every expectation below is labelled with where it was measured; anything not marked is a precondition you must confirm **on your own device before starting**. The adversarial analysis behind the mitigations is in [`research/REVIEW3_codex_fmea.md`](research/REVIEW3_codex_fmea.md) (28 scenarios). That note reviewed a discarded T0/T2 RAM-boot list; those steps are not part of this protocol (rule 1). What was verified **in the real bootloader binary** (and what was not) is tabulated in [`SAFETY.md`](SAFETY.md) §*What we verified in the real bootloader*.

## Read this first (brick / data-loss rules)

1. **`fastboot boot` is NOT part of this protocol.** A legacy-v2 RAM-boot path was **discarded** after review (see *Why the legacy RAM-boot is discarded* below), and support for `fastboot boot` on this bootloader is **UNKNOWN** — two independent sources agree there is no evidence either way: the command exists in the LK source and binary (`cmd_boot`, `docs/SAFETY.md` rule 4 and its LK table) and it was never demonstrated on this device (`docs/PLAN-AND-FINDINGS.pt-BR.md` fact 10, `research/OPENCODE2_boot_safety.md` §1). If a future revision ever re-introduces it and the bootloader answers `unknown command`, stop: nothing was transferred and nothing changed.
2. **Never choose "Factory data reset" on any screen.** If the device shows *"Can't load Android system. Your data may be corrupt"* with *Try again* / *Factory data reset*, choose **Try again** — and photograph the screen before touching anything. **Your backup does not contain `userdata`**, so a wipe is permanent loss of photos/apps/data (`research/REVIEW3_codex_fmea.md` §2, measurement M5: `grep -ciE "userdata|user_data" backup/SHA256SUMS.log` → 0; `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 21). **Back up your personal data first** (cloud/PC), before you even connect the cable.
3. **Never switch slots.** On the audited device slot A holds an **older firmware (OS3.0.20.0)** while slot B runs OS3.0.306.0, so booting slot A means an old OS on top of newer user data (`docs/PLAN-AND-FINDINGS.pt-BR.md` facts 62/64). Do **not** run `set_active`, and do not use "the inactive slot" as a test slot.
4. **Any `FAILED (...)` from fastboot is a STOP**, whatever the text says — do not improvise, do not retry with another cable "just once more", do not switch to a flash command. Note the exact message; it decides what can be tried another day. Absence is the bare string Variable not found with no FAILED ( in that answer. A line that contains FAILED ( is a STOP even when it also contains Variable not found.
5. **Every step before T3 writes nothing to flash, except T-1** — which rewrites the byte-identical backup (see below) and is itself gated like a write. If a command you are about to run is not in the table below, don't run it.

## Why the legacy RAM-boot is discarded (3 lines)

1. A legacy (v2-header) boot image carries no `androidboot.*` parameters — not even `slot_suffix` — and there is no evidence that this LK injects them on its `fastboot boot` path, so the system could come up **without knowing which slot it is on**.
2. That means Android could mount the **old system of slot A on top of the current data** — exactly the data-loss scenario this protocol exists to avoid (rule 3).
3. Therefore no instruction in this repository presents the legacy RAM-boot as a safe path; `fastboot boot` of the *stock-equivalent v4 repack* remains a **hypothesis** to be re-evaluated separately, never a default.

## Steps

### Z0 — recovery rehearsal (mandatory before any write; writes neither `boot` nor `lk`; does not prove recovery from a bad `boot_b`)

Purpose: prove, with the device **powered off** and using read-only fastboot commands only, that you can reach fastboot **by keys** and get back out — the exact motions you would need if a written `boot_b` ever failed. The mandatory Z0 (Z0.1–Z0.3) writes nothing; Z0.0 (optional, documentary) runs `adb reboot bootloader` which writes only the Android boot reason, nothing in boot/lk.

Preconditions (host): data cable to the PC, **charger disconnected** (advisory: a connected charger can park the LK in off-mode-charge instead of booting, which looks like a dead device; disconnect to remove the ambiguity — a connected charger alone never fails a gate); `adb` already authorized with exactly one device; hash-verified backup present; day baseline captured (`adb shell 'cat /proc/modules' | awk '{print $1}' | sort > baseline_modules.txt`); shell guard from *Host-side guard* active.

- **Z0.0 (optional, documentary):** `adb -s <serial> reboot bootloader` warms the path only; it is NOT the criterion (it writes a boot reason and follows a warm path, while T-1/T3 need the cold key path). The PASS criterion is Z0.1/Z0.2.
- **Z0.1:** Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable. PASS = fastboot screen visible. Anything else = STOP (without key-reached fastboot there is no recovery path for T-1/T3).
- **Z0.2:** `tools/fastboot_guard.sh devices` → exactly one device, else STOP.
- **Z0.3 (closed allowlist — run only these, nothing else, always through the guard):**
  `tools/fastboot_guard.sh getvar product`
  `tools/fastboot_guard.sh getvar current-slot`
  `tools/fastboot_guard.sh getvar slot-count`
  `tools/fastboot_guard.sh getvar is-userspace`
  `tools/fastboot_guard.sh getvar unlocked`
  `tools/fastboot_guard.sh getvar max-download-size`
  `tools/fastboot_guard.sh getvar partition-size:boot_b`
  `tools/fastboot_guard.sh getvar slot-successful:a`
  `tools/fastboot_guard.sh getvar slot-successful:b`
  `tools/fastboot_guard.sh getvar slot-unbootable:a`
  `tools/fastboot_guard.sh getvar slot-unbootable:b`
  `tools/fastboot_guard.sh getvar slot-retry-count:a`
  `tools/fastboot_guard.sh getvar slot-retry-count:b`
  `tools/fastboot_guard.sh getvar battery-soc-ok`
  `tools/fastboot_guard.sh getvar battery-voltage`
  **Forbidden**: `getvar all`, any `oem` (the real LK carries `oem allow-wipe-userdata`), anything outside this list.

  **Getvar answer policy** (absence is never false safety nor a false STOP):
  `required` (a missing/empty answer = STOP, do not advance): `product`,
  `current-slot`, `unlocked`, `slot-successful:*`, `slot-unbootable:*`,
  `partition-size:boot_b` (the write gate needs it).
  `optional` (record if answered, skip silently if the bootloader does not
  expose them): `slot-count`, `slot-retry-count:*`,
  `battery-soc-ok`, `battery-voltage`.
  `threshold-if-present`: `max-download-size`. If the bootloader answers, the
  value must be ≥ 67108864 (LK hex, optional 0x prefix, in bytes; 0x4000000 = 67108864; measured 0x8000000 = 134217728) or this step STOPs. If the answer is missing or
  `Variable not found`, record that and continue: absence is not a size pass,
  and the pre-flight file-size check still gates every write.
  `accepted-absent` (`Variable not found` is a valid answer, never a STOP):
  `is-userspace` only (`yes` = fastbootd → STOP). `slot-successful:*` and
  `slot-unbootable:*` stay `required`; they are not accepted-absent.
- **Z0.4 (PASS/STOP):** PASS when `product=lake`; `current-slot=b`; `is-userspace` is `no` or `Variable not found` (`yes` = fastbootd → STOP); `unlocked=yes`; `slot-successful:b` shows `yes`; `slot-unbootable:b` shows `no`; `partition-size:boot_b` parses as LK hex, optional `0x`/`0X` prefix, and equals 67108864 (`4000000` and `0x4000000` are the same value; measured 2026-10-09 as `4000000`). Record `slot-retry-count:b` as informational only — `0` is legitimate after a successful mark and never fails Z0. The 2026-10-09 readout was 1. `slot-successful:a` and `slot-unbootable:a` are record-only: any present value is not a value gate (a missing answer is still STOP). Any other answer to those PASS predicates: record it, do not advance to T-1/T3 that day. Exception: `current-slot` other than `b` → do not boot at all: **power off by keys** (long Power) and STOP for the day, never `fastboot reboot` — with `current-slot=a`, the *next boot* (a reboot **or** a power-off/power-on cycle) goes to the old slot A (rollback index 0 means the LK can boot old slot A — RE4 D3; that would boot OS3.0.20.0 over newer data).
- **Z0.5 (record twice):** save the full allowlist output as `z0_fastboot_before.txt` (+ photograph the screen). Capture both streams — fastboot answers on stderr: `{ for v in product current-slot slot-count is-userspace unlocked max-download-size partition-size:boot_b slot-successful:a slot-successful:b slot-unbootable:a slot-unbootable:b slot-retry-count:a slot-retry-count:b battery-soc-ok battery-voltage; do tools/fastboot_guard.sh getvar "$v"; done; } 2>&1 | tee z0_fastboot_before.txt`. STOP if z0_fastboot_before.txt lacks one answer per allowlist name; do not go to Z0.6 on an empty capture. Reference state for later slot readouts.
- **Z0.6 (exit):** `tools/fastboot_guard.sh reboot` only after Z0.4 passes. The guard itself runs `getvar current-slot` and `getvar is-userspace` and prints `desligue por teclas e encerre` unless current-slot is exactly b after trailing space and CR are removed (whitespace after the colon is not part of the value), and is-userspace is not yes. Wait for Android (3 min). Confirm: `adb devices` lists it again; `ro.boot.slot_suffix=_b`; `ro.product.device=lake`; `ro.build.version.incremental` the OS3.0.306.0 line; modules ⊇ day baseline (429 modules (example only); your number is your baseline). Device not lake: STOP, do not advance, do not unlock. slot not _b: power off, do not unlock, do not reboot. OS line mismatch: power off, do not unlock, report, do not reboot. modules not a superset: STOP, do not advance, and do not reboot when current-slot is not b. If adb is not back in 3 min: long Power 10–15 s → re-enter by keys → repeat Z0.3, then re-apply Z0.4 before reboot, then `tools/fastboot_guard.sh reboot` **once** only if Z0.4 passes; a second failure ends the day (no USB improvisation). If it boots a different slot/OS line: power off, do not unlock the screen, report, and do not reboot when current-slot is not b. Z0.6 is the exit of an isolated Z0. On a T-1 day do not run this reboot between Z0.4 and T-1.2; stay in fastboot until the flash.
- **Z0.7 (close):** log Z0.6 + keep `z0_fastboot_before.txt` as the reference for the pre-T-1 readout. Z0 PASS = Z0.1-Z0.4 green and Z0.6 shows ro.product.device=lake, slot _b, OS3.0.306.0, and modules superset of the day baseline.

**What Z0 does not prove (read before claiming confidence):** key-reached fastboot with a *bad* `boot_b`; acceptance of a v4 image; retry decrement/exhaustion; the exact Vol−↔code mapping; on-device fallback to slot A. Those stay UNVERIFIED. The 2026-10-09 run measured the healthy key entry (cable disconnected) and the 15 getvar values. "Does not fall to A" stays INFERRED. Risk remains.

Z0 PASS = Z0.1-Z0.4 green and Z0.6 shows ro.product.device=lake, slot _b, OS3.0.306.0, and modules superset of the day baseline. **Only after Z0 passes** may any later step be attempted on another day or the same day. If fastboot is not reachable by keys with a healthy device, **do not proceed**: every recovery path in this project depends on reaching fastboot, and that assumption is exactly what Z0 tests (healthy key entry and the getvar values are logged in the 2026-10-09 results; a bad `boot_b` stays UNVERIFIED).

### R3 / pre-flight (read-only identity checks)

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| R3 | in fastboot: `tools/fastboot_guard.sh getvar current-slot`, `unlocked`, `is-userspace`, `slot-count`, `max-download-size`, and the per-slot `slot-successful:*`, `slot-retry-count:*`, `slot-unbootable:*` when the bootloader exposes them | no | `current-slot=b` (**abort if ≠ b**), `is-userspace` accepts `no` **or `Variable not found`** (the string `is-userspace` **exists** in the LK getvar table; runtime value measured `no` on 2026-10-09 — `docs/SAFETY.md` LK table; `Variable not found` stays accepted), `is-userspace=yes` = **STOP** (you are talking to fastbootd, not the LK), `unlocked=yes`. `max-download-size`: if answered, it must be ≥ 67108864 (LK hex, optional 0x prefix, in bytes; 0x4000000 = 67108864; measured 0x8000000 = 134217728) or STOP; if absent, record and continue (same rule as Z0 `threshold-if-present`) |

### Pre-flight for the write (T3 gate) — all three must agree

```bash
# a) what the device says the partition is
tools/fastboot_guard.sh getvar partition-size:boot_b          # EXPECT: 0x4000000 or 4000000 (LK hex, both = 67108864 bytes). The guard reads partition-size:boot_b and compares it with the file size before it flashes.
# b) what the file is
stat -c%s boot_b_new.img                       # EXPECT: 67108864  (exactly; not one byte more or less)
sha256sum boot_b_new.img                       # EXPECT: the hash you recorded when building it
```

**Any divergence between (a), (b) and the recorded hash = PARAR.** The oversize protection must come
from *this* check, run by you — not from assuming the order of the bootloader's internal tests
(that order is **MEASURED** by disassembly of the real binary: check `bl 0x4c4367d2` precedes write `bl 0x4c436834`, fail branch returns first; see `research/RE1_opencode_flash.md` §3.3; reproduce host-side with `r2 -a arm -b 16 -m 0x4c3ffe00 -q -c 's 0x4c4367c8; pd 12; s 0x4c43688a; pd 6' lk_b.img`). The LK string
`size too large, space small. image length[0x%llx], partition max size[0x%llx]` exists in the real
binary, but you must not *rely* on reaching it.

### T-1 — write-path rehearsal with identical content (a write; gated like T3)

Purpose: demonstrate the flash path itself works — with bytes identical to what is already on
the device — before the new kernel is ever written. This is the first of the two write commands
of this protocol (T-1 identical content, T3 new kernel).

Only after **Z0 PASS**, and only with the owner's explicit "yes" on the day:

| T-1 | Action | Pass criteria |
|---|---|---|
| T-1.1 | On the host, confirm the backup file: `stat -c%s <path/to/backup/boot_b.img>` (= 67108864) and `sha256sum <path/to/backup/boot_b.img>` (= the hash YOU recorded when you made the backup; for the audited device that is `3890fb96…829fc7` in `SHA256SUMS.log`, a file that lives with your backup, not in this repo). This blocks T-1.1, not only T3: the backup also sits on a second physical disk. Copy with `cp`, then `sha256sum -c` on the destination; the criterion is that the hash matches on that disk | size exact, hash matches the recorded backup hash, and the second-disk `sha256sum -c` matches |
| T-1.2 | In fastboot (after R3): run `tools/fastboot_guard.sh flash boot_b <path/to/backup/boot_b.img>` (the T-1 line of *The two write commands* below, backup image, hash-gated). T-1 uses the **backup**; `boot_b_new.img` is only for T3. Interruption carries the same risk class as any flash (it rewrites the ACTIVE slot); Z0 PASS plus the battery/cable gates are what minimize it. On the T-1 day there is no Z0.6 reboot between Z0.4 and T-1.2; stay in fastboot until this flash. The day's `adb shell uname -r` is captured before this step | `OKAY`, no `FAILED (...)` |
| T-1.3a | `tools/fastboot_guard.sh reboot`. On Android, confirm the system is **unchanged**: `adb shell getprop ro.build.version.incremental` still the OS3.0.306.0 line, `adb shell uname -r` the stock kernel release. STOP if either changed. Do not run `getvar` in Android: fastboot is not listening. A missing fastboot device here is expected, not a slot-state change | build line and kernel release match the day's capture taken before T-1.2. Reference `uname -r` is MEASURED `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k` (source: PLAN fact 2) |
| T-1.3b | Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable, then read `tools/fastboot_guard.sh getvar slot-successful:b`, `slot-unbootable:b`, `slot-retry-count:b`, `current-slot`. If `getvar` sees no device, you are not in fastboot: re-enter by keys once; a second miss STOPs the day. Do not call that miss a slot change | gate is `slot-successful:b=yes`, `slot-unbootable:b=no`, and `current-slot=b`. Record `slot-retry-count:b` only; `0` is not a STOP. A change in those three gate values is a STOP |

**T-1 PASS** = T-1.1, T-1.2, T-1.3a and T-1.3b green. If the guard refuses, or T-1.2 returns `FAILED (...)` while the device is still in fastboot: the write not started: stop, no second flash, and T3 is off the table. A cable or power drop with no OKAY is not intact bytes: if FASTBOOT returns by keys, one flash of the verified backup through the guard and the day ends; if it does not return, that is L3. LK write atomicity is UNVERIFIED (RE1 does not disassemble the primitive).

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| T2b-pre | after T-1.3b, still in fastboot, **before** the T3 flash: re-read the six slot variables and compare with Z0.5 (capture both streams, fastboot answers on stderr: `{ ...; } 2>&1 | tee t2b_readout.txt`):<br>`tools/fastboot_guard.sh getvar slot-successful:a`<br>`tools/fastboot_guard.sh getvar slot-successful:b`<br>`tools/fastboot_guard.sh getvar slot-retry-count:a`<br>`tools/fastboot_guard.sh getvar slot-retry-count:b`<br>`tools/fastboot_guard.sh getvar slot-unbootable:a`<br>`tools/fastboot_guard.sh getvar slot-unbootable:b` | no | `slot-successful:b=yes` and `slot-unbootable:b=no`. Record `slot-retry-count:b`; `0` is informational only and is not a STOP. Any other successful/unbootable answer: stay in fastboot, do not flash T3, stop the day |
| T3 | only if T2b-pre is green **and the owner agrees**: the T3 line of *The two write commands*, with the verified backup as immediate rollback | **yes** | `OKAY` and no `FAILED (...)`. Do not reboot yet. The 30 min stress is acceptance after Android is up, not this pass criterion |
| T2b-post | still in fastboot after the T3 `OKAY`, before the first normal boot of the new image: the same six `getvar` commands, `{ ...; } 2>&1 | tee t2b_post_readout.txt` | no | same gate as T2b-pre (`slot-successful:b=yes`, `slot-unbootable:b=no`; retry recorded, `0` is not a STOP). Only then `tools/fastboot_guard.sh reboot` |

**The two write commands of this protocol** (paste them; never retype):

```bash
tools/fastboot_guard.sh flash boot_b <path/to/backup/boot_b.img>   # T-1: identical content (gates: Z0 PASS, owner yes, T-1.1 hash/size, guard hash+size+magic+partition-size+current-slot exactly b after trailing space and CR are removed+is-userspace!=yes)
tools/fastboot_guard.sh flash boot_b boot_b_new.img                 # T3: new kernel (gates: T-1 PASS, pre-flight, owner yes, guard hash+size+magic+partition-size+current-slot exactly b after trailing space and CR are removed+is-userspace!=yes)
```

**NEVER type** (not in this protocol, not "just to fix" anything):
`flash` on any other partition (`preloader*`, `lk*`, `seccfg`, `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `protect2`, `protect1`, `expdb`, `vbmeta*`, `vendor_boot*`, `init_boot*`, `dtbo*`, `system*`, `super`, `misc`, `boot_para`), `erase` (anything), `format` (anything), `oem` (anything), `flashing` (anything), `set_active` / `--set-active` (anything), `update`, `flashall`. The real LK strings confirm several of these are refused by the bootloader itself — *"Forbidden to erase boot/preloader partition."*, *"download for partition '%s' is not allowed"*, *"flash preloader is not permitted."* — but the protection you must count on is your own hands, not the bootloader: disassembly shows exactly two name lists — 7 controlled (`nvram`, `nvcfg`, `proinfo`, `nvdata`, `protect2`, `protect1`, `persist`) and 7 erase-forbidden (`preloader*`, `boot0`, `boot1`) — and `lk`, `seccfg`, `misc`, `boot_para`, `vbmeta`, `vendor_boot` are in neither (`docs/SAFETY.md`).

**Why T2b-pre and T2b-post exist** (FMEA-26): a partial boot can reach userspace, fail a health check and leave slot `_b` marked unbootable. Slot selection skips a slot whose priority nibble is 0. Whether that boot then reaches slot A is INFERRED, not observed. Risk remains: slot A on this device is old firmware. T2b-pre reads the slot after the T-1 normal boot and before the T3 flash. T2b-post reads it again after the T3 `OKAY`, still in fastboot, before `reboot`. If `_b` looks unhealthy: stay in fastboot, photograph the screen and the allowlist, and stop the day. Do not treat `slot-retry-count:b=0` as that unhealthy mark.

**T3 warning, in full.** Writing `boot_b` is the step that changes flash content for the first time (T-1 only rewrites identical bytes, and only after T-1 PASS does T3 become eligible). If the written image does not boot, AOSP boot_control skips a slot whose priority nibble is 0. This LK reads that nibble during slot selection: `0x4c42cae2` calls `0x4c453df8` for `_a` and `0x4c42cb02` calls it for `_b` (`ldrb r0, [r4, -0x14]`; `ands r0, r0, 0xf`; `it ne`; `movs r0, 1`); `cmp r0, 0` / `ble.w` skips the slot when the nibble is 0. Both slots invalid reach `fastboot_init` at `0x4c42b266` (RE4 D2), a non-returning USB halt loop. Slot A is MEASURED `unbootable=yes`, `successful=no`, retry-count 0, so an AOSP-style skip of A is what that read does. "Does not fall to A" is INFERRED until observed. Risk remains. The old slot A is **OS3.0.20.0 over data created by OS3.0.306.0**. `slot-retry-count:b` is MEASURED 1. How many failed boots mark `b` unbootable is INFERRED: `tries_remaining` is the 3-bit field (`ubfx r0, r0, 4, 3` in `get_retry_count` at `0x4c453d30`) and the decrement was not isolated (RE4 D1), so one failure can exhaust a count of 1. At the first boot loop the operator does: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable, and reflashes the verified backup. Before T3 you must have: **Z0 passed**, **T-1 passed**, **T2b-pre passed**, the firmware comparison below, the R3/T2b-pre slot readouts saved, `boot_b` + `init_boot_b` + `vbmeta*_b` backups verified on a second disk, Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable for the fastboot rollback (the T-1 command above, backup image), and the owner's explicit "yes". If the device does fall back to slot A, do **not** fight it with slot commands: power off and re-read the slot state in fastboot (run the Z0.3 allowlist again: `tools/fastboot_guard.sh getvar slot-successful:a`, `tools/fastboot_guard.sh getvar slot-successful:b`, `tools/fastboot_guard.sh getvar slot-retry-count:a`, `tools/fastboot_guard.sh getvar slot-retry-count:b`, `tools/fastboot_guard.sh getvar slot-unbootable:a`, `tools/fastboot_guard.sh getvar slot-unbootable:b`). The second-disk copy is a precondition of T-1.1, not only of T3. For this owner it is MEASURED satisfied on 2026-10-09 (44/44 hash-equal after drop_caches, boot_b `3890fb96…829fc7`, private research, not published).

## Preconditions

- USB **data** cable, battery ≥ 60 %, screen on, device unlocked, `adb` authorized.
- Identity check: `ro.product.device=lake`, `ro.boot.slot_suffix=_b`, `ro.boot.flash.locked=0`, `ro.boot.verifiedbootstate=orange`, `ro.build.version.incremental=OS3.0.306.0…`. **Any divergence → STOP** (`research/REVIEW3_codex_fmea.md` FMEA-06). The audited values are the ones written on this line; the raw `getprop` transcript is not published.
- **Both slots' firmware compared before anything else** — run `avbtool info_image` on `vbmeta_a` and `vbmeta_b` and confirm the inactive slot is the *same* firmware line, or **accept in writing** (type in the terminal: `I accept that slot A is older firmware OS3.0.20.0 and fallback would boot old OS over new data`) that it is older and that a fallback to it would boot old firmware over new data (SAFETY rule 3).
- Hash-verified backup of `boot_b`, `init_boot_b`, `vendor_boot_b`, `dtbo_b`, `vbmeta*_b` on a second physical disk. This blocks T-1.1, not only T3. Copy with `cp`, then `sha256sum -c` on the destination; the criterion is that the hash matches on that disk. For this owner the copy is MEASURED 2026-10-09 (separate physical NTFS disk, 44/44 hash-equal after drop_caches, boot_b `3890fb96…829fc7`; private research, not published). Plus the state readouts of step R3 below.
- **Baseline captured on the day** (order: host guard files first, then adb baseline with the cable, then unplug for Z0.1; never reuse an old file): `adb shell 'cat /proc/modules' | awk '{print $1}' | sort > baseline_modules.txt` — on the audited device this is 429 modules (example only), but your number is *your* baseline (FMEA-08); also `adb shell dmesg > baseline_dmesg.txt` and record `adb shell ls -l /sys/fs/pstore` (expected: `console-ramoops-0`, `pmsg-ramoops-0`).

## Host-side guard (host guard files first, then adb baseline with the cable, then unplug for Z0.1)

READONLY vs WRITE split: every fastboot command in this protocol is read-only
(`devices`, `reboot`, `getvar` on the closed allowlist) **except** the two write
commands in *The two write commands* above — and those run **only** through the
exact-allowlist wrapper below, never bare, never via a shell function. A shell
`fastboot()` denylist is weak (a `command` bypass prefix, an absolute path, or a fresh
shell bypasses it silently), so this protocol does not use one.

```bash
# 1. T-1 day: ONLY the backup hash. One sha256 per line. The guard
#    refuses any flash whose file hash is not listed here.
#    The next command is T3 day only, not on the T-1 day.
sha256sum <path/to/backup/boot_b.img> | cut -d' ' -f1 > guard_hashes.txt
sha256sum boot_b_new.img | cut -d' ' -f1 >> guard_hashes.txt   # T3 day only, not on the T-1 day
export FASTBOOT_GUARD_HASHES="$PWD/guard_hashes.txt"
# 2. prefix EVERY fastboot invocation below with: tools/fastboot_guard.sh
#    (forbidden by the closed allowlist — e.g. `tools/fastboot_guard.sh getvar all` prints
#    "BLOQUEADO pelo fastboot_guard: getvar 'all' fora da allowlist" and runs nothing)
```

The guard stays active for R3/Z0/T2b; the T-1/T3 commands run through it after
re-reading the pre-flight checks out loud (the wrapper re-verifies hash, exact
size 67108864, the `ANDROID!` magic, current-slot exactly `b` after trailing space and CR are removed (whitespace after the colon is not part of the value), and is-userspace not `yes` on every flash). The LK's own denylist
strings (`docs/SAFETY.md`) are a second layer, not a substitute.

## Acceptance (all required)

- `uname -r` shows the new kernel; `sys.boot_completed=1`.
- `/proc/modules` module-name set ⊇ your baseline captured today.
- `dmesg` has **no** `Unknown symbol`, `disagrees about version`, `exports protected symbol`, `Invalid module format`, `kCFI`/panic — verified by the command in *Acceptance commands* below (not by eye).
- `wlan0` up and connected; Bluetooth turns on; SIM registers; display/touch/audio/camera/GPU/sensors work; charging works.
- All checks above work **without root** (`adb shell`, `adb bugreport`).
- First normal boot also confirms `ro.build.version.incremental` is still the OS3.0.306.0 line — if it is not, the device booted the **other slot**: power off, do not unlock the screen, and reassess (FMEA-26).

### Acceptance commands (copy them, never retype)

```bash
# 1. kernel log: module-loading errors and panics. EXPECT: no output on the device (grep exits 1)
adb shell 'dmesg | grep -iE "Unknown symbol|disagrees about version|exports protected symbol|Invalid module format|kCFI|BUG: kernel NULL pointer|Kernel panic"'
#    control that the pattern itself works, on the host, before trusting it:
grep -iE "Unknown symbol|disagrees about version|exports protected symbol|Invalid module format|kCFI|BUG: kernel NULL pointer|Kernel panic" tests/fixtures/dmesg_bad.txt    # must print lines
grep -iE "Unknown symbol|disagrees about version|exports protected symbol|Invalid module format|kCFI|BUG: kernel NULL pointer|Kernel panic" tests/fixtures/dmesg_clean.txt   # must print nothing

# 2. module set is a superset of the baseline captured today
diff <(adb shell 'cat /proc/modules' | awk '{print $1}' | sort) baseline_modules.txt

# 3. identity and build line (must still be the OS3.0.306.0 line, not the other slot)
adb shell getprop ro.build.version.incremental; adb shell uname -r; adb shell getprop sys.boot_completed
```

`tools/check_regex_controls.sh` keeps these patterns honest: each one must match a planted bad log
(`tests/fixtures/dmesg_bad.txt`) and nothing in a clean one (`tests/fixtures/dmesg_clean.txt`), and
`\|` inside a `-E` pattern is rejected outright (a literal pipe never matches — that is how this
acceptance once passed on nothing).

## Abort criteria

Any hang > 3 minutes without UI, any panic, any missing baseline module, any `FAILED` from fastboot, any failed acceptance item, **any screen mentioning corrupted data** → hold power to reboot (do not touch the screen), capture `pstore`/bugreport from the next normal boot on a good kernel, and stop. One anomaly = the day ends: no second attempt, no "different cable", no improvised command. Exception: current-slot other than b: do not reboot; power off by keys and leave it off.

### If something goes wrong (symptoms & exact actions)

| Symptom | Exact action (protocol/SAFETY line) |
|---------|--------------------------------------|
| **Tela preta / não liga** | Power 10–15 s (forced off). Tente Z0.1 de novo. Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable. Se fastboot não aparece → **PARAR**, dia acaba (PROTO:32#Power, PROTO:200#corrupted). |
| **Logo em loop (bootloop)** | Power 10–15 s → off. Entre no fastboot por teclas. Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable. Se T-1/T3 já rodou: rollback `tools/fastboot_guard.sh flash boot_b <backup>`. Se não rodou T-1/T3: Z0.1 de novo. Se não resolve → PARAR (PROTO:118#reboot, PROTO:200#corrupted). |
| **Entra no recovery (stock / "Android com triângulo")** | **NUNCA** escolha "Factory data reset". Escolha **Try again**. Fotografe antes de tocar. Backup **não tem userdata** (SAFETY:8#userdata) — wipe = perda permanente (PROTO:12#userdata, SAFETY:11#factory). |
| **Cai no sistema antigo (OS3.0.20.0 / slot A)** | **Power off** (Power longo). **Não desbloqueie a tela**. Não use `set_active`. Releia estado no fastboot (Z0.1 + Z0.3). Relate (PROTO:13#set_active, PROTO:132#OS3, SAFETY:9#OS3). |
| **Fastboot não aparece no PC (`fastboot devices` vazio)** | Cabo USB de dados já conferido antes do Z0. Sem outro cabo. Z0.2 empty ends the day, no other port. Aparelho realmente no fastboot? Se sim e vazio → driver/udev no PC. Não improvise. Se Z0.2 falha → PARAR (PROTO:33#devices). |
| **`fastboot getvar current-slot` ≠ `b`** | **Exceção Z0.4** (desligue por teclas, nunca dê boot — o próximo boot iria ao slot A antigo) (PROTO:66#current-slot). |
| **`is-userspace=yes` (fastbootd)** | **PARAR** — você está falando com fastbootd, não com o LK (PROTO:64#fastbootd, SAFETY:38#fastbootd). |
| **Qualquer `FAILED (...)` do fastboot** | **PARAR imediato** (regra 4). Não reforce, não troque cabo, não mude para flash. Anote a mensagem. Absence is the bare string Variable not found with no FAILED ( in that answer. (PROTO:14#FAILED, PROTO:200#FAILED). |
| **Tela "Can't load Android... corrupt" + Try again / Factory data reset** | Escolha **Try again**. Fotografe antes de tocar. Backup **não tem userdata** (SAFETY:8#userdata) — wipe = perda permanente (PROTO:12#Try, SAFETY:11#Try). |
| **`fastboot boot` → `unknown command`** | **PARAR** — nada transferido, nada mudou. Legado RAM-boot descartado (PROTO:11#UNKNOWN). |
| **Tela "corrupted data" / "data may be corrupt"** | Power hold para reiniciar (não toque na tela), unless current-slot other than b: do not reboot; power off by keys and leave it off. Capture `pstore`/bugreport no próximo boot normal. **Pare** — uma anomalia = dia acaba (PROTO:200#corrupted). |
| **`slot-unbootable:b` = `yes` (em T2b-pre ou T2b-post)** | **Não deixe bootar** e não faça o flash seguinte. Fique no fastboot, fotografe tela + allowlist, **pare o dia**. `slot-retry-count:b=0` só se registra; não é parada (informational only). |
| **`FAILED` em T-1.2** | **PARAR**. Guard refusal or `FAILED (...)` with the device still in fastboot means the write not started: stop, no second flash. A cable or power drop with no OKAY is not intact bytes: if FASTBOOT returns by keys, one flash of the verified backup through the guard and the day ends; if it does not return, that is L3. LK write atomicity is UNVERIFIED (RE1 does not disassemble the primitive) (PROTO:108#FAILED). |
| **Divergência no pre-flight (partição ≠ 0x4000000 e ≠ 4000000 (LK hex), arquivo ≠ 67108864, hash ≠ gravado)** | **PARAR** — proteção oversize vem deste check seu (PROTO:85#0x4000000). |
| **Backup hash ≠ SHA256SUMS.log** | **PARAR** — não use backup corrompido (PROTO:107#sha256sum). |
| **`pstore` vazio (`ls -l /sys/fs/pstore` sem `console-ramoops-0`/`pmsg-ramoops-0`)** | **PARAR** — sem observabilidade pós-crash (PROTO:140#console-ramoops-0, PROTO:200#pstore). |
| **Carregador conectado durante Z0** | Desconecte para tirar a ambiguidade. Sozinho o carregador não encerra o dia (advisory; charger disconnected continua sendo o pedido do Z0) (PROTO:29#charger). |

#### Lacunas (sintomas NÃO cobertos pelo protocolo/SAFETY)

| Lacuna | Sintoma | Ação declarada |
|--------|---------|----------------|
| L1 | Aparelho entra em **EDL/BROM mode** (tela preta, `lsusb` mostra Qualcomm/MediaTek EDL) | **PARAR**, não usar mtkclient (DL forbidden), suporte autorizado Xiaomi |
| L2 | `tools/fastboot_guard.sh flash boot_b` retorna `OKAY` mas **aparelho não boota** e **não volta ao fastboot** (trava no kernel, sem fastbootd/recovery) | Uma tentativa: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable. Se a tela fastboot aparecer, rollback `tools/fastboot_guard.sh flash boot_b` com o backup já conferido no hash e pare o dia. Se a tela não aparecer, pare. Não troque de cabo como se fosse o Z0.2 |
| L3 | **Falha física** (energia/eMMC/botão Power/porta USB) | Parar. Não repetir T-1.2 nem T3. Guard refusal or FAILED while still in fastboot means the write not started: stop, no second flash. A cable or power drop with no OKAY is not intact bytes: if FASTBOOT returns by keys, one flash of the verified backup through the guard and the day ends; if it does not return, that is L3. LK write atomicity is UNVERIFIED (RE1 does not disassemble the primitive). Se não houver fastboot por teclas, serviço autorizado Xiaomi. Não usar mtkclient (L1) |
| L4 | **Bypass do host-side guard** (ex: função não carregada, alias, subshell) | Se qualquer flash rodou fora de `tools/fastboot_guard.sh`: permanecer em fastboot, rollback com o wrapper e o backup conferido no hash, encerrar o dia. Se o wrapper não for o comando que você está prestes a colar, não comece o Z0 |
| L5 | **Bootloader travado / AVB** (dispositivo locked) | Não se aplica a desbloqueado; não travar o bootloader |
| L6 | **`pstore` vazio** após crash | Usar `dmesg`/`adb bugreport` como fallback |

### Residual risks (consolidated — what can still go wrong when every gate passes)

| # | Risk | Mitigation in this protocol | Status |
|---|---|---|---|
| R1 | Physical failure mid-write (power loss, eMMC fault, cable/port failure) | Battery ≥ 60 % + data cable verified before Z0 (PROTO:136#battery); hands off cable/device during T-1.2/T3; Z0 PASS proves key-reached recovery on a healthy device only when the cable is disconnected during Vol− + Power (measured 2026-10-09; PROTO:32#key-reached). A bad `boot_b` is still unshown. Guard refusal or FAILED while still in fastboot means the write not started: stop, no second flash. A cable or power drop with no OKAY is not intact bytes: if FASTBOOT returns by keys, one flash of the verified backup through the guard and the day ends; if it does not return, that is L3. LK write atomicity is UNVERIFIED (RE1 does not disassemble the primitive) | Accepted risk; a damaged preloader leaves only an authorized Xiaomi service (SAFETY:7#preloader)
| R2 | LK rejects the new image at runtime (unsigned repack refused or boot failure) | T-1 demonstrates the flash path with identical bytes first (PROTO:97#identical); immediate rollback with the T-1 command + verified backup; T2b-post reads the slot after the T3 OKAY and before reboot (PROTO:118#T2b-post) | UNVERIFIED for `boot` (plausible by analogy with the measured `init_boot_b` tolerance — see SAFETY "Why a modified boot image is plausibly accepted"); on-device behaviour still unproven (SPEC §T) |
| R3 | Automatic fallback to slot A (old OS3.0.20.0 over new data) | T2b-post before the first normal boot of the new image (PROTO:118#T2b-post); never `set_active` (PROTO:13#set_active); slot firmware compared or accepted in writing before anything else (PROTO:138#accept). At the first boot loop: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable, then reflash the verified backup | Slot A MEASURED 2026-10-09 `unbootable=yes`, `successful=no`, retry 0. Selection reads the priority nibble (`ands r0, 0xf`) at `0x4c42cae2` / `0x4c42cb02` and skips the slot when it is 0. Both invalid reach `fastboot_init` (RE4 D2, SAFETY:42#RE4). "Does not fall to A" is INFERRED until observed. Risk remains
| R4 | A/B retry counter mechanics (decrement, initial value) | Record `slot-retry-count`; `0` is informational only and is not a STOP (PROTO:66#informational). Stop the day when `slot-unbootable:b` is `yes` or `slot-successful:b` is not `yes` (PROTO:118#unbootable). `slot-retry-count:b` measured 1. At the first loop: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable, then reflash the verified backup | MEASURED value 1 on 2026-10-09. How many failed boots mark b unbootable is INFERRED (3-bit field, decrement not isolated — RE4 D1, SAFETY:44#retry). One failure can exhaust a count of 1. Risk remains

## Z0 results (2026-10-09)

MEASURED on the audited lake device in fastboot. No serial is recorded here. The capture is not in this repository.

| getvar | value | reading |
|---|---|---|
| product | lake | required |
| current-slot | b | required |
| slot-count | 2 | optional, answered |
| is-userspace | no | this run answered no. A later `Variable not found` without FAILED ( is still recorded and is not a STOP |
| unlocked | yes | required |
| max-download-size | 0x8000000 | LK hex = 134217728 (128 MiB), which is ≥ 67108864 |
| partition-size:boot_b | 4000000 | LK hex with no prefix = 67108864. `0x4000000` is the same value. The token `67108864` is hex 1729136740 and is not this size |
| slot-successful:a | no | record-only |
| slot-successful:b | yes | gate |
| slot-unbootable:a | yes | record-only. Together with successful=no and retry-count 0 this is the measured state of slot A |
| slot-unbootable:b | no | gate |
| slot-retry-count:a | 0 | record-only |
| slot-retry-count:b | 1 | informational. `0` would still pass the gate |
| battery-soc-ok | yes | optional, answered |
| battery-voltage | 3921mV | optional, answered |

Post-reboot through the guard: `sys.boot_completed=1`, `ro.product.device=lake`, slot `_b`, `OS3.0.306.0.WGTMIXM`, modules 429/429. Reference `uname -r` is MEASURED `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k` (source: PLAN fact 2). Capture `adb shell uname -r` on the day before T-1.2.

Key entry that day: fastboot by keys happened only with the USB cable disconnected during Vol− + Power. With the cable connected the device did not enter. Reconnect after the FASTBOOT screen. Order from here on: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable.

Slot A is `unbootable=yes`, `successful=no`, retry-count 0. AOSP boot_control does not select a slot whose priority nibble is 0. This LK's selection reads that nibble at `0x4c42cae2` (`_a`) and `0x4c42cb02` (`_b`) via `bl 0x4c453df8` (`ldrb r0, [r4, -0x14]`; `ands r0, r0, 0xf`; `it ne`; `movs r0, 1` at `0x4c453e26`–`0x4c453e30`) and `ble.w` skips the slot when the result is 0. The image is `backup-2026-10-05/lk_b.img`, sha256 `017da2dac658cbce05081974590ad86ab2f75b6f07b28b0dbe06fb7386e92635`, disassembled with `r2 -a arm -b 16 -m 0x4c3ffe00`. `tries_remaining` is a different read (`ubfx r0, r0, 4, 3` at `0x4c453d60`, callers `0x4c42cb28` and `0x4c42cb58`) and is printed, not the skip. "Does not fall to A" is INFERRED until observed. Risk remains. Both slots invalid reach `fastboot_init` at `0x4c42b266` (RE4 D2), on-device behaviour of a bad `boot_b` still UNVERIFIED.

`slot-retry-count:b` = 1. For T3, how many failed boots mark `b` unbootable is INFERRED. The field is 3 bits and the decrement was not isolated, so one failure can exhaust a count of 1. At the first boot loop the operator does: Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable, and reflashes the verified backup.

Still UNVERIFIED after this log: key-reached fastboot with a bad `boot_b`; acceptance of a v4 image; the retry decrement; the exact Vol−↔code mapping; on-device fallback to slot A.
