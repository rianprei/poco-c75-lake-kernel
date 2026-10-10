# FIX18 report

No device command was run. Nothing was pushed. The fastboot in the S5/S6 re-run was a stub, earlier on `PATH` than any real binary, and it was removed after the transcript below.

INTENT: `flash` uses the same slot rule as `reboot`. The second-disk copy blocks T-1.1. A refusal is not a mid-write, and a drop with no `OKAY` is not intact bytes. T-1.3b does not gate `slot-retry-count:b`. The measured stock `uname -r` is the reference. The day order, the hash file, and the isolated Z0 exit are explicit. Fact 21 counts the real hash files.

Counts: fixed 12, refutados 0. Open: none in this review. LK write atomicity stays UNVERIFIED. Boot on a bad `boot_b` stays UNVERIFIED.

## S5 / S6, re-run on the new guard

The file under test was the audited backup: size 67108864, magic `ANDROID!`, sha256 `3890fb9664c6543a4939b18b3845f05995221672fb4af905d2367ef12b829fc7`. The stub answered `partition-size:boot_b: 4000000`. A private copy path in the allow-case log is written here as `<private-copy>`.

```
CASE S5  current-slot: a    is-userspace: no
RC 2
stderr: desligue por teclas e encerre
log:
getvar partition-size:boot_b
getvar current-slot
getvar is-userspace
flash_line: no

CASE S6  current-slot: b    is-userspace: yes
RC 2
stderr: desligue por teclas e encerre
log:
getvar partition-size:boot_b
getvar current-slot
getvar is-userspace
flash_line: no

CASE missing current-slot line
RC 2
stderr: desligue por teclas e encerre
log:
getvar partition-size:boot_b
getvar current-slot
getvar is-userspace
flash_line: no

CASE allow  current-slot: b    is-userspace: no
RC 0
log:
getvar partition-size:boot_b
getvar current-slot
getvar is-userspace
flash boot_b <private-copy>
FLASHED_SHA256 3890fb9664c6543a4939b18b3845f05995221672fb4af905d2367ef12b829fc7
flash_line: yes
```

Before this fix, S5 and S6 returned 0 and the log contained `flash`. Both now return 2, print `desligue por teclas e encerre`, and do not send `flash`.

## Tasks

| Item | Result | Where |
|---|---|---|
| G1 | FIXED | `tools/fastboot_guard.sh:26` gate 6, `:133-147` read both getvars and refuse when the slot value is not exactly `b`. A missing slot line refuses, exit 2, and `flash` is not sent. `tools/selftest_fastboot_guard.sh:221` and `:223`. Protocol `:164-165` says the wrapper re-verifies `current-slot exactly b`. SPEC B124, V102 (`tools/check_protocol_invariants.sh:1247`, `tools/run_all_checks.sh:127-129`). Sabotage case 133 deletes the marked block. |
| G2 | FIXED | Same block, `tools/fastboot_guard.sh:27` gate 7 and `:142`: `is-userspace` exactly `yes` refuses. `tools/selftest_fastboot_guard.sh:222`. Protocol `:165` says `is-userspace not yes`. |
| A | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:107` T-1.1, `:132` the T3 warning, and `:139` say the second-disk copy blocks T-1.1, not only T3. The copy is `cp`, then `sha256sum -c` on the destination. `docs/PLAN-AND-FINDINGS.pt-BR.md:143` states the same precondition. For this owner it is MEASURED 2026-10-09, 44/44 hash-equal after drop_caches, boot_b `3890fb96…829fc7`, private research. SPEC B125, V103 (`tools/check_protocol_invariants.sh:1265`). Case 134. |
| B | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:112`, `:218`, `:230`, and `:239`. Guard refusal or `FAILED` while still in fastboot: write not started, stop, no second flash. Cable or power drop with no `OKAY`: not intact bytes; if FASTBOOT returns by keys, one flash of the verified backup through the guard and the day ends; otherwise L3. LK write atomicity is UNVERIFIED. SPEC B126, V104 (`:1282`). Case 135. |
| C | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:110`. Gate is `slot-successful:b=yes`, `slot-unbootable:b=no`, and `current-slot=b`. `slot-retry-count:b` is recorded only. `0` is not a STOP. SPEC B127, V105 (`:1299`). Case 136. |
| D | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:109` and `:266`. Reference `uname -r` is MEASURED `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k`, source PLAN fact 2. Capture it on the day before T-1.2. SPEC B128, V106 (`:1313`). Case 137. |
| E1 | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:140` and `:142`. Host guard files first, then adb baseline with the cable, then unplug for Z0.1. SPEC B129, V107 (`:1331`). Case 138. |
| E2 | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:152-156`. On the T-1 day `guard_hashes.txt` receives only the backup hash. `boot_b_new.img` is T3 day only. SPEC B130, V108 (`:1343`). Case 139. |
| E3 | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:68` and `:108`. Z0.6 is the exit of an isolated Z0. On a T-1 day there is no Z0.6 reboot between Z0.4 and T-1.2. SPEC B131, V109 (`:1356`). Case 140. |
| E4 | FIXED | `docs/DEVICE-TEST-PROTOCOL.md:137`. The identity check names `ro.product.device=lake`, `ro.boot.slot_suffix=_b`, and `ro.build.version.incremental=OS3.0.306.0`. No model or CPU property is required: this repo does not record `ro.product.model` or `ro.soc.model`. SPEC B132, V110 (`:1368`). Case 141. |
| F | FIXED | `docs/PLAN-AND-FINDINGS.pt-BR.md:33` fact 21, `:76` fact 56, and `:112` F1. `SHA256SUMS.log` covers 12 images. The private 2026-10-05 reference has 42 lines and 41 distinct images (`vbmeta_vendor_b` duplicated). `gpt_header_256kb.bin` and `super_header_8m.bin` have no prior hash. The second-disk copy is MEASURED 44/44. The string `42/42` is gone from the plan. SPEC B133, V111 (`:1381`). Case 142. |

## Backprop

| Bug | Invariant | Sabotage |
|---|---|---|
| B124 | V102 | case 133 deletes the flash interlock |
| B125 | V103 | case 134 leaves the second disk as a T3-only block |
| B126 | V104 | case 135 rewrites `write not started` on line 112 |
| B127 | V105 | case 136 puts the four-value gate back |
| B128 | V106 | case 137 removes the measured uname |
| B129 | V107 | case 138 drops the day order |
| B130 | V108 | case 139 marks the new-image hash as a T-1 line |
| B131 | V109 | case 140 makes Z0.6 the T-1 exit |
| B132 | V110 | case 141 puts an unnamed model requirement back on the identity line |
| B133 | V111 | case 142 appends `42/42` to the plan |

Case 71 now substitutes every `slot-unbootable:b` on the T-1.3 rows. The T-1.3b pass cell repeats that token, so a first-only substitute left V63 green.

## Suite

`./tools/selftest_backprop.sh` printed `SABOTAGENS: 146 detectada(s) FAIL->PASS, 0 falha(s)` and `SELFTEST-BACKPROP PASS`. `./tools/check_protocol_invariants.sh` printed PASS, including V33 and V102 through V111, with this file present. `./tools/run_all_checks.sh` printed `run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V111 + gate self-test)`.
