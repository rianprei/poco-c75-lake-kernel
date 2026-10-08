# AUDIT-CODEX — maintainer audit of poco-c75-lake-kernel

> Maintainer: codex (sole editor this round). Method: AUDIT → FIX → TEST →
> RE-AUDIT → DOCUMENT → COMMIT. No device touched; no adb/fastboot executed;
> no private dumps downloaded; no push. Every structural fix gains a negative
> test/sabotage. Claims without proof become UNKNOWN/UNVERIFIED.

## 1. BASELINE (item 1)

- HEAD: `9ccf2ef6ef3f942021b5a6a797afd1d8c4565969` — "FIX13 (opencode): kilo audit findings"
- `git status --short`: empty at start. No destructive reset.
- `git log --oneline -12`: 9ccf2ef, bcea695, aea25a1, a92fed4 (FIX12), 3d82a2d,
  3ab04bd, 2111f69 (FIX11/11b), 5746802 (FIX10), b55408d (FIX9), c8bb481 (FIX8),
  d321bbe, f8df432.
- `tools/*.sh`: 12 files, all `100755` in index and on disk.
- `./tools/run_all_checks.sh` → PASS (57 checks). `./tools/selftest_backprop.sh` →
  69/69 FAIL→PASS. Observed, not inferred.

## 2. ITEM MATRIX — file → claim → command → evidence → test → risk → state

Legend: FIX = fix this round (+§B/§V/test/sabotage). HAVE = already true, verified.
REFUTADO = mission claim is false in current code (command+output cited), no change.
DEFER = true but out of scope for this round (recorded in BUGS REMAINING).

### 2A doc contradictions
| # | Verdict | Evidence |
|---|---------|----------|
| 1 | HAVE | `docs/SAFETY.md:10` already says "two protected writes" (FIX12). |
| 2 | FIX | `CONTRIBUTING.md:3` says steps "(T0/T2/T3)"; protocol has Z0/R3/T-1/T2b/T3, no T0/T2. |
| 3 | FIX | `docs/BUILD.md:74` cites protocol "step T0" (nonexistent) + `:72` plain-fact NONE/rollback (see 63). |
| 4 | FIX | `CHANGELOG.md` ends at 0.1.2 (B1–B13 era); B14–B60 undocumented. New entry with real content. |
| 5 | FIX | Controlled vocabulary absent: 0 hits for host-verified/rebuild-reproducible/hardware-unverified/boot-unproven in README/KMI-GATES/SAFETY. Apply + enforce lightly. |
| 6 | FIX | `README.md:22`: "All device-specific code lives in closed vendor modules" overclaims (DT/DTBO, firmware, boot metadata, userspace live elsewhere). |
| 7 | FIX | `README.md:3` title "Reproducible, gate-verified build" too strong (end-to-end corpus reproduction not publicly demonstrated). Soften honestly. |

### 2B protocol Z0/T3 (ex-FIX14 items 8, 11, 12, 13 inside)
| # | Verdict | Evidence |
|---|---------|----------|
| 8 | FIX | `DEVICE-TEST-PROTOCOL.md:51`: `slot-retry-count:b` above `0` is a hard PASS gate; legit 0 after successful mark → false STOP. Gate = successful:b + unbootable:b; retry only recorded. Apply in Z0.4, pre-flight, T2b + twins. |
| 9 | FIX | No per-variable getvar policy (required/optional/accepted-absent). Add policy table; absence must cause neither false safety nor false STOP. |
| 10 | FIX | "charger disconnected" as hard gate without device-specific evidence → advisory + rationale (off-mode-charge risk), not a gate. |
| 11 | FIX | getvar captures lack `2>&1` (fastboot writes to stderr): Z0.5, pre-T-1 readouts, T2b, acceptance. Wrap `{ ...; } 2>&1`. |
| 12 | FIX | `fastboot()` shell denylist is weak (`command`, absolute path, fresh shell bypass). New `tools/fastboot_guard.sh`: exact allowlist (devices, getvar×15, reboot) + write wrapper (`flash boot_b <file>` only if sha256 ∈ {backup hash, T3 hash} file, size == 67108864, first 8 bytes == ANDROID!). Protocol uses only the wrapper; `command fastboot` instructions removed. `tools/selftest_fastboot_guard.sh` with fake fastboot in PATH; wired into run_all_checks; sabotage case. |
| 13 | FIX | No READONLY/WRITE split. Write wrapper from 12 enforces it (read-only commands vs single write form). |
| 14 | FIX | Pre-flight/T-1 verify size/file/hash but not slot A/B state; T-1.3 checks version/uname only (no slot-state, boot-metadata, boot_b-hash, build, release change detection). Extend T-1.3 + pre-flight. |
| 15 | FIX | Same as 14 (T-1.3 change detection). |
| 16 | HAVE | No RAM-boot-error→T3-logic association (only conditional future-revision sentence at protocol L11). |
| 17 | FIX | Generic "(RAM boots leave flash untouched...)" at protocol L173 + L189. Remove generic claim; keep the concrete capture+stop instruction. |

### 3 false pass
| # | Verdict | Evidence |
|---|---------|----------|
| 18 | FIX | `run_all_checks.sh`: crashed check without FAIL lines → RC=0 PASS (fail-open); no explicit-PASS requirement; no output-shape validation. Fix: `rc==0` required per run + FAIL-absent + PASS-present. |
| 19 | FIX | GATE checks `SELFTEST PASS` string only, ignores exit code. Fix: string AND `rc==0`. |
| 20 | FIX | V8: rows + non-empty proof col, but no existence/size floor. Add: facts file exists, ≥10 data rows. |
| 21 | FIX (doc-clarify) | V5 enforces two DISTINCT source tokens (via `set()`), not semantic independence. Keep mechanics; SPEC honest-limits already say so — strengthen wording, do not claim more. |
| 22 | FIX (doc-clarify) | V7 keyword-triggered, no claim_id/source/rationale triple. Add claim anchors: each behaviour claim gets an explicit id the check can cite (lightweight: keep keyword gate, require the rationale token on the line). |
| 23 | FIX | V31 counts `^command` lines, does not parse fenced blocks. Upgrade to fenced-block parse (only count inside ```bash fences + table command cells excluded by rule). |
| 24 | FIX (verify) | V21 matches fenced `^  \`fastboot getvar` lines in Z0.3 vs 15-name allowlist — largely what item 24 asks; harden to extract from the actual Z0.3 fence and diff exact multiset. |
| 25 | FIX (guard) | V2 single-line QUOTED only. Add out-of-scope guard: multiline/unquoted/variable-held grep → FAIL "rewrite single-line-quoted" instead of silently missing. |
| 26 | FIX | V6 covers `rm` only. Extend to `dd of=`, `truncate`, `mkfs.*`, `fastboot flash/erase/format`, `set_active`, writes to `/dev/block`, multiline + argument-splitting. |
| 27 | FIX | V33 covers `/tmp/`+`/home/` only. Extend to `~`, `$HOME`, `/var/tmp`, `/Users`, bare usernames in paths, serial/IMEI patterns, tokens/private keys (careful: no secret *values* in repo — pattern-shape only). |

### 4 build.sh
| # | Verdict | Evidence |
|---|---------|----------|
| 28 | FIX | `cmd_cert` patches the same checkout (`scripts/build.sh:38-43`); control-after-cert contaminated. Fix: independent worktrees/copies per mode (or pristine-check + abort). |
| 29 | FIX | No idempotence: re-running cert double-applies patches; no state checks. Fix: per-mode state assertions. |
| 30 | FIX | No pre-mode `git status`/SHA/patch-state gates (only 2 SHAs in sync). Add. |
| 31 | FIX | Only common + build/kernel SHAs validated of 36 manifest projects. Validate ALL `<project>` (path, revision, HEAD); one fail ⇒ FAIL. |
| 32 | FIX | `common` pinned by TAG `refs/tags/android15-6.6-2025-06_r12` (`manifests/pinned.xml:22`): tag metadata mutable. Document + mitigate (record resolved SHA at sync time; warn). |
| 33 | FIX | `${REPO_NO_VERIFY:+--no-repo-verify}`: any non-empty value (even `0`) disables verification, silently. Strict boolean (`1`/`true`/`yes` only) + explicit WARNING. |
| 34 | FIX | No disk check; README says 80 GB. Single canonical requirement + preflight `df` check. |
| 35 | FIX | Missing record: manifest SHA, per-project SHAs, compiler, Kleaf, config, tool versions (SOURCE_DATE_EPOCH present). Add `build-record` mode writing a provenance file. |

### 5 fetch
| # | Verdict | Evidence |
|---|---------|----------|
| 36 | FIX | `FILES=("$@")` flows into `-o "$OUT/$f"` unvalidated (`tools/fetch_official_artifacts.sh:18,83`): `../x` escapes, absolute paths write anywhere. Reject `/`, `..`, absolutes. |
| 37 | FIX | Direct `-o` (no mktemp→validate→mv). Atomicize. |
| 38 | FIX | Failed curl leaves partial file as candidate (no --remove-on-error). Fix. |
| 39 | FIX (states) | verify_hash prints OK/"não verificado"/mismatch but no formal DOWNLOADED/HASH-VERIFIED/UNVERIFIED separation in summary. Add per-file state column. |
| 40 | FIX | No magic/type/minimum-size validation. Add (gzip/ELF/`ANDROID!` per filename class + min sizes). |
| 41 | FIX | `selftest_fetch.sh` is structural (URL construction only). Rename semantics honestly (`--network-smoke` separate opt-in) or extend with local fixture test. Decision: keep offline structural + separate network smoke, documented. |

### 6 KMI
| # | Verdict | Evidence |
|---|---------|----------|
| 42 | FIX | Gate compares name+CRC only; no EXPORT_SYMBOL vs _GPL / namespace identity. Add export_type+namespace to gate (data has no such columns → extend TSV or companion file from r12 lists). |
| 43 | FIX (doc) | Document KMI-list coverage; BTF/stgdiff/ABI-XML unavailable offline → declared, not gated. |
| 44 | FIX | Only __kcfi_typeid_ COUNTS (101/68). Compare stock-vs-new VALUES, not counts. |
| 45 | FIX | 1829 non-vmlinux imports declared "unaffected" informally (`KMI-GATES.md:57`). Formalize: per-symbol single-compatible-provider check, or explicit out-of-scope statement with rationale. |
| 46 | FIX (doc, 1 line) | `modules_required_crcs.tsv` missing "derivado, não regenerável sem os módulos originais" note. |
| 47 | FIX | `dump_modcrcs.py`: invalid ELF → silent `[]`; truncated → `struct.error` traceback; no strict/permissive flag. Strict by default (FAIL with clean message), `--permissive` opt-in. |
| 48 | FIX | No unit tests. Add `tests/test_dump_modcrcs.py` + `tests/test_repack_boot.py` (item 76): truncated ELF, out-of-range section, truncated __versions, module without __versions, slot-prefix collision, same basename divergent CRC. |

### 7 verify_modsig.sh
| # | Verdict | Evidence |
|---|---------|----------|
| 49 | FIX | Method B prints serial/issuer but never compares. Extract signer fingerprint/SPKI from PKCS#7 and compare with the validating Image cert; mismatch ⇒ FAIL. |
| 50 | FIX | No recorded expected-cert fingerprint. Record Googleikey fingerprint (from the published cert file in repo) in docs + check. |
| 51 | FIX | `assert i > 0` → AssertionError traceback on unsigned module. Clean error + exit code (ties into 54). |
| 52 | FIX | Selftest has 2 cases; build the 6-matrix (signer ok/errado, conteúdo/assinatura modificados, cert ausente, mesmo issuer chave diferente). |
| 53 | FIX (doc) | Document "prova criptográfica offline cert↔assinatura", explicitly not runtime-keyring behaviour. |

### 8 repack_boot_v2.py (PRIORITY)
| # | Verdict | Evidence |
|---|---------|----------|
| 54 | FIX | `err(msg, code=1)` ignores code: `sys.exit(f"ERRO: {msg}")` (`repack_boot_v2.py:39-40`). Stderr + `sys.exit(code)`. |
| 55 | FIX (restrict) | keep-footer preserves old footer with new kernel content (same-size gate exists, no content-hash revalidation). Add descriptor-vs-content match gate; document restriction (NOT removal — size+byte gates already exist). |
| 56 | FIX | `info_image` post-build non-fatal (prints only on success). Fatal. |
| 57 | FIX | Kernel roundtrip try/except AVISO. Hard gate. |
| 58/59 | FIX | `fb_img_size` (original_image_size) parsed L125, never validated; vbmeta offset/size bounds-checked L132 but not cross-checked (offset+size vs footer_off, img_size vs header kernel+pages). Validate structure relations. |
| 60 | FIX | Only gzip magic checked. Validate decompressed arm64 Image (`0x644d5241` "ARM\x64" @ 0x38) via `new_image` (currently computed L152, unused — ties into 61). |
| 61 | FIX | `new_image` unused. Use in validation (60 + size relations). |
| 62 | FIX | Outputs follow from 56+57+58/59: size == partition_size, footer at end, valid VBMeta, info_image success, exact roundtrip. Encode as fatal post-conditions. |
| 63 | FIX (doc) | `--algorithm NONE` + rollback 0 stated as plain facts (`BUILD.md:72-74`). Reframe as project choices with rationale. |
| 64 | FIX (doc) | No glossary distinguishing GKI boot signature / AVB footer / VBMeta / verified boot / module signing. Add. |
| 65 | FIX (doc) | No VTS note on `--drop-signature`. Add. |

### 9 config table
| # | Verdict | Evidence |
|---|---------|----------|
| 66 | FIX | `CONFIG_CPU_FREQ_GOV_SCHEDUTIL` row claims `hispeed_freq` tunable — not a schedutil knob (schedutil: `rate_limit_us`; `hispeed_freq` is foreign). Pinned tree offline → correct conservatively (drop the knob claim) + rule: only knobs verified in target tree. |
| 67 | FIX | Absolute language present ("SEGURO", "sem risco de boot"). Replace with LOW-RISK/NEEDS-GATES/REJECTED-BY-CURRENT-CONTRACT/UNVERIFIED-RUNTIME as applicable. |
| 68 | FIX | No G-gate chain per change (G-CONFIG/G-SYMVERS/G-CRC/G-EXPORT-TYPE/G-CFI/repack/boot/stability). Add gate-result columns (UNVERIFIED default). |
| 69 | FIX | No tree validation of CONFIG_* against pinned tree. Add validation step (offline tree when present; else mark NEEDS-TREE-CHECK, never assume). |
| 70 | FIX | 28 rows, 12 unique URLs (2 third-party: github OWLXS, gitlab susfs4ksu = weak evidence). Sampled googlesource Kconfig resolves; add URL-liveness audit (network-smoke, not default gate). |

### 10 research
| # | Verdict | Evidence |
|---|---------|----------|
| 71 | FIX | No `docs/research/raw/` separation. Create raw/ + move AI-output notes, keep normative notes at top level. |
| 72 | FIX | No `docs/FACTS.md` canonical log (FACT/PROOF/SOURCE/DATE/SCOPE/CONFIDENCE). Create with seed facts. |
| 73 | FIX | No REJECTED section for refuted claims. Add (in FACTS.md). |
| 74 | FIX | Truncated/placeholder URLs → BROKEN/UNVERIFIED triage. Audit research links. |
| 75 | FIX | `backup-2026-10-05/...` cited as reproducible source (`docs/SAFETY.md:8`, `PLAN-AND-FINDINGS`). Replace with `<PRIVATE_DEVICE_DUMP>` + SHA/provenance. |

### 11 tests/CI
| # | Verdict | Evidence |
|---|---------|----------|
| 76 | FIX | No Python unit tests. Add `tests/test_dump_modcrcs.py`, `tests/test_repack_boot.py` (matrix from 48). |
| 77 | FIX (process) | `bash -n` every `.sh` before each commit (this round: clean). |
| 78 | FIX (conditional) | `shellcheck` binary absent. CI runs it; locally: skip with note when unavailable (never fake a pass). |
| 79 | FIX | No `.github/workflows/`. Add CI: syntax, unit tests, gates, backprop sabotage, exec bit, secret/path scan. |
| 80 | FIX | CI must not download 12 GB by default; full build = manual job. Encode in workflow. |
| 81 | FIX (process) | Invariant per new bug (this round: V57+ per fix). |
| 82 | FIX | Sabotages for: run_all exit-code masking, keep-footer, info_image failure, fact file absent, control/cert mutable checkout, export-type mismatch, CFI mismatch, path traversal, destructive-command variants. Wire into selftest_backprop. |

### 12 pass tiers
- FOUND-TIER-1 = host/source/KMI/build proven; FOUND-TIER-0 = real boot + critical functions + stability. Never FOUND-PERFECT before lake boot. Encode in README/CI summary (no new gate needed beyond honest labels).

## 3. REFUTADOS (mission claims false in current code — with command+output)
- 2A(1): SAFETY already states two protected writes (`grep -c "two protected writes" docs/SAFETY.md` → 1). No change.
- 16: no RAM-boot-error→T3 association (`grep -n "RAM-boot" docs/DEVICE-TEST-PROTOCOL.md` shows only the discard section + conditional future sentence). No change.

## 4. RESULTS (filled as the round progresses)
- TEST MATRIX / BUGS FIXED / BUGS REMAINING / UNKNOWN / COMMAND OUTPUTS / FILES CHANGED / FINAL STATUS → §5 on completion.
