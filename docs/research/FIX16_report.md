# FIX16 report

Z1 through Z10 from the Z0 review are fixed in the device protocol and in the day plan. No finding was refuted. No device was used. Nothing was pushed.

INTENT: `tools/fastboot_guard.sh reboot` reads `current-slot` and `is-userspace` before it sends `reboot`, and the protocol and the day plan use one rule for a missing getvar, for a retry, and for leaving fastboot when the slot is not `b`.

TWINS: searched `tools/fastboot_guard.sh reboot` in the protocol, SAFETY, and the guard. The retry on the Z0.6 line re-applies Z0.4 and names the refuse phrase. T-1.3a and T2b-post still reboot only after their own gates, on a slot that Z0 already required to be `b`. Searched `Outro cabo` in the protocol: the empty-devices row no longer offers another cable. Searched `Any other answer:` without the PASS-predicate subject: the Z0.4 sentence now names that subject.

AUTH: the FIX16 goal says to commit and to send the closing line to Claude Code.

Counts: fixed 10, refutados 0.

The day plan is outside this repository. Z5 and Z6 are the plan's missing failure actions. The same sentences are in the protocol, where V90 and V92 fail if they disappear. A sabotage copy of this repo cannot delete the plan, so those two rows have no in-repo sabotage of their own. The 15 Z0.3 `getvar` lines and the Z0.5 `2>&1 | tee z0_fastboot_before.txt` capture are the same text in both files, in the same order.

## Z1–Z10

| ID | Result | Where |
|---|---|---|
| Z1 | FIXED | `tools/fastboot_guard.sh` runs `getvar current-slot` and `getvar is-userspace` before `reboot`. It continues only when the slot value is exactly `b` and is-userspace is not exactly `yes`. Otherwise it exits 2 and prints `desligue por teclas e encerre`, and the fastboot binary does not receive `reboot`. The stub covers slot `a`, `is-userspace` `yes`, slot `b` with `no`, slot `b` with `Variable not found`, and a slot line that is not `current-slot:`. Removing the marked interlock makes V89 FAIL. Z0.6 says to re-apply Z0.4 before that reboot (V90). |
| Z2 | FIXED | Abort line 200 still says to hold power to reboot, then read pstore on the next normal boot on a good kernel. It also says `current-slot other than b: do not reboot; power off by keys and leave it off` (V91). The corrupt-data row carries the same exception. |
| Z3 | FIXED | `Any other answer to those PASS predicates` names the subject. `slot-successful:a` and `slot-unbootable:a` are record-only: any present value is not a value gate. A missing answer is still STOP (V92). |
| Z4 | FIXED | Absence is the bare string `Variable not found` with no `FAILED (` in that answer. Rule 4 and the abort row both say that sentence. The check classifies `Variable not found` as absence and `FAILED (remote: Variable not found)` as STOP. Turning the `FAILED (` test into `True` makes V93 FAIL. Dropping the sentence from one of the two sites does too. |
| Z5 | FIXED | Z0.6 states an action for device not `lake`, slot not `_b`, an OS line mismatch, and a module set that is not a superset. The day plan copies those actions. V90 fails if the protocol actions disappear. |
| Z6 | FIXED | The day plan now says that any other answer to those PASS predicates does not advance, and that a slot other than `b` means power off by keys and leave it off. V92 guards the protocol sentence. |
| Z7 | FIXED | The empty-devices row says `Sem outro cabo` and `Z0.2 empty ends the day, no other port` (V94). |
| Z8 | FIXED | Z0.5 still captures with `2>&1 | tee z0_fastboot_before.txt` and stops if that file lacks one answer per allowlist name (V95). |
| Z9 | FIXED | Z0 and R3 both say `decimal or 0x hex, both in bytes` for `max-download-size` (V96). `0x4000000` is 67108864 bytes. The radix of this bootloader was not measured on a device. |
| Z10 | FIXED | Lines 69 and 73 carry the same Z0 PASS equation: lake, slot `_b`, OS3.0.306.0, and a module superset of the day baseline (V97). A short module set does not fall through to a reboot when the slot is not `b`. |

## Backprop

| Bug | Invariant | Sabotage |
|---|---|---|
| B109 | V89 | case 118 deletes the interlock |
| B110, B114 | V90 | case 119 removes `re-apply Z0.4 before reboot` |
| B111 | V91 | case 120 removes the abort exception |
| B112, B115 | V92 | case 121 unscopes "any other answer" |
| B113 | V93 | case 122 lets `FAILED (` count as absence; case 123 drops one copy of the sentence |
| B116 | V94 | case 124 removes `Sem outro cabo` |
| B117 | V95 | case 125 removes the capture STOP |
| B118 | V96 | case 126 removes the radix phrase |
| B119 | V97 | case 127 changes one PASS equation |

The accepted slot line is `current-slot:` plus the value. A value that is not on that line refuses the reboot. That is fail-closed. This host did not run fastboot against the phone, so the report does not claim the bootloader's print format.

## Suite

`tools/run_all_checks.sh` printed `run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V97 + gate self-test)` and exited 0. That is V1–V97 plus the CRC-gate self-test, 98 checks. `tools/selftest_backprop.sh` printed `SABOTAGENS: 131 detectada(s) FAIL->PASS, 0 falha(s)` and `SELFTEST-BACKPROP PASS`.
