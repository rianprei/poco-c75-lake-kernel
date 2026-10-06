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
| V14 | ∀ claim C about **this** device's bootloader in `README.md`/`docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md`: `!` C cites the real-`lk_b.img` evidence (exact string quoted in the `docs/SAFETY.md` LK table) **or** C is explicitly labelled `INFERRED (other device)`/`UNKNOWN`; `∄` claim presented as fact with neither; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V15 | ∀ alternative boot path P (`fastboot boot`, legacy v2 RAM-boot, …) mentioned in `docs/DEVICE-TEST-PROTOCOL.md`: `!` P is not an executable step of the protocol, and the doc states why the legacy RAM-boot was discarded (slot-selection risk); `∃` evidence of slot selection for any path that *is* offered; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V16 | ∀ `getvar` check in `docs/DEVICE-TEST-PROTOCOL.md`: `!` the doc declares the accepted values **including `Variable not found`** for variables the real LK may not implement, and the pre-flight write gate exists (`partition-size:boot_b` = `0x4000000` AND file = 67108864 B AND sha256 recorded); else `⊥`. | `tools/check_protocol_invariants.sh` |
| V17 | ∀ claim marked PROVED/MEASURED about the bootloader: `!` the evidence is of the right kind — existence claims may cite strings, but **order/behaviour claims require disassembly or an on-device experiment**; a strings-only order claim is `⊥`. Enforced structurally: the SAFETY LK table must carry the `INFERRED (other device)` row and the protocol must derive the oversize protection from its own pre-flight check, not from the bootloader's assumed check order. | `tools/check_protocol_invariants.sh` |
| V18 | ∀ write step in `docs/DEVICE-TEST-PROTOCOL.md`: `!` the first write is an identical-content rehearsal (T-1: hash-verified backup reflashed onto its own partition) gated on Z0 PASS and the owner's explicit yes, and no stale "single write" sentence contradicts it; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V19 | ∀ fallback-behaviour row of the `docs/SAFETY.md` bootloader table: `!` it cites the disassembly reports (`research/RE2_codex_bootmode.md`, `research/RE4_codex_fallback.md`) with the function/address evidence, and anything still unproven stays labelled UNVERIFIED; else `⊥`. | `tools/check_protocol_invariants.sh` |
| V20 | ∀ sentence about `is-userspace` in `README.md`/`docs/SAFETY.md`/`docs/DEVICE-TEST-PROTOCOL.md`/`docs/PLAN-AND-FINDINGS.pt-BR.md`/`docs/KMI-GATES.md`/`docs/BUILD.md`: `!` it never presents the variable as absent from the real binary (the string measurably exists); an absence claim there is `⊥`. Raw notes under `docs/research/` stay out of scope (V8 warning covers them). | `tools/check_protocol_invariants.sh` |

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
- **The exact order of the LK's size/allowlist checks before a write** — INFERRED (other device) only; proving it here requires disassembly of `lk_b.img` or a deliberate (unsafe) experiment, so the protocol never relies on it.
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
