# SPEC — bug registry, invariants and what is still unproven

This file exists so that a mistake found once cannot come back silently. Every real error found
while building this project is written down in §B, turned into an invariant in §V, and given a
command that fails when the error reappears. Run all of it with:

```bash
tools/run_all_checks.sh          # prints PASS/FAIL per invariant V1..V9, exit != 0 on any FAIL
tools/selftest_backprop.sh       # proves each check catches its own defect (FAIL -> PASS)
```

The checks are read-only; the only temporary directories they create come from `mktemp -d` and are
removed by a `trap`. Nothing here touches a device, a partition image or a build tree.

## §B — bug registry (one row per real error, with the rule that would have prevented it)

| id | date | root cause (one sentence) | invariant |
|---|---|---|---|
| B1 | 2026-10-05/06 | The published CRC gate covered 215 modules while README/KMI-GATES claimed 557, and nothing compared the docs against the gate's own numbers. | V1 |
| B2 | 2026-10-06 | A device command in the protocol used `grep -iE "a\|b"` — in `-E` the `\|` is a literal pipe, so the pattern could never match and the dmesg acceptance passed on nothing. | V2 |
| B3 | 2026-10-06 | The plan told the operator to test on "the inactive slot A", which on the audited device holds older firmware (OS3.0.20.0) over newer data. | V3 |
| B4 | 2026-10-06 | `fastboot boot` of a v4 boot image is likely rejected by this LK (legacy `page_size = 0` in the v4 header), but the docs presented RAM boot as available. | V4 |
| B5 | 2026-10-06 | "ramoops is absent" was claimed from a single probe (device tree only); the bootloader injects the region through the command line. | V5 |
| B6 | 2026-10-06 | Scripts used `rm -rf` on fixed `/tmp` paths, which can delete a user's directory when the path is wrong. | V6 |
| B7 | 2026-10-06 | "The vermagic `-ab…` suffix must match or the module is refused" was false (`same_magic()` ignores the release token when modules carry CRCs), and the claim cited no source. | V7 |
| B8 | 2026-10-06 | Agent research notes contained `FACT` claims with no source and invented links, and nothing forced a proof for a fact in the log. | V8 |
| B9 | 2026-10-06 | A "the fetch is broken" finding was produced by testing a URL the script never uses. | V9 |
| B10 | 2026-10-06 | The acceptance criterion "dmesg has no `Unknown symbol`…" had no runnable command at all — no reader could execute it, and no control existed (found by V2 while writing it). | V2 |
| B11 | 2026-10-06 | Six "X does not exist / is UNKNOWN" claims in SAFETY.md and the test protocol rested on a single observation, with no second independent source on the line (found by V5). | V5 |
| B12 | 2026-10-06 | `tools/verify_modsig.sh` used `grep -i "serial\|issuer"` — BRE alternation that is unnecessary and is the same confusing construct as B2 (found by V2, shell-scripts scope). | V2 |
| B13 | 2026-10-06 | `docs/KMI-GATES.md` asserted that nine imported symbols are *protected exports of Google-signed GKI modules* with no source for that set (found by V7). | V7 |
| B14 | 2026-10-06 | Claims about this device's bootloader (order of size/allowlist checks before a write) were supported by LK **source of a different device** (dguidipc/gemini-lk, MT6797) — behaviour the real `lk_b.img` never evidenced. | V14 |
| B15 | 2026-10-06 | The legacy (v2-header) RAM-boot was offered as a safe test path although the image carries no `androidboot.*`/`slot_suffix` and nothing proves the LK injects them — Android could come up slot-less and mount the old slot-A system over current data. | V15 |
| B16 | 2026-10-06 | The protocol demanded a STOP unless `fastboot getvar is-userspace` answers `no`, but that variable may not exist in the real LK (its runtime behaviour is unverified) — a guaranteed false STOP. | V16 |
| B17 | 2026-10-06 | A review report marked the bootloader's check order as "PROVED" from `strings` output alone — strings prove a message exists, not the order in which code reaches it. | V17 |
| B18 | 2026-10-06 | The protocol's first write was the new kernel itself: nothing demonstrated the flash path beforehand with identical, zero-risk content. | V18 |
| B19 | 2026-10-06 | The SAFETY bootloader table recorded fallback behaviour as UNKNOWN although RE2/RE4 had measured it by disassembling the real `lk_b.img` (immediate same-boot fallback; both-invalid lands in a non-returning `fastboot_init`; retry mechanics partly unproven). | V19 |
| B20 | 2026-10-06 | Historical wording ("`is-userspace` may not exist") could leak back into an instruction as an absence claim about the real binary, where the string measurably exists. | V20 |
| B21 | 2026-10-06 | Z0 ran an open-ended getvar list with no prohibition of `getvar all` or any `oem`, while the real LK carries `oem allow-wipe-userdata yes` (freebuff A1). | V21 |
| B22 | 2026-10-06 | `adb reboot bootloader` was usable as the Z0 entry, testing a warm path instead of the cold key path T-1/T3 recovery needs (freebuff A2). | V22 |
| B23 | 2026-10-06 | No rule said what to do when `current-slot` is not `b`; a plain `fastboot reboot` there would boot the old slot-A firmware over new data (freebuff A3b/A7). | V23 |
| B24 | 2026-10-06 | Z0 did not require the charger disconnected, so the LK could park in off-mode-charge instead of booting (freebuff A4). | V24 |
| B25 | 2026-10-06 | No keys-only procedure existed for adb not coming back in 3 min, inviting USB improvisation (freebuff A5). | V25 |
| B26 | 2026-10-06 | `~429` modules was usable as the acceptance number instead of the day baseline superset (freebuff A4/A6). | V26 |
| B27 | 2026-10-06 | Z0 stated no honest list of what it does not prove, inviting false confidence (freebuff A6). | V27 |
| B28 | 2026-10-06 | `tools/*.sh` were mode 100644 in the index while `README.md` tells the reader to execute them directly ("permission denied"). | V28 |
| B29 | 2026-10-06 | The SAFETY bootloader table listed a wrong protected set (`preloader*`, `seccfg`, `expdb`) — disassembly shows exactly 7 controlled + 7 erase-forbidden names, and none of `lk`/`seccfg`/`expdb`/`misc`/`boot_para`/`vbmeta`/`vendor_boot` is in either. | V29 |
| B30 | 2026-10-06 | T2b ordered `fastboot getvar all`, contradicting the closed-allowlist discipline the protocol itself requires. | V30 |
| B31 | 2026-10-06 | `README.md` said "one protected write of `boot_b`" after the protocol grew a second one (T-1 backup). | V31 |
| B32 | 2026-10-06 | The T-1 section sat before R3 while depending on it ("In fastboot (after R3)"). | V32 |
| B33 | 2026-10-06 | Published research notes carried machine paths (`/tmp/...`, `/home/...`) against the repo's own redaction promise. | V33 |
| B34 | 2026-10-06 | V29 checked the whole SAFETY.md file instead of the specific table rows, allowing a name removed from the table row to still pass if it appeared elsewhere (e.g., in the never-touch rule). | V29 |
| B35 | 2026-10-06 | The never-touch rule (rule 1) omitted `misc`, `boot_para`, `expdb` even though the SAFETY table explicitly states the bootloader does not protect them and the protocol already forbids touching them. | V34 |
| B36 | 2026-10-06 | V29 only checked table rows exist in SAFETY but not that SAFETY rows match TSV exactly (bidirectional); extra names in table rows were not caught. | V29 |
|---|---|---|---|
| B37 | 2026-10-06 | "Z0 writes nothing" in the protocol header contradicted Z0.0 which admits `adb reboot bootloader` writes a boot reason. | V35 |
| B38 | 2026-10-06 | SAFETY.md said "single protected T3 command" after the protocol grew T-1. | V36 |
| B39 | 2026-10-06 | V2 only covered greps in the protocol; reader-runnable greps in README/SAFETY/BUILD/KMI-GATES had no positive/negative controls. | V37 |
| B40 | 2026-10-06 | V21 allowed extra `getvar` commands outside the closed allowlist by only checking presence of the 15 names. | V38 |
| B41 | 2026-10-06 | V18 sentinel ("one and only write command") did not exist in any doc; the real contradiction is "single write" vs two writes. | V39 |
| B42 | 2026-10-06 | V22/V26 accepted loose tokens (`powered off` + `Vol` anywhere; `429` + `reference` on same line) without co-location. | V40 |
| B43 | 2026-10-06 | `docs/research/README.md` missing the V8 "contain errors" warning and UNVERIFIED link table. | V41 |
| B44 | 2026-10-06 | V30 filter for `getvar all` was too permissive: a line mentioning "allowlist" but ordering `getvar all` as executable passed. | V42 |
| B45 | 2026-10-06 | `current-slot != b` exception said "old slot not barred by rollback" but rollback index 0 means LK **can** boot old slot A (RE4 D3). | V43 |
| B46 | 2026-10-06 | `is-userspace` text said string "may not exist" but the string measurably exists in the LK getvar table. | V44 |
| B47 | 2026-10-06 | Check-before-write order cited as INFERRED (other device) but RE1 §3.3 measured it in the real binary (check `bl 0x4c4367d2` precedes write `bl 0x4c436834`). | V45 |
| B48 | 2026-10-06 | T-1.2 and T2b steps referenced commands indirectly; the exact commands were not inline. | V46 |
| B49 | 2026-10-06 | T-1 used `command fastboot` to bypass the shell guard but T3 did not; the guard blocks both. | V47 |
| B50 | 2026-10-06 | `protect1`/`protect2` order differed across docs; measured table has `protect2` then `protect1`. | V48 |
| B51 | 2026-10-06 | Baseline "429 modules" presented as the audited device's number without clarifying it's an example; the reader's number is their own baseline. | V49 |
| B52 | 2026-10-06 | No guidance on when/how to read `pstore` (next normal boot on a good kernel). | V50 |
| B53 | 2026-10-06 | "Never touch" list in SAFETY.md presented as bootloader protection; it is project policy, wider than LK tables. | V51 |
| B54 | 2026-10-06 | "Accept in writing" for slot firmware comparison was unspecified (how to document). | V52 |
| B55 | 2026-10-06 | Six symptom lacunae not covered in abort criteria (EDL mode, fastboot OKAY but no boot, hardware failure, guard bypass, locked bootloader, empty pstore). | V53 |
| B56 | 2026-10-07 | Status-checked `printf ... | grep -q` pipelines in `tools/*.sh` flaked under load (`grep -q` exits early, writer dies with SIGPIPE=141, `pipefail` reports FAIL on present text); 33 sites converted to herestrings, V38's dead extra-getvar check (escaped backticks) fixed. | V54 |
| B57 | 2026-10-07 | Symptom-table cross-references cited a SAFETY line for the userdata-backup fact that lives 3 lines above (SAFETY:11 vs :8); dangling/stale `PROTO:NN`/`SAFETY:NN` refs go uncaught when edits shift lines. | V55 |
| B58 | 2026-10-07 | README described the check suite with stale fixed ranges ("V1–V9 + V14–V17", "14 sabotage cases") and omitted `check_sigpipe.sh` from the tools list — same drift class as B31/B38. | V39 |
| B59 | 2026-10-07 | SAFETY recovery path showed the rollback as bare `fastboot flash` (guard would block it); same inconsistent-form class as B47. | V47 |
| B60 | 2026-10-07 | T-1.3 and the baseline row gave on-device observation commands (`uname -r`, `getprop`, `cat /proc/modules`, `dmesg`, `ls /sys/fs/pstore`) without the `adb shell` prefix — a reader at a host shell would measure the host, not the device (the acceptance block already uses `adb shell`). | V56 |

### TWINS — the same pattern searched across the whole repository

Per the fable rule, each bug was searched for again everywhere:

- TWINS: searched `corpus numbers quoted as 557/370/4138/2309 vs other values` — found 4 other sites: `docs/PLAN-AND-FINDINGS.pt-BR.md` (facts 7/20/22/23, all corrected and proof-bearing), `docs/KMI-GATES.md:59` (the historical "1573", explicitly labelled as the 215-module subset), `docs/research/CODEX5_build_signing.md`, `docs/research/AUDIT_codex.md` (raw notes, marked "contain errors"). Ensured those are the only ones the checks do not assert, and V1 covers the rest.
- TWINS: searched `grep -E/-iE with escaped \|` — found 8 other sites: `docs/research/REVIEW3_codex_fmea.md` lines 289-294 (table cells), `docs/research/OPENCODE3_mtk_gki_failures.md` (81, 85), `docs/research/AUDIT_antigravity.md:156` (all inside the raw notes, which carry the "contain errors" warning and are not executable instructions) and `tools/verify_modsig.sh:104` (fixed, see B12).
- TWINS: searched `instruction that can reach the other slot` — found 4 other sites: `docs/DEVICE-TEST-PROTOCOL.md:13,21,32,51`, `docs/SAFETY.md:9`; all are prohibitions or the comparison requirement, verified by V3.
- TWINS: searched `fastboot boot` — found 14 sites outside the raw notes (`README.md`, `DEVICE-TEST-PROTOCOL.md`, `SAFETY.md`, `BUILD.md`, `KMI-GATES.md`, `PLAN-AND-FINDINGS.pt-BR.md`); V4 asserts on all of them that no site claims support and that the UNKNOWN caveat is present.
- TWINS: searched `absence phrasing without two sources` — found 6 sites (`docs/SAFETY.md:7,8,10,16`, `docs/DEVICE-TEST-PROTOCOL.md:11,12`), all fixed (B11) and now checked by V5.
- TWINS: searched `rm -rf` — found 3 other sites, all in `tools/` (`gate_kmi_crc.sh:17`, `selftest_gates.sh:13`, `verify_modsig.sh:20`), all already `mktemp -d` + `trap`; V6 covers the whole `tools/`+`scripts/` tree.
- TWINS: searched `claim about kernel behaviour without a source` — found 8 sites (`README.md:24,25`, `docs/KMI-GATES.md:9,11,13,75`, `docs/SAFETY.md:16,18`); the one without a citation was `KMI-GATES.md:75` (fixed, B13), and V7 now enforces a citation on all of them.
- TWINS: searched `fact row without a proof column` — found 0 of 67 rows in `docs/PLAN-AND-FINDINGS.pt-BR.md`; the 199 `FACT` mentions inside `docs/research/` are raw notes covered by the warning asserted in V8.
- TWINS: searched `ci.android.com/builds/submitted` — found 3 other sites (`docs/research/CODEX2_kleaf_repro.md:14,27,137`, raw notes) plus the script itself (`tools/fetch_official_artifacts.sh:12`); V9 tests the script's own URL, not a copy of it.
- TWINS: searched `bootloader-behaviour claims sourced from another device` — found 2 sites: `docs/research/OPENCODE2e_lk_repack_review.md` (raw note, carries the "contain errors" warning) and the now-labelled INFERRED row in the `docs/SAFETY.md` LK table; V14/V17 enforce the label.
- TWINS: searched `RAM-boot presented as a safe path` — found 3 sites, all now negative or discarded: `README.md` ("tested **in RAM (`fastboot boot`)** before anything is written" — reworded to point at the protocol), `docs/SAFETY.md` rule 4 and `docs/DEVICE-TEST-PROTOCOL.md` rule 1; V15 forbids an executable RAM-boot step in the protocol.
- TWINS: searched `getvar checks that assume a variable exists` — found 1 site: the protocol's `is-userspace` check (fixed, accepts `Variable not found`); the other getvars in R3/Z0 are already phrased as "when the bootloader exposes them"; V16 keeps the tolerated-answer list in the doc.
- TWINS: searched `write steps without a rehearsal` — found 1 site: the protocol's T3 was the first write (fixed, T-1 reflashes the hash-verified backup first); V18 keeps the T-1 gates (Z0 PASS, owner yes, hash check, no stale single-write sentence).
- TWINS: searched `bootloader fallback stated as UNKNOWN` — found 1 site: the SAFETY LK table (fixed, disassembly rows with RE2/RE4 cites); V19 keeps the cites and the UNVERIFIED labels on what is still unproven.
- TWINS: searched `is-userspace described as absent` — found 0 sites in instructions (only the historical B16 row and raw notes, both out of V20 scope); V20 rejects any such sentence if one appears.
- TWINS: searched `getvar outside a closed list` — found 1 site: the Z0 section (fixed, 15-line allowlist + `getvar all`/`oem` prohibition); V21 keeps every name and both prohibitions.
- TWINS: searched `adb reboot as a pass criterion` — found 1 site: Z0.0 (fixed, marked optional/documentary); V22 keeps the wording.
- TWINS: searched `reboot on slot mismatch` — found 1 site: Z0.4 exception (fixed, power off by keys); V23 keeps the `never \`fastboot reboot\`` rule.
- TWINS: searched `charger` in preconditions — found 1 site: Z0 preconditions (fixed, disconnected); V24 keeps it.
- TWINS: searched `no-adb-back procedure` — found 1 site: Z0.6 (fixed, 3 min + keys once + day ends); V25 keeps all three tokens.
- TWINS: searched `429 as acceptance` — found 1 site: Z0.6 (fixed, day baseline is the criterion, `429 modules` carries "example only; your number is your baseline"); V26 keeps both phrases on the 429 line.
- TWINS: searched `what Z0 does not prove` — found 1 site (fixed, honest list); V27 keeps the header.
- TWINS: searched non-executable `tools/*.sh` — the index listed 7 files at 100644; V28 keeps index mode 100755 and on-disk +x.
- TWINS: searched `protected-name claims` — the SAFETY row and the NEVER-type paragraph were rewritten from the measured tables; V29 keeps all 14 names plus the 7 NOT-in-either-table sentences.
- TWINS: searched `getvar all` outside research — remaining sites are prohibitions only (Z0.3); V30 rejects any executable use.
- TWINS: searched `fastboot flash` in the protocol — exactly 2 command lines remain (T-1 block line, T3 block line), both `boot_b`, plus 2 table-cell references (bootloop rollback, L2 symptom) that are not commands; V31 counts command-position lines only.
- TWINS: searched `### T-1` position — section now follows R3/pre-flight; V32 keeps the order.
- TWINS: searched `/tmp/|/home/` in research notes — fixed files: RE2, RE4, RE1 (new copy), FIX8/FIX9 reports; V33 keeps all non-README notes clean.
- TWINS: searched `Z0 header contradiction` — found 1 site: the Z0 header (fixed, mandatory/optional distinction + boot reason); V35 keeps the wording.
- TWINS: searched `single T3 write claim` — found 1 site: SAFETY.md rule 4 (fixed, now says two protected writes); V36 keeps the wording.
- TWINS: searched `regex controls outside protocol` — reader-runnable `grep -E` found only in the protocol; README/SAFETY/BUILD/KMI-GATES carry none, so V37's extension is vacuously green and any future one is covered.
- TWINS: searched `allowlist extra getvar` — found 1 site: Z0.3 (fixed, V38 checks for extras beyond the 15 names).
- TWINS: searched `stale single-write sentence` — found 0 sites in instructions (only the historical B41 row); V39 rejects any such sentence if one appears.
- TWINS: searched stale suite ranges (`V1–V9`, `V14–V17`, `14 sabotage`, `V1..V9`) — found 3 sites, all in README.md table/quickstart/layout (fixed, range-free wording + `check_sigpipe.sh` listed); V39 rejects them if they reappear.
- TWINS: searched `loose tokens V22/V26` — found 2 sites: Z0.1/Z0.2 key-entry phrase, Z0.6 429 line (fixed, V40 enforces exact phrases); V40 keeps the exact wording.
- TWINS: searched `research README warning` — found 1 site: research/README.md (fixed, V41 adds warning + UNVERIFIED table); V41 keeps the warning.
- TWINS: searched `getvar all executable with allowlist` — found 1 site shape (fixed, V42 strict filter rejects `run/execute getvar all` even with an allowlist mention); V42 keeps it forbidden.
- TWINS: searched `rollback index 0 means LK can boot old slot` — found 1 site: Z0.4 exception (fixed, V43 clarifies rollback index 0 means LK CAN boot old slot); V43 keeps the clarification.
- TWINS: searched `is-userspace string exists in LK` — found 2 sites: R3 row, SAFETY LK row (fixed, V44 states string exists); V44 keeps the fact.
- TWINS: searched `check-before-write order MEASURED` — found 3 sites: SAFETY LK row (§3.3 + MEASURED suffix), protocol, SPEC §T (was stale INFERRED, fixed); V45 keeps the citation.
- TWINS: searched `inline commands T-1.2/T2b` — found 2 sites: T-1.2 (indirect reference to the two-write block, V46 names it), T2b (six getvars inline); V46 keeps them.
- TWINS: searched `same command form T-1/T3` — found 3 sites: T-1 block line, T3 block line, SAFETY recovery path (fixed, V47 enforces the guarded `command fastboot` form everywhere); V47 keeps the form consistent.
- TWINS: searched `protect1/protect2 order` — found 2 sites carrying both names: PROTOCOL NEVER list, SAFETY rule 1 (fixed, V48 enforces measured order protect2-first); README names neither partition (vacuous leg); V48 keeps the order.
- TWINS: searched `baseline 429 modules example` — found 2 sites: Z0.6 (exact plain phrase) and the baseline-capture row (same meaning with emphasis); V49 keeps the exact phrase "429 modules (example only); your number is your baseline" in Z0.6.
- TWINS: searched `pstore reading guidance` — found 1 site: the abort-criteria line (fixed, V50 adds "next normal boot on a good kernel"); V50 keeps the guidance.
- TWINS: searched `never-touch project policy` — found 1 site: SAFETY.md rule 1 (fixed, V51 states it is project policy wider than LK tables); V51 keeps the statement.
- TWINS: searched `accept in writing specific phrase` — found 1 site: firmware-comparison line (fixed, V52 requires typing the exact phrase); V52 keeps the exact phrase.
- TWINS: searched `lacunae L1-L6 in abort criteria` — found 1 table: "If something goes wrong" (fixed, V53 keeps all six rows); V53 keeps them all.
- TWINS: searched status-checked `| grep -q` pipelines — found 33 sites in `check_protocol_invariants.sh` + 1 each in `selftest_backprop.sh`/`selftest_gates.sh` (all flaked under load via SIGPIPE=141 + pipefail; fixed, herestrings); V54 forbids any pipe into `grep -q` in `tools/*.sh`.
- TWINS: searched `PROTO:NN`/`SAFETY:NN` cross-references — found 17 PROTO + 6 SAFETY refs in the device-facing docs (1 stale: userdata fact at SAFETY:8 cited as :11; fixed); V55 keeps every ref resolving to an existing line.
- TWINS: searched bare on-device commands (`uname -r`, `getprop`, `cat /proc/modules`, `dmesg`, `ls /sys/fs/pstore` without `adb shell`) — found 2 rows: T-1.3, baseline-capture (fixed); acceptance block already used `adb shell` (3 sites, untouched); V56 keeps the prefix on all five forms.

## §V — invariants (each one testable, with the file that protects it)

Notation: `∀` for all, `!` negation / must, `⊥` failure (the check must fail).

| id | invariant | protected by |
|---|---|---|
| V1 | ∀ number N quoted in `README.md`/`docs/KMI-GATES.md` about the module corpus (files, modules, required/provided symbols, rows, copies): `! N == value produced by tools/gate_kmi_crc.sh over data/official-vmlinux.symvers and by tools/data/*.tsv`, else `⊥`. Numbers that only came from the unpublished device dump are listed as out of scope. | `tools/check_docs_numbers.sh` |
| V2 | ∀ `grep -E`/`-iE` pattern P a reader is told to run in `docs/DEVICE-TEST-PROTOCOL.md`: `! (∃ line in the matching *_bad fixture matching P) ∧ (∄ line in the matching *_clean fixture matching P) ∧ ∄ `\|` inside P`; ∀ planted error class in `dmesg_bad.txt`: `∃ P` that matches it; else `⊥`. Same `\|`-in-`-E` rule over `tools/**.sh` and `scripts/**.sh`. | `tools/check_regex_controls.sh` |
| V3 | ∀ instruction in the protocol that can reach a slot change: `!` the doc forbids slot switching ∧ requires `avbtool info_image` on `vbmeta_a` **and** `vbmeta_b`; ∄ un-negated `fastboot set_active`; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V4 | ∀ sentence mentioning `fastboot boot`: `!` it is never asserted as supported (no `fastboot boot is supported/works/…`), and `∃` the UNKNOWN caveat plus the STOP on `unknown command`; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V5 | ∀ absence claim A (`does not contain`, `is not in`, `has no public recovery`, `no wipe flag`, `no entry in`, `is UNKNOWN`, `never verified/observed/present`) in `docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md`: `!` A cites ≥ 2 independent sources (paths/fact numbers/measurements) on its own line; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V6 | ∀ `rm -rf` in `tools/**.sh`/`scripts/**.sh`: `!` the target is a variable assigned from `mktemp -d` in the same file and removed through a `trap`; ∄ literal path operand; else `⊥`. | `tools/check_destructive_ops.sh` |
| V7 | ∀ claim about kernel behaviour (keywords: `same_magic`, `MODULE_SIG_PROTECT`, `sig_ok`, `protected export`, `MODVERSIONS`, `partition_wiped`, `first_stage_mount`) in `README.md`/`docs/KMI-GATES.md`/`docs/SAFETY.md`: `!` the line cites a source file (`.c`/`.h`/`.cpp`) or the `CONFIG_` symbol; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V8 | ∀ fact row in `docs/PLAN-AND-FINDINGS.pt-BR.md`: `!` its `Prova` column is non-empty; ∧ `docs/research/README.md` carries the "contain errors" warning and the UNVERIFIED link table; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V9 | ∀ file F requested from the artifact viewer by `tools/fetch_official_artifacts.sh`: `--dry-run F` prints exactly `https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest/<viewer path of F>` and writes nothing; else `⊥`. | `tools/selftest_fetch.sh` |
| V10–V13 | *Aliases.* The FIX6 round spent ids B10–B13 on four doc/tooling defects (missing runnable dmesg command, single-source absence claims, BRE `\|` in `verify_modsig.sh`, unsourced protected-exports claim); the invariants that protect them are V2, V5, V2 and V7 respectively. V10–V13 are reported as aliases of those in `tools/run_all_checks.sh` so the id space stays contiguous. | `tools/run_all_checks.sh` (alias rows) |
| V14 | ∀ claim C about **this** device's bootloader in `README.md`/`docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md`: `!` C cites the real-`lk_b.img` evidence (exact string quoted in the `docs/SAFETY.md` LK table, or the RE1 disassembly report) **or** C is explicitly labelled `INFERRED (other device)`/`UNKNOWN`; `∄` claim presented as fact with neither; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V15 | ∀ alternative boot path P (`fastboot boot`, legacy v2 RAM-boot, …) mentioned in `docs/DEVICE-TEST-PROTOCOL.md`: `!` P is not an executable step of the protocol, and the doc states why the legacy RAM-boot was discarded (slot-selection risk); `∃` evidence of slot selection for any path that *is* offered; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V16 | ∀ `getvar` check in `docs/DEVICE-TEST-PROTOCOL.md`: `!` the doc declares the accepted values **including `Variable not found`** for variables the real LK may not implement, and the pre-flight write gate exists (`partition-size:boot_b` = `0x4000000` AND file = 67108864 B AND sha256 recorded); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V17 | ∀ order/behaviour claim about this bootloader's write path: `!` it cites the RE1 disassembly of the real binary (`research/RE1_opencode_flash.md`); claims sourced only from another device's LK stay labelled `INFERRED (other device)`; a strings-only order claim or the word PROVED is `⊥`. | `tools/check_protocol_invariants.sh` |
| V18 | ∀ write step in `docs/DEVICE-TEST-PROTOCOL.md`: `!` the first write is an identical-content rehearsal (T-1: hash-verified backup reflashed onto its own partition) gated on Z0 PASS and the owner's explicit yes, and no stale "single write" sentence contradicts it; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V19 | ∀ fallback-behaviour row of the `docs/SAFETY.md` bootloader table: `!` it cites the disassembly reports (`research/RE2_codex_bootmode.md`, `research/RE4_codex_fallback.md`) with the function/address evidence, and anything still unproven stays labelled UNVERIFIED; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V20 | ∀ sentence about `is-userspace` in `README.md`/`docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md`/`docs/PLAN-AND-FINDINGS.pt-BR.md`/`docs/KMI-GATES.md`/`docs/BUILD.md`: `!` it never presents the variable as absent from the real binary (the string measurably exists); an absence claim there is `⊥`. Raw notes under `docs/research/` stay out of scope (V8 warning covers them). | `tools/check_protocol_invariants.sh` |
| V21 | ∀ `getvar` named in the Z0 section of `docs/DEVICE-TEST-PROTOCOL.md`: `!` it is one of the closed allowlist (product, current-slot, slot-count, is-userspace, unlocked, max-download-size, partition-size:boot_b, slot-successful/unbootable/retry-count:a/b, battery-soc-ok, battery-voltage), and the section forbids `getvar all` and any `oem`; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V22 | ∀ Z0 entry path in `docs/DEVICE-TEST-PROTOCOL.md`: `!` the PASS criterion is powered-off key entry and `adb reboot bootloader` is marked optional/documentary (Z0.0); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V23 | ∀ slot-mismatch branch in the Z0 section: `!` `current-slot` other than `b` means power off by keys, never `fastboot reboot`; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V24 | ∀ Z0 preconditions: `!` the charger is required disconnected; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V25 | ∀ no-adb-back procedure in the Z0 section: `!` it waits 3 min, retries by keys once, ends the day on second failure, with no USB improvisation; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V26 | ∀ module-count criterion in the Z0 section: `!` the day baseline superset is the criterion and the `429 modules` figure carries "example only; your number is your baseline"; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V27 | ∀ Z0 section: `!` it carries the honest list of what Z0 does not prove (still UNVERIFIED items); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V28 | ∀ file in `tools/*.sh`: `!` it is executable (mode 100755 in the git index and on disk); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V29 | ∀ name in `data/lk_tables.tsv` (7 controlled + 7 erase-forbidden): `!` `docs/SAFETY.md` names it in the measured tables **on the correct table row** (controlled @0x4c4bf8b0 or erase-forbidden @0x4c4bf8cc), and no extra names appear in those rows; the seven names `lk`, `seccfg`, `expdb`, `misc`, `boot_para`, `vbmeta`, `vendor_boot` are each explicitly stated NOT to be in either table; else `⊥`. **Bidirectional: SAFETY table rows must match TSV exactly (no extra, no missing).** | `tools/check_protocol_invariants.sh` |
| V30 | ∀ line mentioning `getvar all` in `README.md`/`docs/*.md` (research notes excluded): `!` the line forbids it (contains `forbid`/`PROIBIDO`/`never run`/`not run`/`allowlist`/`instead`) **and** the line does not order it (`run`/`execute` + `getvar all` is executable even with an allowlist mention); an executable `getvar all` instruction is `⊥`. | `tools/check_protocol_invariants.sh` |
| V31 | ∀ `fastboot flash` command **line** (line starts with the command; table-cell mentions are references, not commands) in `docs/DEVICE-TEST-PROTOCOL.md`: `!` there are exactly as many as `README.md` affirms (two protected writes: T-1 backup, T3 kernel) and every one targets `boot_b`; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V32 | ∀ T-1 section in `docs/DEVICE-TEST-PROTOCOL.md`: `!` it comes after the R3 section (it depends on R3); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V33 | ∀ file in `docs/research/*.md` except `README.md` (which documents the redaction): `!` it contains `/tmp/` or `/home/` paths; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V34 | ∀ never-touch rule (rule 1 of SAFETY.md) and protocol NEVER list: `!` both contain {preloader, lk, seccfg, nvram, nvdata, nvcfg, persist, proinfo, protect1, protect2, misc, boot_para, expdb}; preloader covers preloader_*, boot0/1 covered by preloader; else `⊥`. | `tools/check_protocol_invariants.sh` |
|---|---|---|
| V35 | The Z0 section header states that mandatory Z0 (Z0.1–Z0.3) writes nothing; Z0.0 (optional) writes only the Android boot reason. | `tools/check_protocol_invariants.sh` |
| V36 | `docs/SAFETY.md` states there are two protected writes: T-1 backup and T3 kernel. | `tools/check_protocol_invariants.sh` |
| V37 | ∀ `grep -E`/`-iE` pattern P a reader is told to run in `README.md`/`docs/SAFETY.md`/`docs/BUILD.md`/`docs/KMI-GATES.md`/`docs/DEVICE-TEST-PROTOCOL.md`: `!` P has positive+negative controls; `∄ \|` in P; else `⊥`. | `tools/check_regex_controls.sh` |
| V38 | The Z0 section's allowlist is **closed**: `∀` line in Z0.3 matching `getvar ...`: the name is one of the 15; `∄` other `getvar` in Z0.3; `∄` `oem` in Z0.3; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V39 | The protocol contains no stale sentence claiming a single write (e.g., "one protected write", "single write", "one and only write"); the README affirms two protected writes (T-1 backup, T3 kernel) and carries no stale suite ranges ("V1–V9", "V14–V17", "14 sabotage", "V1..V9"). | `tools/check_protocol_invariants.sh` |
| V40 | V22 requires the exact phrase "key-reached fastboot" + `Vol− + Power` in Z0.1/Z0.2; V26 requires the line with `429` to also contain "reference" or "reference only" with the meaning that baseline is criterion. | `tools/check_protocol_invariants.sh` |
| V41 | `docs/research/README.md` carries the "contain errors" warning **and** the UNVERIFIED link table. | `tools/check_protocol_invariants.sh` |
| V42 | ∀ line mentioning `getvar all` in `README.md`/`docs/*.md` (research excluded): the line **forbids** it (contains `forbid`/`PROIBIDO`/`never`/`not run`/`allowlist`/`instead`); an executable `getvar all` is `⊥`. | `tools/check_protocol_invariants.sh` |
| V43 | Z0.4 exception states that rollback index 0 means the LK **can** boot old slot A (RE4 D3), so power off by keys is required. | `tools/check_protocol_invariants.sh` |
| V44 | `is-userspace` text states the string **exists** in the LK getvar table; `no` or `Variable not found` accepted; `yes` = STOP. | `tools/check_protocol_invariants.sh` |
| V45 | Protocol cites RE1 disassembly for check-before-write order (check `bl 0x4c4367d2` precedes write `bl 0x4c436834`). | `tools/check_protocol_invariants.sh` |
| V46 | T-1.2 contains the exact command `command fastboot flash boot_b <path/to/backup/boot_b.img>`; T2b lists the six exact `getvar` commands inline. | `tools/check_protocol_invariants.sh` |
| V47 | The shell guard blocks `fastboot flash lk ...` but allows exactly the two permitted commands (`command fastboot flash boot_b <backup>` and `command fastboot flash boot_b boot_b_new.img`); the SAFETY recovery path uses the same guarded `command` form. | `tools/check_protocol_invariants.sh` |
| V48 | `protect2` appears before `protect1` in all device-facing docs (measured table order). | `tools/check_protocol_invariants.sh` |
| V49 | Baseline modules text says "429 modules (example only); your number is your baseline". | `tools/check_protocol_invariants.sh` |
| V50 | Protocol states when/how to read `pstore`: after a crash, on the **next normal boot** on a good kernel. | `tools/check_protocol_invariants.sh` |
| V51 | SAFETY.md "Never touch" list explicitly states it is project policy, wider than the bootloader's measured tables. | `tools/check_protocol_invariants.sh` |
| V52 | Slot firmware comparison "accept in writing" = type `I accept that slot A is older firmware OS3.0.20.0 and fallback would boot old OS over new data` in the terminal. | `tools/check_protocol_invariants.sh` |
| V53 | Abort criteria table includes entries for L1–L6 lacunae. | `tools/check_protocol_invariants.sh` |
| V54 | ∀ status-checked pipeline P in `tools/*.sh`: `!` P feeds `grep -q` (SIGPIPE race under `set -o pipefail`: `grep -q` exits early, the writer dies with 141, the chain flakes); use a herestring or a file argument; else `⊥`. | `tools/check_sigpipe.sh` |
| V55 | ∀ `PROTO:NN`/`SAFETY:NN` cross-reference R in `docs/DEVICE-TEST-PROTOCOL.md`/`docs/SAFETY.md`: `!` line NN exists in the cited file; else `⊥`. (Existence only; topical relatedness stays human review.) | `tools/check_protocol_invariants.sh` |
| V56 | ∀ on-device observation command C in `docs/DEVICE-TEST-PROTOCOL.md` (T-1.3 `uname`/`getprop`, baseline `cat /proc/modules`, `dmesg`, `ls /sys/fs/pstore`): `!` C carries the `adb shell` prefix (bare forms would read the host); else `⊥`. | `tools/check_protocol_invariants.sh` |

Notes on the honest limits of these checks (each also printed as `NOTE manual-review` by the
script that cannot automate it):

- V1 does not assert the device-dump-only counts (342 ramdisk files, 215 `vendor_dlkm` files, 17 names in both, vermagic group sizes 193/170/7, 101|68 kCFI counts, 429 baseline modules) because the dump is not published — re-measuring them requires the device.
- V5/V7 are line-scoped greps: they enforce that a source is *present*, not that it says what the sentence claims (that stays a human review; the sources named are the ones the reviewer must open).
- V5 deliberately covers empirical absence claims only: a sentence about the docs' own tables ("nothing in T0/T2 writes flash") is checked by reading the table, not by counting citations.
- V2's `\|`-in-`-E` rule covers `docs/DEVICE-TEST-PROTOCOL.md`, `tools/**.sh` and `scripts/**.sh`. Patterns written inside `docs/research/*` are out of scope on purpose: those files are raw agent output, are not instructions, and carry the "contain errors" warning that V8 asserts (the TWINS line above lists every site).
- V6 ignores comment lines and anything that is not a shell command position, so the sabotage fixture string in `tools/selftest_backprop.sh` is data, not an executed command; a `rm -rf` added anywhere it would actually run is still a FAIL.
- V8 cannot judge whether an individual `FACT` sentence in the raw notes is true; it forces every distilled fact into the proof column of the log and flags the raw notes as unreliable.
- V3/V4 cannot prove the LK's actual behaviour; they make it impossible to *state* the unproven behaviour as fact in these docs.

## §T — tasks still open (nothing below is proven; do not treat any as done)

- **Boot on a real `lake` device** — no image from this project has been booted on hardware.
- **`fastboot boot` support on this bootloader** — UNKNOWN; if absent, the whole RAM-test path disappears and the protocol STOPS.
- **Automatic A/B fallback on this device** — disassembly of the real `lk_b.img` shows the mechanism (same-boot `_a`→`_b` fallback with direct branches; both-invalid lands in a non-returning `fastboot_init`; retry read is a 3-bit field, decrement/initial value unproven: `docs/research/RE4_codex_fallback.md` D1–D2); on-device behaviour still UNVERIFIED.
- **Wi-Fi / Bluetooth / modem / camera with the new kernel** — untested; the certificate reasoning is host-side only.
- **Acceptance of an unsigned repacked `boot` by the chained-partition verifier** — analogous to the measured `init_boot_b` tolerance, but unproven.
- **30-minute thermal/GPU stress with the new kernel** — not run.
- **Reading `pstore` after a panic caused by *this* kernel** — the observability path is measured on stock, not validated for the new build.
- **`fastboot getvar is-userspace` runtime value on this LK** — the string exists in `lk_b.img`, but the value it returns (or `Variable not found`) was never read on the device; the protocol tolerates both non-fastbootd answers.
- **The exact order of the LK's size/allowlist checks before a write** — MEASURED by disassembly of the real `lk_b.img` (`research/RE1_opencode_flash.md` §3.3); what stays unproven is the *runtime* behaviour on-device, so the protocol never relies on it (the pre-flight oversize check is yours).
- **Denylist completeness** — `lk`, `misc`, `boot_para` do not appear explicitly in the protected-name lists inside the binary; whether a `flash`/`erase` on them would be refused is unknown and must stay untested.
- **The Z0 rehearsal itself** — mandatory before any write, still unlogged: reaching fastboot by keys with a *healthy* device is proven only by the general key-combo lore, and with a *bad* `boot_b` it is UNVERIFIED until Z0 runs. (Disassembly bounds the risk: key detection runs before any boot-partition read, `docs/research/RE2_codex_bootmode.md` B1; it does not replace the rehearsal.)

## Critério de convergência (adversarial review)

The adversarial review of this project ends only after **two consecutive rounds with no new,
concrete finding**. Any new finding — from any reviewer — goes into §B as a new row with its
root cause in one sentence, and gets an invariant in §V plus a test and a sabotage case in
`tools/selftest_backprop.sh` before the round closes. A round that produces "looks fine" without a
command, a measurement or a citation does not count as a round. The same rule applies to the
device-facing protocol: a mitigation that cannot be reduced to a checkable condition is recorded in
§T as unproven rather than described as done.
