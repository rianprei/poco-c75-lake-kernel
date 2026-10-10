# FIX19 report

No device command was run for this edit. Nothing was pushed.

INTENT: the pstore precondition measures the registered ramoops backend. An empty folder after a cold boot is recorded. `console-ramoops-0` is required only after a warm restart, and only before T3.

Counts: fixed 7, refutados 0. Open: none in this review. LK write atomicity stays UNVERIFIED. `pmsg-ramoops-0` after a warm restart is INFERRED (it shows up only if something wrote pmsg; not re-measured on 2026-10-10).

## Items

1. `docs/DEVICE-TEST-PROTOCOL.md:140` records `adb shell ls -l /sys/fs/pstore` and does not stop on an empty folder after a cold boot. The gate is `adb shell cat /sys/module/pstore/parameters/backend` printing `ramoops`, and `adb shell cat /proc/cmdline` containing `ramoops.mem_address=0x4d010000` with `ramoops.console_size` and `ramoops.pmsg_size` greater than 0. If the shell cannot read the parameter file, the cmdline clause is the gate. No root.
2. `docs/DEVICE-TEST-PROTOCOL.md:117` is the optional proof before T3, not on the T-1 day and not between Z0.4 and T-1.2. From Android on slot b, `adb reboot` (warm restart, boot reason only, same class as Z0.0), then `adb shell ls -l /sys/fs/pstore` must list `console-ramoops-0`. Empty after that warm restart is STOP before T3.
3. `docs/DEVICE-TEST-PROTOCOL.md:221` splits the cases: cold-boot empty is not a stop; backend absent is PARAR; warm-restart empty is PARAR before T3. `docs/DEVICE-TEST-PROTOCOL.md:233` L6 keeps `dmesg` and `adb bugreport` for an empty pstore after a real crash.
4. `docs/SAFETY.md:64` says files in `/sys/fs/pstore` appear only after a warm restart or a crash, and that empty after a cold boot is normal.
5. `docs/DEVICE-TEST-PROTOCOL.md:276` records the 2026-10-10 read-only capture. Uptime about 25 h. Last boot was a key power-off (Z0.1) then a boot by the LK (Z0.6). pstore was mounted. `ls -l` was `total 0` for the shell user and for root. Backend `ramoops`. `mem_address` 1291911168 (`0x4d010000`), `mem_size` 917504 (`0xe0000`), `console_size` 262144 (`0x40000`), `pmsg_size` 524288 (`0x80000`), matching cmdline. Which uid read the parameter file was not isolated from root, so cmdline is the no-root clause. No serial.
6. `SPEC.md:154` is B135. `SPEC.md:333` is V113. `tools/check_protocol_invariants.sh:1422` enforces it. `tools/run_all_checks.sh:100` counts it. `tools/selftest_backprop.sh:605` is case 144: putting the old cold-boot file expectation back on line 140 fails V113.
7. The private T-1 day script is outside this repository and is not in this commit. Its pstore block (`T1_DAY_SCRIPT.md:104`) uses the backend gate. The second-disk sentence (`T1_DAY_SCRIPT.md:11`) records the copy as MEASURED 2026-10-09, 44/44, `cp` then `sha256sum -c`. Also aligned: the identity line (`:113`), retry-count is not a stop (`:202`), no Z0.6 reboot between Z0.4 and T-1.2 (`:213`), and the guard compares slot `b` after trailing space and CR are removed.

## Checks

`./tools/run_all_checks.sh` PASS, including V113, through V34–V113 plus the CRC gate (114 checks). `./tools/selftest_backprop.sh` 148/148, SELFTEST-BACKPROP PASS. Case 144 detected `V113 FAIL`.
