# FIX20 report

No device command was run for this edit. Nothing was pushed.

INTENT: T3 acceptance compares a captured `dmesg` with the normalized stock boot. The CRC gate fails when a required symbol has no provider, except the one stock exception.

Counts: fixed 2, refutados 0. Open: none in this review. LK write atomicity stays UNVERIFIED. The impact of `mtk_em` not loading stays UNVERIFIED.

## Items

1a. `data/stock_dmesg_known.txt:18` is the stock line `mtk_em: Unknown symbol calc_eff_hook (err -2)`. The file holds 11 normalized signatures. Timestamps, TIDs, `CPU:`/`PID:`, `+0x` offsets, and `0x` addresses of 8 or more hex digits are removed. Each signature has an origin comment (stock dmesg line and inventory verdict). `Call trace:` contributes the signature above the trace, not the frame dump. The set is 7 `WARNING:` lines (4 vendor fechado, 3 GKI: 1 policy, 2 UNVERIFIED), 3 cmdq `dump_stack` lines (vendor fechado, not part of the 7), and the `mtk_em` unknown-symbol line. Correctable in this kernel: 0.

1b. `tools/dmesg_new_errors.sh:18` applies that same normalization and prints only lines absent from the known file. Exit 0 when none, 1 when any. `docs/DEVICE-TEST-PROTOCOL.md:181` is the acceptance command: `adb shell dmesg > t3_dmesg.txt; tools/dmesg_new_errors.sh t3_dmesg.txt`. `docs/DEVICE-TEST-PROTOCOL.md:172` states the criterion. `docs/DEVICE-TEST-PROTOCOL.md:180` expects exit 0 and no output. The historical token grep stays on lines 183-184 as the fixture control, so `tools/check_regex_controls.sh` did not need a logic change.

1c. `tests/fixtures/dmesg_stock_self.txt:1` is the stock-shaped log (the 8 warning and unknown-symbol lines, plus a `Call trace:` stanza after each cmdq line). Fed to the script it exits 0. `tests/fixtures/dmesg_plant_symbol.txt:1` is `foo: Unknown symbol bar (err -2)` and exits 1, printing that line. `tests/fixtures/dmesg_plant_warn.txt:1` is a new `WARNING:` and exits 1, printing the normalized line. `tools/check_protocol_invariants.sh:1481` runs those four inputs on every invariants pass. The known file fed to itself also exits 0.

2. `tools/gate_kmi_crc.sh:86` subtracts the new vmlinux exports, `data/vendor_ko_exports.tsv`, and `data/gki_ko_exports.tsv` from the required set, then subtracts `data/kmi_unresolved_stock.tsv`. A remainder is printed as `UNRESOLVED <symbol>` (`tools/gate_kmi_crc.sh:98`) and the verdict is FAIL (`tools/gate_kmi_crc.sh:100`). The vmlinux CRC compare, `missing_exports`, export type, and namespace checks are unchanged. `data/kmi_unresolved_stock.tsv:5` is `calc_eff_hook`. `data/vendor_ko_exports.tsv` is 4369 symbol/basename rows from `__ksymtab_*` (`nm` without `-g`) over the 557 ramdisk and vendor_dlkm modules. `data/gki_ko_exports.tsv` is the same extraction for `rfkill.ko` and `libarc4.ko` (17 names). The 9 protected imports are providers in that GKI table. They are not on the allowlist.

   Before this patch the official-symvers run printed PASS with `compared=2309`, `mismatches=0`, `missing_exports=0`, `conflicting_crcs=0`, `export_type_mismatches=0`, `namespace_mismatches=0` (`modules.files=557`, `modules.unique=370`, `symbols.required=4138`, `symbols.reference_provides=2309`). After the patch the same run adds `unresolved=0` and still prints PASS. Deleting the `calc_eff_hook` row printed `unresolved=1`, `UNRESOLVED calc_eff_hook`, and FAIL. The row was restored. The pre-allowlist remainder is only `calc_eff_hook`.

3. `docs/KMI-GATES.md:97` documents the three tables and the allowlist. `docs/KMI-GATES.md:99` records T-1 PASS (2026-10-10): flash OKAY in 2.3 s, same build and uname, 429 modules, slot variables identical before and after, including retry-count 1. `docs/DEVICE-TEST-PROTOCOL.md:280` is the results section with the same facts, the 7/4/3 inventory, the 3 cmdq traces, and `mtk_em` not loading (IMPACT UNVERIFIED). `SPEC.md:229` records the same T-1 paragraph. `CHANGELOG.md:3` is 0.2.8. The 0.2.7 counts were not rewritten.

4. `SPEC.md:155` is B136 (empty-grep acceptance rejected the stock boot) and maps to V114 (`SPEC.md:339`). `SPEC.md:156` is B137 (a provider-less required symbol passed the gate) and maps to V115 (`SPEC.md:340`). `tools/check_protocol_invariants.sh:1466` enforces V114. `tools/check_protocol_invariants.sh:1495` enforces V115 as a text check (the gate source names the three tables and the allowlist contains `calc_eff_hook`). `tools/run_all_checks.sh:100` and `tools/run_all_checks.sh:142` count V114 and V115 (116 checks). `tools/selftest_backprop.sh:608` is case 145: replacing the acceptance command with an empty grep fails V114. `tools/selftest_backprop.sh:611` is case 146: deleting the allowlist row makes `tools/gate_kmi_crc.sh` print `UNRESOLVED calc_eff_hook`. `tools/selftest_backprop.sh:615` is case 147: renaming the `UNRESOLVED` report in the gate fails V115.

## Checks

`./tools/run_all_checks.sh` PASS, through V34–V115 plus the CRC gate (116 checks). `./tools/selftest_backprop.sh` 151/151, SELFTEST-BACKPROP PASS. `./tools/selftest_fastboot_guard.sh` PASS.
