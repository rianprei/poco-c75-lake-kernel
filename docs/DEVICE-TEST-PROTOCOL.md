# Device test protocol (not yet executed)

> Status: **planned, not run.** Results will be added here with logs.

Images are built and verified on the host (`docs/BUILD.md`). Order matters — each step is only attempted if the previous one passed. Only two steps write anything to flash, and both are explicit below (T-1 rewrites identical bytes, T3 writes the new kernel); everything else writes nothing.

This protocol is written for the **audited device** (POCO C75 4G `lake`, slot `_b`, `OS3.0.306.0`, bootloader unlocked/`orange`). Every expectation below is labelled with where it was measured; anything not marked is a precondition you must confirm **on your own device before starting**. The adversarial analysis behind the mitigations is in [`research/REVIEW3_codex_fmea.md`](research/REVIEW3_codex_fmea.md) (28 scenarios) and the command list under review is `research/DEVICE_COMMANDS_T0_T2.md`. What was verified **in the real bootloader binary** (and what was not) is tabulated in [`SAFETY.md`](SAFETY.md) §*What we verified in the real bootloader*.

## Read this first (brick / data-loss rules)

1. **`fastboot boot` is NOT part of this protocol.** A legacy-v2 RAM-boot path was **discarded** after review (see *Why the legacy RAM-boot is discarded* below), and support for `fastboot boot` on this bootloader is **UNKNOWN** — two independent sources agree there is no evidence either way: the command exists in the LK source and binary (`cmd_boot`, `docs/SAFETY.md` rule 4 and its LK table) and it was never demonstrated on this device (`docs/PLAN-AND-FINDINGS.pt-BR.md` fact 10, `research/OPENCODE2_boot_safety.md` §1). If a future revision ever re-introduces it and the bootloader answers `unknown command`, stop: nothing was transferred and nothing changed.
2. **Never choose "Factory data reset" on any screen.** If the device shows *"Can't load Android system. Your data may be corrupt"* with *Try again* / *Factory data reset*, choose **Try again** — and photograph the screen before touching anything. **Your backup does not contain `userdata`**, so a wipe is permanent loss of photos/apps/data (`research/REVIEW3_codex_fmea.md` §2, measurement M5: `grep -ciE "userdata|user_data" backup/SHA256SUMS.log` → 0; `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 21). **Back up your personal data first** (cloud/PC), before you even connect the cable.
3. **Never switch slots.** On the audited device slot A holds an **older firmware (OS3.0.20.0)** while slot B runs OS3.0.306.0, so booting slot A means an old OS on top of newer user data (`docs/PLAN-AND-FINDINGS.pt-BR.md` facts 62/64). Do **not** run `set_active`, and do not use "the inactive slot" as a test slot.
4. **Any `FAILED (...)` from fastboot is a STOP**, whatever the text says — do not improvise, do not retry with another cable "just once more", do not switch to a flash command. Note the exact message; it decides what can be tried another day.
5. **Every step before T3 writes nothing to flash, except T-1** — which rewrites the byte-identical backup (see below) and is itself gated like a write. If a command you are about to run is not in the table below, don't run it.

## Why the legacy RAM-boot is discarded (3 lines)

1. A legacy (v2-header) boot image carries no `androidboot.*` parameters — not even `slot_suffix` — and there is no evidence that this LK injects them on its `fastboot boot` path, so the system could come up **without knowing which slot it is on**.
2. That means Android could mount the **old system of slot A on top of the current data** — exactly the data-loss scenario this protocol exists to avoid (rule 3).
3. Therefore no instruction in this repository presents the legacy RAM-boot as a safe path; `fastboot boot` of the *stock-equivalent v4 repack* remains a **hypothesis** to be re-evaluated separately, never a default.

## Steps

### Z0 — recovery rehearsal (mandatory before any write; zero-risk)

Purpose: prove, with the device **powered off** and using read-only fastboot commands only, that you can reach fastboot **by keys** and get back out — the exact motions you would need if a written `boot_b` ever failed. Z0 **mandatory** (Z0.1–Z0.3) writes nothing; Z0.0 (optional, documentary) runs `adb reboot bootloader` which writes only the Android boot reason, nothing in boot/lk.

Preconditions (host): data cable to the PC, **charger disconnected** (a connected charger can park the LK in off-mode-charge instead of booting); `adb` already authorized with exactly one device; hash-verified backup present; day baseline captured (`cat /proc/modules | awk '{print $1}' | sort > baseline_modules.txt`); shell guard from *Host-side guard* active.

- **Z0.0 (optional, documentary):** `adb -s <serial> reboot bootloader` warms the path only; it is NOT the criterion (it writes a boot reason and follows a warm path, while T-1/T3 need the cold key path). The PASS criterion is Z0.1/Z0.2.
- **Z0.1:** device **powered off** (long Power until dark) → hold `Vol− + Power` until the fastboot screen. PASS = fastboot screen visible. Anything else = STOP (without key-reached fastboot there is no recovery path for T-1/T3).
- **Z0.2:** `fastboot devices` → exactly one device, else STOP.
- **Z0.3 (closed allowlist — run only these, nothing else):**
  `fastboot getvar product`
  `fastboot getvar current-slot`
  `fastboot getvar slot-count`
  `fastboot getvar is-userspace`
  `fastboot getvar unlocked`
  `fastboot getvar max-download-size`
  `fastboot getvar partition-size:boot_b`
  `fastboot getvar slot-successful:a`
  `fastboot getvar slot-successful:b`
  `fastboot getvar slot-unbootable:a`
  `fastboot getvar slot-unbootable:b`
  `fastboot getvar slot-retry-count:a`
  `fastboot getvar slot-retry-count:b`
  `fastboot getvar battery-soc-ok`
  `fastboot getvar battery-voltage`
  **Forbidden**: `getvar all`, any `oem` (the real LK carries `oem allow-wipe-userdata`), anything outside this list.
- **Z0.4 (stop Opinions):** PASS when `product=lake`; `current-slot=b`; `is-userspace` is `no` or `Variable not found` (`yes` = fastbootd → STOP); `unlocked=yes`; `slot-unbootable:b` shows `no`; `slot-retry-count:b` above `0`; `partition-size:boot_b = 0x4000000`. Any other answer: record it, do not advance to T-1/T3 that day. Exception: `current-slot` other than `b` → **power off by keys** (long Power), never `fastboot reboot` (rollback index of vbmeta_a/vbmeta_b/backup is 0, so the LK is **not barred** from booting the old slot A; rolling back to it would boot OS3.0.20.0 over newer data).
- **Z0.5 (record twice):** save the full allowlist output as `z0_fastboot_before.txt` (+ photograph the screen). Reference state for later slot readouts.
- **Z0.6 (exit):** `fastboot reboot` → wait for Android (3 min). Confirm: `adb devices` lists it again; `ro.boot.slot_suffix=_b`; `ro.product.device=lake`; `ro.build.version.incremental` the OS3.0.306.0 line; modules ⊇ day baseline (`~429` is only a reference to the audited device, not your criterion). If adb is not back in 3 min: long Power 10–15 s → re-enter by keys → repeat Z0.3 + `fastboot reboot` **once**; a second failure ends the day (no USB improvisation). If it boots a different slot/OS line: power off, do not unlock the screen, report.
- **Z0.7 (close):** log Z0.6 + keep `z0_fastboot_before.txt` as the reference for the pre-T-1 readout. **Z0 PASS** = Z0.1–Z0.4 green + Z0.6 on slot `_b`/OS3.0.306.0/modules ⊇ baseline.

**What Z0 does not prove (read before claiming confidence):** key-reached fastboot with a *bad* `boot_b`; acceptance of a v4 image; retry decrement/exhaustion and its initial value; the exact Vol−↔code mapping; expected getvar *values* (the binary proves a handler exists; Z0 measures the values). All still UNVERIFIED after Z0.

**Z0 PASS** = all rows above green. **Only after Z0 passes** may any later step be attempted on another day or the same day. If fastboot is not reachable by keys with a healthy device, **do not proceed**: every recovery path in this project depends on reaching fastboot, and that assumption is exactly what Z0 tests (it stays **UNVERIFIED** until a Z0 run is logged).

### R3 / pre-flight (read-only identity checks)

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| R3 | in fastboot: `fastboot getvar current-slot`, `unlocked`, `is-userspace`, `slot-count`, `max-download-size`, and the per-slot `slot-successful:*`, `slot-retry-count:*`, `slot-unbootable:*` when the bootloader exposes them | no | `current-slot=b` (**abort if ≠ b**), `is-userspace` accepts `no` **or `Variable not found`** (the string `is-userspace` **exists** in the LK getvar table; runtime value on this device was never read — `docs/SAFETY.md` LK table), `is-userspace=yes` = **STOP** (you are talking to fastbootd, not the LK), `unlocked=yes`, `max-download-size ≥ 67108864` |

### Pre-flight for the write (T3 gate) — all three must agree

```bash
# a) what the device says the partition is
fastboot getvar partition-size:boot_b          # EXPECT: 0x4000000  (= 67108864 bytes)
# b) what the file is
stat -c%s boot_b_new.img                       # EXPECT: 67108864  (exactly; not one byte more or less)
sha256sum boot_b_new.img                       # EXPECT: the hash you recorded when building it
```

**Any divergence between (a), (b) and the recorded hash = PARAR.** The oversize protection must come
from *this* check, run by you — not from assuming the order of the bootloader's internal tests
(that order is **MEASURED** by disassembly of the real binary: check `bl 0x4c4367d2` precedes write `bl 0x4c436834`, fail branch returns first; see `research/RE1_opencode_flash.md` §3.3). The LK string
`size too large, space small. image length[0x%llx], partition max size[0x%llx]` exists in the real
binary, but you must not *rely* on reaching it.

### T-1 — write-path rehearsal with identical content (a write; gated like T3)

Purpose: demonstrate the flash path itself works — with bytes identical to what is already on
the device — before the new kernel is ever written. This is the first of the two write commands
of this protocol (T-1 identical content, T3 new kernel).

Only after **Z0 PASS**, and only with the owner's explicit "yes" on the day:

| T-1 | Action | Pass criteria |
|---|---|---|
| T-1.1 | On the host, confirm the backup file: `stat -c%s <path/to/backup/boot_b.img>` (= 67108864) and `sha256sum <path/to/backup/boot_b.img>` (= the hash YOU recorded when you made the backup; for the audited device that is `3890fb96…829fc7` in `SHA256SUMS.log`, a file that lives with your backup, not in this repo) | size exact, hash matches the recorded backup hash |
| T-1.2 | In fastboot (after R3): run the T-1 command from *The two write commands* below (`flash boot_b` with the backup image, `command` bypass prefix exactly as listed). T-1 uses the **backup**; `boot_b_new.img` is only for T3. Interruption carries the same risk class as any flash (it rewrites the ACTIVE slot); Z0 PASS plus the battery/cable gates are what minimize it | `OKAY`, no `FAILED (...)` |
| T-1.3 | `fastboot reboot`; confirm the normal system: `ro.build.version.incremental` still the OS3.0.306.0 line, `uname -r` the stock kernel | device boots exactly as before (the content written was identical, so behaviour must be identical) |

**T-1 PASS** = all three rows green. If T-1.2 returns `FAILED (...)`: STOP (rule 4) — the write path itself is not demonstrated on this device, and T3 is off the table. No rollback flash is needed after T-1: the bytes written are the backup bytes.

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| T2b | in fastboot before the first normal boot: re-read the Z0.3 allowlist — run these exact commands and compare with the R3/Z0.5 values:<br>`fastboot getvar slot-successful:a`<br>`fastboot getvar slot-successful:b`<br>`fastboot getvar slot-retry-count:a`<br>`fastboot getvar slot-retry-count:b`<br>`fastboot getvar slot-unbootable:a`<br>`fastboot getvar slot-unbootable:b` | no | slot `_b` not marked `unbootable`, retry count not exhausted — **only then let the device boot normally** |
| T3 | only if everything above is green **and the owner agrees**: the write command for the new kernel, below, with the verified backup as immediate rollback | **yes** | same acceptance, then 30 min stress |

**The two write commands of this protocol** (paste them; never retype):

```bash
command fastboot flash boot_b <path/to/backup/boot_b.img>   # T-1: identical content (gates: Z0 PASS, owner yes, T-1.1 hash/size)
command fastboot flash boot_b boot_b_new.img                         # T3: new kernel (gates: T-1 PASS, pre-flight, owner yes)
```

**NEVER type** (not in this protocol, not "just to fix" anything):
`flash` on any other partition (`preloader*`, `lk*`, `seccfg`, `nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `protect1`, `protect2`, `expdb`, `vbmeta*`, `vendor_boot*`, `init_boot*`, `dtbo*`, `system*`, `super`, `misc`, `boot_para`), `erase` (anything), `format` (anything), `oem` (anything), `flashing` (anything), `set_active` / `--set-active` (anything), `update`, `flashall`. The real LK strings confirm several of these are refused by the bootloader itself — *"Forbidden to erase boot/preloader partition."*, *"download for partition '%s' is not allowed"*, *"flash preloader is not permitted."* — but the protection you must count on is your own hands, not the bootloader: disassembly shows exactly two name lists — 7 controlled (`nvram`, `nvcfg`, `proinfo`, `nvdata`, `protect2`, `protect1`, `persist`) and 7 erase-forbidden (`preloader*`, `boot0`, `boot1`) — and `lk`, `seccfg`, `misc`, `boot_para`, `vbmeta`, `vendor_boot` are in neither (`docs/SAFETY.md`).

**Why T2b exists** (FMEA-26, the main gap this revision closes): a partial boot can reach userspace, fail a health check and leave slot `_b` marked unbootable — and the LK would then fall back to the **other** slot, which on this device is old firmware. Check the slot state *before* the first normal boot, and if `_b` looks unhealthy: stay in fastboot, photograph the fastboot screen and the allowlist output, and stop for the day.

**T3 warning, in full.** Writing `boot_b` is the step that changes flash content for the first time (T-1 only rewrites identical bytes, and only after T-1 PASS does T3 become eligible). If the written image does not boot, the LK may mark `boot_b` unbootable and **automatically fall back to the other slot**, which on the audited device contains **OS3.0.20.0 over data created by OS3.0.306.0** — that path risks "data corrupted"/anti-rollback prompts, and it is the one route to data loss that does not require a human mistake. Before T3 you must have: **Z0 passed**, **T-1 passed**, the firmware comparison below, the R3/T2b slot readouts saved, `boot_b` + `init_boot_b` + `vbmeta*_b` backups verified on a second disk, USB cable and `Vol− + Power` at hand for the fastboot rollback (the T-1 command above, backup image), and the owner's explicit "yes". If the device does fall back to slot A, do **not** fight it with slot commands: power off and re-read the slot state in fastboot (run Z0.3 allowlist again: `fastboot getvar slot-successful:a`, `fastboot getvar slot-successful:b`, `fastboot getvar slot-retry-count:a`, `fastboot getvar slot-retry-count:b`, `fastboot getvar slot-unbootable:a`, `fastboot getvar slot-unbootable:b`).

## Preconditions

- USB **data** cable, battery ≥ 60 %, screen on, device unlocked, `adb` authorized.
- Identity check: `ro.product.device=lake`, expected model/CPU id, `ro.boot.slot_suffix=_b`, `ro.boot.flash.locked=0`, `ro.boot.verifiedbootstate=orange`, `ro.build.version.incremental=OS3.0.306.0…`. **Any divergence → STOP** (`research/REVIEW3_codex_fmea.md` FMEA-06; the audited values are in `audit/getprop.txt`).
- **Both slots' firmware compared before anything else** — run `avbtool info_image` on `vbmeta_a` and `vbmeta_b` and confirm the inactive slot is the *same* firmware line, or **accept in writing** (type in the terminal: `I accept that slot A is older firmware OS3.0.20.0 and fallback would boot old OS over new data`) that it is older and that a fallback to it would boot old firmware over new data (SAFETY rule 3).
- Hash-verified backup of `boot_b`, `init_boot_b`, `vendor_boot_b`, `dtbo_b`, `vbmeta*_b` on a **second disk**, plus the state readouts of step R3 below.
- **Baseline captured on the day** (never reuse an old file): `cat /proc/modules | awk '{print $1}' | sort > baseline_modules.txt` — on the audited device this is 429 modules (example only), but your number is *your* baseline (FMEA-08); also `dmesg > baseline_dmesg.txt` and record `ls -l /sys/fs/pstore` (expected: `console-ramoops-0`, `pmsg-ramoops-0`).

## Host-side guard (do this before plugging the cable)

Paste the commands, never retype them, and put this function in the shell from which you will call fastboot (FMEA-28):

```bash
fastboot() {
  case "$*" in
    *flash*|*erase*|*format*|*oem*|*flashing*|*set_active*|*--set-active*|*update*|*flashall*)
      echo "BLOQUEADO: comando de gravação proibido neste protocolo" >&2; return 1;;
    *) command fastboot "$@";;
  esac
}
```

The guard stays active for T0/T2/R3/Z0; for the T-1/T3 commands, run them with `command fastboot ...` after re-reading the pre-flight checks out loud. The LK's own denylist strings (`docs/SAFETY.md`) are a second layer, not a substitute.

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

Any hang > 3 minutes without UI, any panic, any missing baseline module, any `FAILED` from fastboot, any failed acceptance item, **any screen mentioning corrupted data** → hold power to reboot (RAM boots leave flash untouched; do not touch the screen), capture `pstore`/bugreport from the next normal boot on a good kernel, and stop. One anomaly = the day ends: no second attempt, no "different cable", no improvised command.
