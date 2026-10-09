# FIX17 report

The 2026-10-09 fastboot readout is now the logged Z0. No device command was run for this change. Nothing was pushed.

INTENT: one size parser, the flash guard reads `partition-size:boot_b` before it writes, the key order disconnects the cable first, and slot A plus `slot-retry-count:b` = 1 are recorded as measured, with the fall to A and the retry exhaustion left INFERRED.

Counts: fixed 7, refutados 0.

T-1 pronto: sim

The guard selftest printed `T-1 pronto: sim` and `### T-1 backup 3890fb96…829fc7 + 4000000` aceito. The same run refused a wrong hash, `3ffffff`, the all-digit token `67108864`, an empty value, `Variable not found`, a bad magic, a bad size, and `flash boot_b` with an extra argument. `bash ./tools/run_all_checks.sh` exited 0 after that selftest (V98 PASS, V66 PASS).

## Tasks

| # | Result | Proof |
|---|---|---|
| 1 | FIXED | `lk_parse_size` in `tools/lk_size.sh` is the only parser. It strips CR and space, accepts an optional `0x` or `0X`, then 1 to 8 hex digits, and prints the decimal of `$((16#…))`. Empty, non-hex, a bare `0x`, and more than 8 digits return 1. `4000000`, `0x4000000`, and `0X4000000` are 67108864. `3ffffff` is 67108863 and then fails the 67108864 gate. The all-digit token `67108864` is hex 1729136740, not the byte count, because a decimal reading would make the measured `4000000` mean 4194304. The 2026-10-09 line was `partition-size:boot_b: 4000000` with no prefix. `max-download-size` uses the same function: measured `0x8000000` is 134217728, which is ≥ 67108864; a missing answer stays record-and-continue. The flash guard, after the file gates and before the reboot interlock, runs `getvar partition-size:boot_b` and refuses with `partition-size:boot_b recusado` unless the parsed integer equals the file size. Z0.4, the T-1/T3 pre-flight, and R3 say the same rule (V96, V98). Case 126 retargets the old radix phrase. Case 128 replaces `16#` with `10#`. Case 132 deletes the marked gate. |
| 2 | FIXED | `docs/DEVICE-TEST-PROTOCOL.md` has `## Z0 results (2026-10-09)` after the residual-risk table, with the 15 measured values and no serial. The sentence `until a Z0 run is logged` is gone. `docs/PLAN-AND-FINDINGS.pt-BR.md` records `partition-size:boot_b=4000000` and the date (V100). Healthy key entry and those 15 values are MEASURED. A bad `boot_b` stays UNVERIFIED. |
| 3 | FIXED | Slot A is MEASURED `unbootable=yes`, `successful=no`, retry 0 (R3, SAFETY, the plan, the day plan). AOSP boot_control does not select a slot whose priority nibble is 0. This LK reads that nibble in slot selection: `0x4c42cae2` (`_a`) and `0x4c42cb02` (`_b`) call `0x4c453df8`, which does `ldrb r0, [r4, -0x14]` at `0x4c453e26`, `ands r0, r0, 0xf` at `0x4c453e2a`, then `it ne` / `movs r0, 1` at `0x4c453e2e`–`0x4c453e30`. Each caller then `cmp r0, 0` / `ble.w` and skips the slot when the result is 0. Both slots invalid reach `fastboot_init` at `0x4c42b266` (RE4 D2). "Does not fall to A" is INFERRED until observed. Risk remains. The scratch image named by the goal was not on disk. The disassembly used `backup-2026-10-05/lk_b.img`, sha256 `017da2dac658cbce05081974590ad86ab2f75b6f07b28b0dbe06fb7386e92635`, command `r2 -a arm -b 16 -m 0x4c3ffe00`. The decrement-before-boot path was not isolated and stays UNVERIFIED. |
| 4 | FIXED | `slot-retry-count:b` is MEASURED 1. `tries_remaining` is bits 6:4 (`ubfx r0, r0, 4, 3` at `0x4c453d60`, function `0x4c453d30`). How many failed boots mark `b` unbootable is INFERRED, so one failure can exhaust a count of 1. The operator action at the first loop is the key order below, then reflash the verified backup (R4, SAFETY, T3 warning). |
| 5 | FIXED | Z0.1, T-1.3b, the T3 warning, the bootloop rows, L2, and SAFETY recovery say `Power off, disconnect the cable, hold Vol− + Power until FASTBOOT, release, then reconnect the cable`. V99 checks protocol lines 32, 110, 132, 206, 207, 229 and SAFETY line 58. Case 129 replaces `disconnect the cable` on line 32. |
| 6 | FIXED | `research/FINAL_PLAN.md` (outside this repository) keeps the fenced commands in the protocol's order. Z0.1, T-1.3b, L2, and the first-loop note use the cable order. The pre-flight expects `0x4000000` or `4000000`. The two flash lines name the partition-size gate. R1–R4 in that plan match the measured flags, the INFERRED fall, and the measured retry of 1. The header is restamped to this commit after the hash exists. |
| 7 | FIXED | T-1 pronto: sim. See the selftest line above. The audited file is accepted only when the hash is `3890fb96…829fc7`, the size is 67108864, the magic is `ANDROID!`, and the stub answers `4000000`. |

## Backprop

| Bug | Invariant | Sabotage |
|---|---|---|
| B120 | V98 | case 128 forces decimal arithmetic; case 132 deletes the flash gate |
| B121 | V99 | case 129 drops the disconnect on Z0.1 |
| B122 | V100 | case 130 removes the results heading |
| B123 | V101 | case 131 removes `INFERRED until observed` |

Case 126 now removes `LK hex, optional 0x prefix, in bytes`, which is the phrase V96 checks. Case 19b now removes `Vol− + Power` from protocol line 32, which is the only copy inside the Z0 section. Case 93 now writes `ação exata` over the L2 key attempt, which is the placeholder V74 rejects.
