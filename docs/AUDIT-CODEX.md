# AUDIT-CODEX — maintainer audit of poco-c75-lake-kernel

Maintainer this round: grok, sole editor. Method: audit, fix, test, re-audit, document, commit.
No device was touched. No adb or fastboot binary was run. No private dump was published.
No push, tag, or release. A structural fix gained a §B row, a §V row, a test, and a sabotage.

The previous text of this file described HEAD `9ccf2ef`. Those rows are not reused.
Every line below was checked against the tree that contains this report.

Status words: FIXED (a commit in this mission), ALREADY-FIXED (true at a cited line, not changed again),
REFUTADO (the mission claim is false in current code), REMAINING (not done, with the reason).

Counts: FIXED 84, ALREADY-FIXED 47, REFUTADO 0, REMAINING 3. Total rows 134 (items 1–82, U1–U6, G01–G46). The item table is the source of those counts. Item 70 is inside the FIXED set, not an extra row.

## 1. BASELINE (item 1)

- Inherited point was `c764a5c` plus an uncommitted tree. That tree was committed as
  `ba0e137` (protocol order, getvar classes, doc drift) and `9e0c748` (host-only CI).
- Before the fetch gate, `git status --short` was empty at `9e0c748`.
- `docs/DEVICE-TEST-PROTOCOL.md` is 242 lines. `docs/SAFETY.md` is 64 lines.
- No destructive reset. Nothing was pushed.

## 2. TEST MATRIX

| Check | Result observed this session |
|---|---|
| `./tools/run_all_checks.sh` on `9e0c748` (before the fetch gate) | `run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V75 + gate self-test)`, exit 0 |
| `./tools/selftest_backprop.sh` on that same tree | `SABOTAGENS: 99 detectada(s) FAIL->PASS, 0 falha(s)`, `SELFTEST-BACKPROP PASS`, exit 0 |
| `./tools/run_all_checks.sh` after V76 and again after the README/KMI wording | `run_all_checks: PASS (... + V34-V76 + gate self-test)`, exit 0. Gate line: `SELFTEST PASS (positivo PASS + 4 sabotagens FAIL + 1 exatidão de chave)` |
| `./tools/selftest_backprop.sh` after V76 cases 96–98 and the README/KMI wording | `SABOTAGENS: 102 detectada(s) FAIL->PASS, 0 falha(s)`, `SELFTEST-BACKPROP PASS`, exit 0 |
| `bash -n` on `tools/*.sh` and `scripts/*.sh` | `BASHN:0` |
| `git diff --check` before this report | clean |
| `command -v shellcheck` | `shellcheck: absent` |
| Operator-plan fence comparison (section 6) | protocol fence lines missing from the plan: 0 |

Inner FAIL lines printed while a self-test plants a defect are the sabotage, under an overall PASS.

## 3. ITEM MATRIX

### 3.1 Items 1–17

| # | Status | Where |
|---|---|---|
| 1 | FIXED | Section 1. Baseline recorded, no reset. |
| 2 | FIXED `ba0e137` | `docs/SAFETY.md:10` two protected writes (T-1 and T3). `README.md:90` says the same. |
| 3 | FIXED `ba0e137` | `CONTRIBUTING.md:3` steps Z0/R3/T-1/T2b/T3. |
| 4 | FIXED `ba0e137` | `docs/BUILD.md` has no live step T0. Line 72 calls the RAM path UNKNOWN. |
| 5 | FIXED `ba0e137` | `CHANGELOG.md` has 0.2.0 and 0.2.1. The 0.1.x entries stay as history. |
| 6 | FIXED `ba0e137` | `README.md:3`, `docs/SAFETY.md:3`, `docs/KMI-GATES.md:3` use host-verified, rebuild-reproducible, hardware-unverified, boot-unproven. V69. |
| 7 | FIXED `ba0e137` | `README.md:3` says rebuild-reproducible. `README.md:22` separates GKI, vendor modules, DT/DTBO, firmware, boot metadata, userspace. `README.md:106` no longer says the certificate makes modules keep loading. |
| 8 | FIXED `ba0e137` | `docs/DEVICE-TEST-PROTOCOL.md:66` and `:116`–`:118`: retry 0 is informational. Stop is successful:b=yes and unbootable:b=no. V61. |
| 9 | FIXED `ba0e137` | Protocol lines 52–65: one class per name. `is-userspace` is the only accepted-absent. `max-download-size` is threshold-if-present. V72. |
| 10 | FIXED `ba0e137` | Protocol line 222: charger is advisory, not a day-ending stop. |
| 11 | FIXED `ba0e137` | Protocol lines 67, 116, 118 capture stderr with `2>&1`. V60. |
| 12 | FIXED `ba0e137` | Every ordered fastboot call goes through `tools/fastboot_guard.sh`. The wrapper allowlist is `tools/fastboot_guard.sh:102`; the binary is resolved with `type -P` at line 109. |
| 13 | ALREADY-FIXED | `tools/fastboot_guard.sh:82`–`:83` accepts only `flash boot_b`. |
| 14 | FIXED `ba0e137` | Pre-flight fence checks partition size, file size, and sha256. T-1.3a/T-1.3b re-check identity and slot. V63. |
| 15 | FIXED `ba0e137` | Same split: T-1.3a is Android (`getprop`, `adb shell uname -r`); T-1.3b is keys, then getvar. |
| 16 | FIXED `ba0e137` | Protocol line 11: `fastboot boot` is not a step and its support is UNKNOWN. SPEC §T says absence of the command is not a stop. |
| 17 | FIXED `ba0e137` | The generic "RAM boots leave flash untouched" sentence is gone. V64. |

### 3.2 Items 18–35

| # | Status | Where |
|---|---|---|
| 18 | ALREADY-FIXED | `tools/run_all_checks.sh:75`–`:81`: pass needs exit 0, no FAIL line, and an explicit PASS/OK. |
| 19 | ALREADY-FIXED | The GATE row requires the SELFTEST PASS string and exit 0. |
| 20 | ALREADY-FIXED | V8 requires the facts log to exist and to clear the row floor. Sabotage case 74. |
| 21 | ALREADY-FIXED | SPEC V5: two distinct source tokens, not a claim of semantic independence. |
| 22 | ALREADY-FIXED | SPEC V7 keeps the source token on the claim line. |
| 23 | ALREADY-FIXED | V31 counts fenced `tools/fastboot_guard.sh flash` lines and requires exactly two, both `boot_b`. |
| 24 | ALREADY-FIXED | V21 compares the Z0.3 allowlist multiset. Sabotage cases 18 and 77. |
| 25 | ALREADY-FIXED | V2 flags a multiline or unquoted grep instead of ignoring it. Sabotage case 75. |
| 26 | ALREADY-FIXED | V6 covers `rm`, `dd of=`, `truncate`, `mkfs`, fastboot write, `set_active`, and block-device writes. Cases 7 and 82–85. |
| 27 | FIXED `ba0e137` | V33 also scans `docs/PLAN-AND-FINDINGS.pt-BR.md` and `data/config_safety_table.csv`. Case 95. |
| 28 | ALREADY-FIXED | `scripts/build.sh:79` `require_pristine` refuses a dirty or already-patched tree. `cmd_cert` calls it at line 170. |
| 29 | ALREADY-FIXED | Same state gate. `cmd_clean` returns both projects to pristine (`scripts/build.sh:108`). |
| 30 | ALREADY-FIXED | `require_pristine` checks `git status` and patch state before control and cert. |
| 31 | ALREADY-FIXED | `scripts/build.sh:43` `check_all_projects`; `cmd_sync` calls it at line 98. |
| 32 | ALREADY-FIXED | `scripts/build.sh:100`–`:104` records the resolved HEAD. The tag is labelled metadata. |
| 33 | ALREADY-FIXED | `scripts/build.sh:29`–`:36`: `REPO_NO_VERIFY` must be unset or exactly `1`/`true`/`yes`, with a WARNING. |
| 34 | ALREADY-FIXED | `scripts/build.sh:25`: one disk floor, `83886080` KiB (80 GB). |
| 35 | ALREADY-FIXED | `scripts/build.sh:126` `cmd_record` writes provenance, including `SOURCE_DATE_EPOCH` at line 133. |

### 3.3 Items 36–53

| # | Status | Where |
|---|---|---|
| 36 | FIXED | `tools/fetch_official_artifacts.sh` `safe_name` (`V76-NAME-GATE`) refuses an empty name, a leading dot, an absolute name, any `/`, and any `..` before mkdir or curl. V76. Sabotage case 96. |
| 37 | FIXED | The body is written in a private `mktemp -d` and moved only after the checks. |
| 38 | FIXED | A rejected body is removed. A hash mismatch does not leave a candidate. Sabotage case 98. |
| 39 | FIXED | Published output is `DOWNLOADED` plus exactly one of `HASH-VERIFIED` or `UNVERIFIED`. |
| 40 | FIXED | `check_type` (`V76-TYPE-GATE`) enforces magic and a minimum size per known name. Sabotage case 97. |
| 41 | FIXED | `tools/selftest_fetch.sh` is the structural URL check (V9). Its header says it is not a network smoke test. The default suite does not download the tree. |
| 42 | ALREADY-FIXED | `tools/gate_kmi_crc.sh:54`–`:78` compares export type and namespace. `tools/selftest_gates.sh` now plants one export_type mismatch and expects `XTYPE_MISMATCH`. |
| 43 | ALREADY-FIXED | `docs/KMI-GATES.md:80`: BTF/stgdiff/ABI XML declared out of scope. No baseline is published. |
| 44 | ALREADY-FIXED | Same paragraph: `__kcfi_typeid_*` value comparison is out of scope. Counts 101 and 68 are not a re-runnable check. |
| 45 | ALREADY-FIXED | `docs/KMI-GATES.md:78`: the 1829 inter-module symbols are declared out of scope. The gate stops at vmlinux. |
| 46 | ALREADY-FIXED | `docs/KMI-GATES.md:72`: the TSV is derived and not regenerable without the original modules. |
| 47 | ALREADY-FIXED | `tests/test_dump_modcrcs.py`: bad magic, truncated header, bad `shstrndx`, section out of range, strict vs permissive. |
| 48 | ALREADY-FIXED | Same file: truncated `__versions`, missing `__versions`, slot-prefix collision, divergent CRC for one basename. |
| 49 | ALREADY-FIXED | `tools/verify_modsig.sh` compares the PKCS#7 signer with the Image cert. V67. |
| 50 | ALREADY-FIXED | V68 recomputes the recorded certificate fingerprint in `docs/KMI-GATES.md`. |
| 51 | ALREADY-FIXED | `tests/test_verify_modsig.py:50` and `:60`: unsigned and truncated input exit without a traceback. |
| 52 | ALREADY-FIXED | SPEC V67: the six-case synthetic matrix. |
| 53 | ALREADY-FIXED | `docs/KMI-GATES.md:3`: the gates prove the host contract. They do not prove that modules load on a device. |

### 3.4 Items 54–82

| # | Status | Where |
|---|---|---|
| 54 | ALREADY-FIXED | `tools/repack_boot_v2.py:41`–`:43`: `err` calls `sys.exit(code)`. `tests/test_repack_boot.py:77` locks the code. |
| 55 | ALREADY-FIXED | `tools/repack_boot_v2.py:174`–`:179`: `--keep-footer` requires a byte-identical kernel. |
| 56 | ALREADY-FIXED | `tools/repack_boot_v2.py:228`–`:231`: `avbtool info_image` failure is fatal. Test at `tests/test_repack_boot.py:145`. |
| 57 | ALREADY-FIXED | Roundtrip is part of the fatal post-check. `tests/test_repack_boot.py:129`. |
| 58 | ALREADY-FIXED | Footer structure checks are in `repack_boot_v2.py` (magic, version, offsets, position). |
| 59 | ALREADY-FIXED | Same footer checks cover `original_image_size`, `vbmeta_offset`, and `vbmeta_size`. |
| 60 | ALREADY-FIXED | `tests/test_repack_boot.py:111` rejects a kernel that is not an arm64 Image. |
| 61 | ALREADY-FIXED | The computed new image size is part of the post-check, not a dead variable. |
| 62 | ALREADY-FIXED | Post-check requires partition size, footer at the end, `info_image` success, and an exact roundtrip. |
| 63 | FIXED `ba0e137` | `docs/BUILD.md:72`: `NONE` and rollback index 0 are project choices, not upstream defaults. |
| 64 | FIXED `ba0e137` | `docs/BUILD.md:79` separates the AVB footer from the GKI boot signature. CHANGELOG 0.2.0 names the glossary. |
| 65 | FIXED `ba0e137` | `docs/BUILD.md:83`: dropping the GKI boot signature may affect VTS. Declared, not verified. |
| 66 | FIXED `ba0e137` | `data/config_safety_table.csv` row 2: `hispeed_freq` is not a schedutil knob. V70. |
| 67 | FIXED `ba0e137` | The table has no SEGURO, ARRISCADO, PROIBIDO, "sem risco", or "panic imediato". Categories are LOW-RISK, NEEDS-GATES, REJECTED-BY-CURRENT-CONTRACT. |
| 68 | FIXED `ba0e137` | Columns `gates_status` and `tree_check` exist. Every `gates_status` is UNVERIFIED. |
| 69 | REMAINING | Every `tree_check` cell is `NEEDS-TREE-CHECK`. The pinned kernel tree was not opened. A config name was not compared to that tree. |
| 70 | FIXED | Twelve distinct `https://` tokens in `fonte` were fetched with curl (25 s cap). Six googlesource file URLs and the two third-party repo roots returned 200. Six tokens were the same files with a `:line` suffix and returned 404; the suffix is now a parenthetical line note, and the file URL is the one that returned 200. Line numbers inside those files were not re-read. `gates_status` stays UNVERIFIED: a live URL is not a runtime gate. GitHub and GitLab returning 200 for a repository root does not validate a commit. Those rows already say the evidence is third-party and unverified. |
| 71 | FIXED `ba0e137` | Raw agent output lives in `docs/research/raw/`. `docs/research/README.md` says the notes contain errors. |
| 72 | FIXED `ba0e137` | `docs/FACTS.md` columns are FACT, PROOF, SOURCE, DATE, SCOPE, CONFIDENCE. The file says it is not a copy of all 67 plan rows. |
| 73 | FIXED `ba0e137` | `docs/FACTS.md` section REJECTED. T0/T2 as the live route, a new kernel on slot A, and "1572 is the live count" are in that table. |
| 74 | FIXED `ba0e137` | `docs/FACTS.md` section BROKEN / UNVERIFIED points at `docs/research/README.md` "External links". |
| 75 | FIXED `ba0e137` | Published docs cite `<PRIVATE_DEVICE_DUMP>`, not a dated backup directory, as the dump source. |
| 76 | ALREADY-FIXED | `tests/test_repack_boot.py`, `tests/test_dump_modcrcs.py`, `tests/test_verify_modsig.py`. V65. |
| 77 | ALREADY-FIXED | `bash -n` on every `tools/*.sh` and `scripts/*.sh` exited 0 this session (`BASHN:0`). |
| 78 | REMAINING | `shellcheck` is not installed. The command printed `shellcheck: absent`. No PASS is claimed. The CI workflow does not install it, because an unseen warning set would fail the job. |
| 79 | FIXED `9e0c748` | `.github/workflows/host-checks.yml` runs syntax, `./tools/run_all_checks.sh`, and `./tools/selftest_backprop.sh`. A GitHub execution was not observed. Push is forbidden. Remote result: UNKNOWN. |
| 80 | FIXED `9e0c748` | The same workflow's comment and steps do not fetch the kernel tree and do not call `scripts/build.sh`. |
| 81 | FIXED | New invariants in this mission: V69–V76, sabotage cases 88–98. Earlier bugs already had cases. `grep` of `^case_run` in `tools/selftest_backprop.sh` is 102. |
| 82 | REMAINING | Present and observed: exit-code masking (case 73), keep-footer and `info_image` (the repack unit tests), missing facts log (case 74), destructive-command variants (cases 82–85), export_type mismatch (`tools/selftest_gates.sh`), path traversal (case 96). Not present: a planted CFI value mismatch, because no stock `__kcfi_typeid_*` value set is published (`docs/KMI-GATES.md:80`); a planted run of `require_pristine`, because that function needs the pinned tree and this session did not fetch it (`scripts/build.sh:79`). |

### 3.5 Adendo U1–U6

| # | Status | Where |
|---|---|---|
| U1 | ALREADY-FIXED | `tools/fastboot_guard.sh:79`–`:89`: the image is copied into a private directory, mode 0400, and that copy is what is checked and flashed. |
| U2 | ALREADY-FIXED | `tools/fastboot_guard.sh:85` refuses a missing or non-regular file before any flash. `tools/selftest_fastboot_guard.sh:128` covers a dash-prefixed name. |
| U3 | ALREADY-FIXED | `tests/test_verify_modsig.py:50`: a bad carve exits clean, without a traceback. |
| U4 | ALREADY-FIXED | `tools/gate_kmi_crc.sh` joins with `LC_ALL=C` discipline in the gate self-test. `tools/selftest_gates.sh` expects `MISSING_EXPORT` when the symbol only grows a suffix. |
| U5 | ALREADY-FIXED | `tools/selftest_gates.sh` expects a different pattern for a bad CRC, a dropped export, an empty symvers, a prefix collision, and an export_type mismatch. The run this session printed SELFTEST PASS. |
| U6 | ALREADY-FIXED | `tools/repack_boot_v2.py:84`–`:85` refuses identical input and output. `tests/test_repack_boot.py:116` rejects a dash-prefixed output path. `tests/test_repack_boot.py:122` rejects the same path. |

### 3.6 Adendo 2 (G01–G46)

All 46 were real against the ancestor the review read. None is still the live procedure.

| # | Status | Where |
|---|---|---|
| G01 | FIXED `ba0e137` | `docs/PLAN-AND-FINDINGS.pt-BR.md:3` marks T0/T2 and a new kernel on slot A REJECTED. |
| G02 | FIXED `ba0e137` | SPEC §T: absence of `fastboot boot` is not a stop. The two `boot_b` writes continue through the wrapper. |
| G03 | FIXED `ba0e137` | SPEC V46/V47 require the wrapper. They do not require a shell `command` bypass. |
| G04 | FIXED `ba0e137` | Protocol lines 66 and 217. Retry 0 is not a T2b stop. |
| G05 | FIXED `ba0e137` | Protocol lines 64–65: `slot-successful` is required and the accepted-absent block says it is not accepted-absent. |
| G06 | FIXED `ba0e137` | `max-download-size` is threshold-if-present in Z0 and in the R3 row (protocol line 79). |
| G07 | FIXED `ba0e137` | Table order T2b-pre, T3, T2b-post (lines 116–118). T3 pass is `OKAY` and "Do not reboot yet". V73. |
| G08 | FIXED | The operator plan outside the git tree has zero `command fastboot`. Comparison section 6. |
| G09 | FIXED | That plan has zero `slot-retry-count:b > 0` gates. Retry is record-only (plan lines 15–16). |
| G10 | FIXED | Plan line 16: a connected charger does not end the day. |
| G11 | FIXED `ba0e137` | `docs/PLAN-AND-FINDINGS.pt-BR.md` fact 11 is three layers. `docs/FACTS.md` REJECTED keeps the fallback claim from being a single label. |
| G12 | FIXED `ba0e137` | Plan fact F3 / `docs/FACTS.md`: a rebuilt Image is the same size, not the official hash. The official hash belongs to the unpacked stock Image. |
| G13 | FIXED `ba0e137` | Plan banner and protocol rule 3: slot A is not the test slot. |
| G14 | FIXED `ba0e137` | Fact 21 proof is the host hash of the backup set. No `adb shell su` step. |
| G15 | FIXED `ba0e137` | `docs/FACTS.md` REJECTED: 1572 is not the live count. The live gate number is 2309. The historical 215-module label 1573 was not recomputed. |
| G16 | FIXED `ba0e137` | `SPEC.md` header says V1–V9 and V14–V76. |
| G17 | FIXED `ba0e137` | `CHANGELOG.md` keeps 0.1.2 and adds 0.2.0 and 0.2.1. |
| G18 | FIXED `ba0e137` | V49 / the 429 line says "example only" and "your number is your baseline". |
| G19 | FIXED `ba0e137` | `CONTRIBUTING.md:3`. |
| G20 | FIXED `ba0e137` | `docs/BUILD.md` does not claim an unsourced "12 min on 6". |
| G21 | FIXED `ba0e137` | `docs/BUILD.md:72` does not call the two certificate choices a measured result. |
| G22 | FIXED `ba0e137` | Fact 37 is the symbol list. Device load is UNVERIFIED. Machine paths are not in the proof cell. |
| G23 | FIXED `ba0e137` | `docs/KMI-GATES.md:10`: the 101/68 kCFI counts are not re-runnable from this repo. |
| G24 | FIXED `ba0e137` | The Z0 heading is not "zero-risk". Protocol line 71: "What Z0 does not prove". V72. |
| G25 | FIXED `ba0e137` | `docs/SAFETY.md` bad-`boot_b` row does not call the rehearsal risk-free. |
| G26 | FIXED `ba0e137` | Plan Q3 is UNKNOWN and outside the protocol. |
| G27 | FIXED `ba0e137` | `docs/KMI-GATES.md:3`: gates do not prove modules load. |
| G28 | FIXED `ba0e137` | `README.md:23` says device load is not yet tested. `README.md:106` matches that. |
| G29 | FIXED `ba0e137` | The README title is not "customize it safely". |
| G30 | FIXED `ba0e137` | SPEC has one B76 row. |
| G31 | FIXED `ba0e137` | The certificate fingerprint is the V68 check, not V50. V50 is pstore. |
| G32 | FIXED `ba0e137` | `README.md` layout separates `data/` and `tools/data/`. CRC path cited as `tools/data/modules_required_crcs.tsv`. |
| G33 | FIXED `ba0e137` | Protocol line 7 cites REVIEW3 as a review of a discarded list. It does not cite a missing command file as if it were in-tree. |
| G34 | FIXED `ba0e137` | The protocol identity line says the raw getprop was not published. |
| G35 | FIXED `ba0e137` | Symptom rows and R1–R4 use `PROTO:N#token` / `SAFETY:N#token`. V75. |
| G36 | FIXED `ba0e137` | `docs/BUILD.md` does not point the reader at step T0. |
| G37 | FIXED `ba0e137` | Fact 7 proof is not a missing `research/kmi_*.txt`. The live files are `data/kmi_abi_union_r12.txt` (8962 lines) and the gate output. |
| G38 | FIXED | This file. The old text had no section 5 and stopped at the `9ccf2ef` snapshot. |
| G39 | FIXED | The operator plan header cites protocol commit `ba0e137a662fe3e719a4265b0eb4b7b2f29b3552` (242 lines) and SAFETY of that commit (64 lines). |
| G40 | FIXED `ba0e137` | Protocol line 229: L2 is one Vol−+Power attempt, then the wrapper rollback or stop. The words "ação exata" are not on that row. V74. |
| G41 | FIXED `ba0e137` | Protocol line 230: L3 says Parar and Não repetir. |
| G42 | FIXED `ba0e137` | T-1.3a does not run getvar on Android. T-1.3b runs getvar after the key entry. |
| G43 | FIXED `ba0e137` | Protocol line 231: L4 stays in fastboot and rolls back with the wrapper. |
| G44 | FIXED | Operator plan line 27 lists `protect2` before `protect1`. |
| G45 | FIXED `ba0e137` | `docs/KMI-GATES.md` separates the 17 shared names from the 170 rows that carry two vermagic strings. |
| G46 | FIXED `ba0e137` | Protocol line 66 heading is `Z0.4 (PASS/STOP)`. |

## 4. BUGS FIXED

Registry additions this mission: B82–B90 in `SPEC.md`, invariants V69–V76.
Commits: `ba0e137`, `9e0c748`, and the fetch-gate commit that precedes this report.
The operator plan is outside the git tree, so G08, G09, G10, G39, and G44 have no blob in git. The comparison in section 6 is the proof.

## 5. BUGS REMAINING

1. Item 69. `tree_check=NEEDS-TREE-CHECK` on every config row. The pinned tree was not checked out.
2. Item 78. `shellcheck` is absent. No lint PASS is claimed.
3. Item 82, two named sabotages only. No planted CFI value mismatch (no published value set). No planted `require_pristine` run (no pinned tree).

## 6. UNKNOWN

- Hardware boot, Wi-Fi, Bluetooth, modem, camera, and on-device A/B fallback. SPEC §T stays open. This is not FOUND-TIER-0 and not FOUND-PERFECT. Host, source, KMI, and the build recipe are FOUND-TIER-1 only where a command in this repo printed PASS.
- `fastboot boot` support on this bootloader. UNKNOWN. Not a step. The operator plan mentions it twice, both as a prohibition (plan lines 13 and 21).
- Remote GitHub Actions. The workflow file is in `9e0c748`. No run was observed.
- Item 70 line numbers inside the fetched files. The file URL returned 200. The line was not opened.
- Third-party repository roots (the OWLXS and susfs URLs) returned 200. That does not confirm the commits named next to them.

### Operator-plan comparison

The plan was regenerated from the 242-line protocol. Fenced non-comment lines were compared after stripping a trailing `#` comment. The plan also repeats getvar lines that the protocol writes outside a fence, which is why the plan count is higher.

```
protocol_fenced 13
plan_fenced 36
protocol_fence_missing_from_plan 0
command_fastboot 0
retry_gt_0 0
home False
tmp False
zero_risk_phrase False
fastboot_boot_lines 2
```

`fastboot_boot_lines 2` are the two prohibition lines, not a command to run.

## 7. COMMAND OUTPUTS

```
run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V75 + gate self-test)
EXIT:0
SABOTAGENS: 99 detectada(s) FAIL->PASS, 0 falha(s)
SELFTEST-BACKPROP PASS
EXIT:0
```

That pair is the tree at `9e0c748`, before V76.

```
V76   PASS
GATE  PASS
run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V76 + gate self-test)
EXIT:0
SELFTEST PASS (positivo PASS + 4 sabotagens FAIL + 1 exatidão de chave)
SABOTAGENS: 102 detectada(s) FAIL->PASS, 0 falha(s)
SELFTEST-BACKPROP PASS
EXIT:0
BASHN:0
DIFFCHECK:clean
shellcheck: absent
```

Observed on the tree that already contained this report, the config-table URL edit, and the fetch publish gate, before the count lines above were corrected from 85/46 to 84/47:

```
run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V33 + V34-V76 + gate self-test)
EXIT:0
SABOTAGENS: 102 detectada(s) FAIL->PASS, 0 falha(s)
SELFTEST-BACKPROP PASS
EXIT:0
BASHN:0
DIFFCHECK:clean
shellcheck: absent
```

The item table was already 84 FIXED, 47 ALREADY-FIXED, 0 REFUTADO, 3 REMAINING when those two commands ran. The header and section 9 were the lines that still said 85 and 46.

Fonte URL codes (curl, follow redirects, 25 s):

| Code | Token |
|---|---|
| 200 | googlesource `.../gki_defconfig` |
| 200 | `source.android.com/.../stable-kmi` |
| 200 | googlesource `.../init/Kconfig` |
| 200 | googlesource `.../lib/Kconfig.debug` |
| 200 | googlesource `.../kernel/module/version.c` |
| 200 | googlesource `.../arch/arm64/Kconfig` |
| 200 | `github.com/OWLXS/android_kernel_common` |
| 200 | `gitlab.com/simonpunk/susfs4ksu` |
| 404 | the six tokens that appended `:227`, `:80-88`, `:202-205`, `:909-921`, `:97`, or `:1407-1510` to a file URL |

## 8. FILES CHANGED

`ba0e137` — protocol, SAFETY, SPEC V69–V75, PLAN, FACTS, KMI-GATES, BUILD, README, CONTRIBUTING, CHANGELOG, config table, research raw move, check scripts, sabotage cases 88–95.
`9e0c748` — `.github/workflows/host-checks.yml` only.
Fetch-gate commit — `tools/fetch_official_artifacts.sh`, `tools/selftest_fetch_publish.sh`, `tools/selftest_fetch.sh`, `tools/selftest_gates.sh`, `tools/selftest_backprop.sh`, `tools/run_all_checks.sh`, `SPEC.md`, `CHANGELOG.md`, `README.md`, `docs/KMI-GATES.md`, `data/config_safety_table.csv`.
This report — `docs/AUDIT-CODEX.md`.
Outside git — the operator plan cited in section 6.

## 9. FINAL STATUS

FIXED 84. ALREADY-FIXED 47. REFUTADO 0. REMAINING 3 (items 69, 78, 82).
Sabotage proof on the tree that contains this report's item table: 102/102, exit 0.
Host checks on that same tree: PASS, exit 0.
Device boot: not tested. No image was flashed.
