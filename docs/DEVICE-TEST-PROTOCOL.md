# Device test protocol (not yet executed)

> Status: **planned, not run.** Results will be added here with logs.

Images are built and verified on the host (`docs/BUILD.md`). Order matters — each step is only attempted if the previous one passed, and every step before the last writes nothing to flash.

## Preconditions

- USB **data** cable, battery ≥ 60 %, screen on, device unlocked, `adb` authorized.
- Identity check: `ro.product.device=lake`, expected model and CPU id match the audit; `ro.boot.slot_suffix=_b`.
- Hash-verified backup of `boot_b`, `init_boot_b`, `vendor_boot_b`, `dtbo_b`, `vbmeta*_b` available on a second disk.
- Baseline captured: `cat /proc/modules | awk '{print $1}' | sort` (429 modules on the audited device).

## Steps

| Step | Action | Writes to flash? | Pass criteria |
|---|---|---|---|
| T0 | `adb reboot bootloader`; read-only `fastboot getvar` checks; `fastboot boot` of the **stock-equivalent** repack (kernel bytes identical to stock) | no | either boots exactly like stock, or `unknown command` (then stop) |
| T2 | `fastboot boot` of the **new kernel** (cert build) | no | see acceptance below |
| T3 | only if T2 is fully green **and the owner agrees**: write `boot_b`, with the verified backup as immediate rollback | yes | same acceptance, then 30 min stress |

## Acceptance (all required)

- `uname -r` shows the new kernel; `sys.boot_completed=1`.
- `/proc/modules` module-name set ⊇ baseline (429).
- `dmesg` has **no** `Unknown symbol`, `disagrees about version`, `exports protected symbol`, `Invalid module format`, `kCFI`/panic.
- `wlan0` up and connected; Bluetooth turns on; SIM registers; display/touch/audio/camera/GPU/sensors work; charging works.
- All checks above work **without root** (`adb shell`, `adb bugreport`).

## Abort criteria

Any hang > 3 minutes without UI, any panic, any missing baseline module, any failed acceptance item → hold power to reboot (RAM boots leave flash untouched), capture `pstore`/bugreport from the next normal boot, and stop.
