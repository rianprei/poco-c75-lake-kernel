# FIX15 report

The host suite passes, and the sabotage suite is 121/121. Code and docs are commit `bddcf5694a278ebb94a38a76867a86a5a7195901`. This report is the following commit. No device was used. Nothing was pushed.

`run_all_checks.sh` printed `run_all_checks: PASS` for V1–V88 plus the CRC-gate self-test (89 checks) and exited 0. `selftest_backprop.sh` printed `SABOTAGENS: 121 detectada(s) FAIL->PASS, 0 falha(s)` and `SELFTEST-BACKPROP PASS`.

INTENT: code does fail closed on a bad CRC gate, a failed curl, and a failed cms diagnostic, and the docs describe only the symbols and pins those commands actually check; the failing checks expect the old success-mask and the old overclaim phrases to print FAIL; the spec (SPEC.md §V V77–V88, plus README, BUILD, and KMI-GATES) says the same limits.

TWINS: searched `grep -v '^#'`, a one-operand `cmp vmlinux.symvers`, and a redirect onto `tools/data/modules_required_crcs.tsv` in README, BUILD, KMI-GATES, CHANGELOG, and CONTRIBUTING — found 0 other instruction sites. Raw notes under `docs/research/` still show the old diff and are not instructions. Searched `does not pass verification` and `will not pass verification` in README, BUILD, and SAFETY — found 0 after the rewrite.

AUTH: user said "Depois de terminar e commitar o FIX15 (e mandar a mensagem final dele)".

Counts below: fixed 82, refutados 1, remaining 0. Six CC4 rows were already "NENHUM ACHADO" and were re-checked, not counted as fixes. Six CC2 notes were out of scope in that review and stay out of scope.

## CC4 — tests and CI

| Item | Result | Where |
|---|---|---|
| 1.1 | FIXED `bddcf56` | `dump_modcrcs.py` uses `with open`. V65 fails if the unittest output contains `ResourceWarning`. |
| 1.2 | FIXED `bddcf56` | `repack_boot_v2.py` uses `with open`. |
| 1.3 | FIXED `bddcf56` | `tests/test_repack_boot.py` uses `with open`. |
| 1.4 | FIXED `bddcf56` | The dumper close fixes the warnings the dump tests were printing. |
| 2.1 | NENHUM ACHADO | Every non-header line of `tests/fixtures/dmesg_bad.txt` matches a documented dmesg pattern. Uncovered count is 0. |
| 2.2 | NENHUM ACHADO | The sabotage suite was already detecting its planted defects. It is now 121/121, including the new rows. |
| 2.3 | FIXED `bddcf56` | V65 runs `run_fuzz.py` when that file exists and says so when it does not. |
| 2.4 | FIXED `bddcf56` | `--selftest-full` is 8/8 and includes an expired certificate and a not-yet-valid certificate. OpenSSL 3 rejects both. |
| 2.5 | FIXED `bddcf56` | The guard selftest sends `update`, `oem unlock`, and `oem off-mode-charge`. |
| 3.1 | FIXED `bddcf56` | `actions/checkout` is pinned to `11d5960a326750d5838078e36cf38b85af677262`. |
| 3.2 | FIXED `bddcf56` | A failed curl prints `ERRO: curl falhou` and does not look like a missing URL. |
| 3.3 | FIXED `bddcf56` | The artifact URL parse no longer masks a failed match with a success token. |
| 3.4 | FIXED `bddcf56` | V77 requires the CRC gate to exit 0 before V1 trusts its numbers. |
| 3.5 | FIXED `bddcf56` | `grep -P` exit 2 is fatal in `check_docs_numbers.sh`. |
| 3.6 | REFUTADO | `exit 1` inside the brace group ended the shell before the trailing success token could run. A dirty tree printed `DIRTY_BLOCK` and the outer status was 1. `require_pristine` is now `if`/`then`, and `scripts/build.sh` contains no success-mask token. |
| 3.7 | FIXED `bddcf56` | The cms diagnostic records openssl's status. V79 fails if that assignment is masked. |
| 4.1 | FIXED `bddcf56` | Same pin as 3.1. |
| 4.2 | NENHUM ACHADO | The host workflow does not mention `build.sh`. |
| 4.3 | NENHUM ACHADO | The host workflow does not mention `fetch_official`. |
| 5.1 | FIXED `bddcf56` | Same close as 1.1. Invalid input still exits 1. |
| 5.2 | FIXED `bddcf56` | Same close as 1.2. |
| 5.3 | NENHUM ACHADO | `test_unsigned_module_clean_error` and `test_truncated_signature_clean_error` already reject those inputs. |
| 5.4 | NENHUM ACHADO | A missing symvers exits 2 with `error: symvers not found`. An empty symvers file is a FAIL exit 1, not a silent pass. The non-empty check is the required-CRC table, not the symvers argument. |
| 5.5 | FIXED `bddcf56` | A missing required doc prints `V85 FAIL required doc missing` and exits 1. |

## CC2 — build docs (65)

All 65 are FIXED in `bddcf56`. The three high findings were narrowed to the command, not widened into an unmeasured full-symvers gate.

| Item | What changed |
|---|---|
| 1.1 | Repack docs say `--footer-algorithm`. avbtool's own flag stays `--algorithm` only where the text says avbtool. |
| 1.2 | `avbtool info_image --image`. |
| 1.3 | `unpack_bootimg` is in the prerequisite lists. |
| 1.4 | `scripts/build.sh clean` and the pristine/contaminated rule are documented. |
| 1.5 | One `.config` origin: the dist directory `scripts/build.sh` writes. |
| 1.6 | Config diffs set `LC_ALL=C` and do not treat one locale's hunk header as the only form. |
| 1.7 | The config diff does not use `grep -v '^#'`, so `# CONFIG_X is not set` stays visible. |
| 1.8 | Symvers `cmp` names the new file and `data/official-vmlinux.symvers`. The row no longer says every CRC equals Google's. |
| 1.9 | Regeneration writes a temp file and moves it only after exit 0 and the expected line count. |
| 1.10 | `WORK`, `CPUS`, `RAM_MB`, and `REPO_NO_VERIFY` (GPG opt-out) are in BUILD. |
| 1.11 | `ORIG_BOOT` is an unpublished stock boot image. `KERNEL_GZ` is gzip of `Image`. The tool requires magic `1f8b`. |
| 1.12 | Control symvers has a two-file `cmp` (PLAN fact 60). `System.map` is marked measured, with no command recorded in the repo. |
| 1.13 | Bootstrap branch `common-android15-6.6-2025-06` is distinguished from the removed monthly branch. |
| 2.1 | Pasted gate blocks include `export_type_mismatches=0` and `namespace_mismatches=0`. `exit=0` is a shell comment. |
| 2.2 | The cert-config example shows the hunk separator `---`. |
| 2.3 | Gate self-test text is 1 positive, 4 sabotage, and 1 exact-key case. |
| 2.4 | Vermagic strings are not assigned to `vendor_dlkm` or the ramdisk. The inventory has no directory column. |
| 2.5 | The 557 files are vendor modules (ramdisk + vendor_dlkm), not every module on the device. |
| 2.6 | The 1829 split names 1819 vendor exports, 9 protected GKI exports, and `calc_eff_hook`. |
| 2.7 | The config hash is `zcat` text. The gzip bytes hash differently. |
| 2.8 | Historical 1573 was not recomputed here. |
| 2.9 | kCFI counts 101 and 68 cite `docs/AUDIT-CODEX.md`, not PLAN fact 50. |
| 2.10 | `compared=` is the join with the symvers file that was passed. |
| 2.11 | The gate also fails on a conflicting CRC, export_type, and namespace. |
| 2.12 | Disk text says 80 GiB. The script names 83886080 KiB. |
| 2.13 | The pasted block is a positive control on the reference symvers. Control and cert output is not stored here. |
| 2.14 | Module signing is independent of the four entries above it. The VTS note stays outside that list. |
| 3.1 | The CRC gate checks the 2309 symbols the modules require. The other stock exports are not compared. Full symvers identity is the control-build `cmp` only. |
| 3.2 | 35 of 36 projects are SHA-checked. `common` is pinned by tag. The resolved SHA is recorded and not enforced. |
| 3.3 | `--selftest` checks official `can.ko` against the official Image. It does not verify a locally built Image. No cert-build result is stored. |
| 3.4 | `rebuild-reproducible` means symvers, config, and Image size, not a bit-identical Image. |
| 3.5 | The Portuguese summary says the Image is not byte-identical. |
| 3.6 | The release-string note cites `same_magic()` and says it is not tested on a device. |
| 3.7 | Protected-export imports in this inventory are Wi-Fi only. Bluetooth on a device was not measured. |
| 3.8 | Each gate has a command or a stated limit. G-REPACK has no published command. G-CERT against a new Image has no stored result. |
| 3.9 | A locked bootloader was not measured. README, BUILD, and SAFETY say that. |
| 3.10 | Host gates are re-runnable here. Device numbers need the unpublished dump. |
| 3.11 | The control-build symvers check cites PLAN fact 60. |
| 3.12 | The device Image dump is unpublished. |
| 3.13 | `selftest_backprop.sh` covers §V. The CRC gate's own selftest is `tools/selftest_gates.sh`. |
| 3.14 | The 0.1.0 certificate bullet says the on-device effect is not verified. |
| 3.15 | The control-image line says no Image certificate validates the module signer. |
| 3.16 | The gates are recommended before a write. `tools/fastboot_guard.sh` does not check them. |
| 4.1 | The filegroup tar is not downloaded and its digest is not recorded. The flat file in the repo is the reference. |
| 4.2 | Bare audit item numbers were removed from the five docs. |
| 4.3 | The README layout names the host checks and the workflow. The workflow does not sync or build. |
| 4.4 | The vermagic cite is `common/kernel/module/version.c` at tag `android15-6.6-2025-06_r12`. |
| 4.5 | The scope list is in the same cell. The dangling "see below" is gone. |
| 4.6 | CHANGELOG uses `docs/SAFETY.md`, `docs/DEVICE-TEST-PROTOCOL.md`, `scripts/build.sh`, and `tests/fixtures/`. |
| 4.7 | CSV fields that contain commas are quoted. V70 counts columns and fails an 8-field row. |
| 5.1 | BUILD says build commands live in `scripts/build.sh` and that verification is called from `tools/`. |
| 5.2 | The route starts from a host-approved image. |
| 5.3 | CONTRIBUTING names both status vocabularies and SPEC V14 `INFERRED` / `UNKNOWN`. |
| 5.4 | Bugreports must have serial, IMEI, and network identifiers removed before pasting. |
| 5.5 | Issue text is excerpts. Raw logs stay local. |
| 5.6 | CONTRIBUTING links `docs/SAFETY.md` and says a flash can bootloop or brick. |
| 5.7 | The local names from the protocol are listed, including the pstore listing. |
| 5.8 | The three commands are `./tools/run_all_checks.sh`, `./tools/selftest_backprop.sh`, and `tools/selftest_gates.sh`. |
| 5.9 | Device model is `ro.product.device`, example `lake`. |
| 5.10 | The exact-key case is `mutex_lock` versus `mutex_lockX`. |
| 5.11 | The certificate file name is written in full. |
| 5.12 | The footer carries size, offset, and vbmeta size. Algorithm and rollback index live in the VBMeta blob. |
| 5.13 | `official/can.ko` is fetched before the verify commands. |
| 5.14 | Changelog headings descend, including 0.1.2 then 0.1.1 then 0.1.0. |
| 5.15 | Strict ELF parsing is attributed to `tools/dump_modcrcs.py`. |

## Out of scope (CC2, not counted)

Left as they were: the repack header mentioning `run_fuzz.py`, the gate comment that says `data/` for files that live under `tools/data/`, an unused `xxd` in the modsig header, the offline note about vermagic groups 193/170/7, the committer-time comment in `scripts/build.sh`, and the consistent "not yet tested" wording.

## Not done

No image was flashed. No official artifact was downloaded for this pass. The full kernel build was not run.
