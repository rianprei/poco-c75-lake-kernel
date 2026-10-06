# Device test protocol (not yet executed)

> Status: **planned, not run.** Results will be added here with logs.

Images are built and verified on the host (`docs/BUILD.md`). Order matters — each step is only attempted if the previous one passed, and every step before the last writes nothing to flash.

This protocol is written for the **audited device** (POCO C75 4G `lake`, slot `_b`, `OS3.0.306.0`, bootloader unlocked/`orange`). Every expectation below is labelled with where it was measured; anything not marked is a precondition you must confirm **on your own device before starting**. The adversarial analysis behind the mitigations is in [`research/REVIEW3_codex_fmea.md`](research/REVIEW3_codex_fmea.md) (28 scenarios) and the command list under review is `research/DEVICE_COMMANDS_T0_T2.md`.

## Read this first (brick / data-loss rules)

1. **If `fastboot boot` does not exist on this bootloader there is no RAM test — the protocol STOPS.** `fastboot boot <image>` loads a kernel without writing to flash, but its support on `lake` is **UNKNOWN** — two independent sources agree there is no evidence either way: the command exists in the LK source (MediaTek `cmd_boot`, `docs/SAFETY.md` rule 4) and it was never seen working on this device (`docs/PLAN-AND-FINDINGS.pt-BR.md` fact 10, `research/OPENCODE2_boot_safety.md` §1). If it answers `unknown command`, stop: nothing was transferred and nothing changed.
2. **Never choose "Factory data reset" on any screen.** If the device shows *"Can't load Android system. Your data may be corrupt"* with *Try again* / *Factory data reset*, choose **Try again** — and photograph the screen before touching anything. **Your backup does not contain `userdata`**, so a wipe is permanent loss of photos/apps/data (`research/REVIEW3_codex_fmea.md` §2, measurement M5: `grep -ciE "userdata|user_data" backup/SHA256SUMS.log` → 0; `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 21). **Back up your personal data first** (cloud/PC), before you even connect the cable.
3. **Never switch slots.** On the audited device slot A holds an **older firmware (OS3.0.20.0)** while slot B runs OS3.0.306.0, so booting slot A means an old OS on top of newer user data (`docs/PLAN-AND-FINDINGS.pt-BR.md` facts 62/64). Do **not** run `set_active`, and do not use "the inactive slot" as a test slot.
4. **Any `FAILED (...)` from fastboot is a STOP**, whatever the text says — do not improvise, do not retry with another cable "just once more", do not switch to a flash command. Note the exact message; it decides what can be tried another day.
5. **Nothing in T0/T2 writes flash** — that is the whole point. If a command you are about to run is not in the table below, don't run it.

## Preconditions

- USB **data** cable, battery ≥ 60 %, screen on, device unlocked, `adb` authorized.
- Identity check: `ro.product.device=lake`, expected model/CPU id, `ro.boot.slot_suffix=_b`, `ro.boot.flash.locked=0`, `ro.boot.verifiedbootstate=orange`, `ro.build.version.incremental=OS3.0.306.0…`. **Any divergence → STOP** (`research/REVIEW3_codex_fmea.md` FMEA-06; the audited values are in `audit/getprop.txt`).
- **Both slots' firmware compared before anything else** — run `avbtool info_image` on `vbmeta_a` and `vbmeta_b` and confirm the inactive slot is the *same* firmware line, or accept in writing that it is older and that a fallback to it would boot old firmware over new data (SAFETY rule 3).
- Hash-verified backup of `boot_b`, `init_boot_b`, `vendor_boot_b`, `dtbo_b`, `vbmeta*_b` on a **second disk**, plus the state readouts of step R3 below.
- **Baseline captured on the day** (never reuse an old file): `cat /proc/modules | awk '{print $1}' | sort > baseline_modules.txt` — on the audited device this is 429 modules, but your number is *your* baseline (FMEA-08); also `dmesg > baseline_dmesg.txt` and record `ls -l /sys/fs/pstore` (expected: `console-ramoops-0`, `pmsg-ramoops-0`).

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

## Steps

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| R3 | in fastboot: `fastboot getvar current-slot`, `unlocked`, `is-userspace`, `slot-count`, `max-download-size`, and the per-slot `slot-successful:*`, `slot-retry-count:*`, `slot-unbootable:*` when the bootloader exposes them | no | `current-slot=b` (**abort if ≠ b**), `is-userspace=no` (**proves it is the real LK, not fastbootd**), `unlocked=yes`, `max-download-size ≥ 67108864` |
| T0 | `fastboot boot` of the **stock-equivalent** repack (kernel bytes identical to stock) | no | either boots exactly like stock, or *any* `FAILED` → step T0.2 + STOP |
| T2 | `fastboot boot` of the **new kernel** (cert build) — only if T0 boots and looks like stock | no | see acceptance below |
| T2b | still in fastboot after T2: `fastboot getvar all` and re-read `slot-successful:*`, `slot-retry-count:*`, `slot-unbootable:*` for **both** slots, then compare with the R3 values | no | slot `_b` not marked `unbootable`, retry count not exhausted — **only then let the device boot normally** |
| T3 | only if T2 is fully green **and the owner agrees**: write `boot_b`, with the verified backup as immediate rollback | yes | same acceptance, then 30 min stress |

**Why T2b exists** (FMEA-26, the main gap this revision closes): a partial boot of the RAM kernel can reach userspace, fail a health check and leave slot `_b` marked unbootable — and the LK would then fall back to the **other** slot, which on this device is old firmware. Check the slot state *before* the first normal boot, and if `_b` looks unhealthy: stay in fastboot, photograph `getvar all`, and stop for the day (the flash copy of `boot_b` is intact — it is the RAM test that must not be repeated).

**T3 warning, in full.** Writing `boot_b` is the first and only step that changes flash. If the written image does not boot, the LK may mark `boot_b` unbootable and **automatically fall back to the other slot**, which on the audited device contains **OS3.0.20.0 over data created by OS3.0.306.0** — that path risks "data corrupted"/anti-rollback prompts, and it is the one route to data loss that does not require a human mistake. Before T3 you must have: the firmware comparison above, the R3/T2b slot readouts saved, `boot_b` + `init_boot_b` + `vbmeta*_b` backups verified on a second disk, USB cable and `Vol− + Power` at hand for the fastboot rollback (`fastboot flash boot_b <backup>`), and the owner's explicit "yes". If the device does fall back to slot A, do **not** fight it with slot commands: power off and re-read the slot state in fastboot.

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

Any hang > 3 minutes without UI, any panic, any missing baseline module, any `FAILED` from fastboot, any failed acceptance item, **any screen mentioning corrupted data** → hold power to reboot (RAM boots leave flash untouched; do not touch the screen), capture `pstore`/bugreport from the next normal boot, and stop. One anomaly = the day ends: no second attempt, no "different cable", no improvised command.
