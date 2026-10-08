# FACTS — canonical fact log (item 72)

One row per verified fact. Columns: FACT (claim) | PROOF (command/output/file) |
SOURCE (where it came from) | DATE | SCOPE (device/host/tree) | CONFIDENCE
(MEASURED / CROSS-CHECKED / SINGLE-SOURCE / UNVERIFIED).

Rule: docs and tools cite FACT ids, never raw research notes. A claim that is
not here (or marked otherwise below) must be treated as UNVERIFIED.

| FACT | PROOF | SOURCE | DATE | SCOPE | CONFIDENCE |
|------|-------|--------|------|-------|------------|
| F-GKI-1: device runs Google's unmodified GKI (`Image` byte-identical to CI 13771415) | `cmp` + sha256 `a023b4fd…bbaca` | device dump + ci.android.com | 2026-10-05 | device+host | MEASURED |
| F-KMI-1: 557 `.ko` = 370 distinct modules; 4138 required symbols, 2309 from vmlinux, 0 mismatches | `tools/gate_kmi_crc.sh` output | device modules + official symvers | 2026-10-06 | host | MEASURED |
| F-LK-1: controlled table = nvram,nvcfg,proinfo,nvdata,protect2,protect1,persist @0x4c4bf8b0; erase-forbidden = preloader,preloader_a,_b,_ab,_backup,boot0,boot1 @0x4c4bf8cc | RE1 disassembly §3–4 | real `lk_b.img` | 2026-10-06 | device binary | MEASURED |
| F-LK-2: check-before-write order (check `bl 0x4c4367d2` precedes write `bl 0x4c436834`) | RE1 disassembly §3.3 | real `lk_b.img` | 2026-10-06 | device binary | MEASURED |
| F-CERT-1: Google module-signing cert fingerprint `76:FB:…:A1` (sha256) | `openssl x509 -fingerprint` on `certs/google_gki_ab13771415_modsign_cert.pem` | repo cert file | 2026-10-07 | host | MEASURED |
| F-SLOT-1: slot A holds older firmware (OS3.0.20.0) over newer data | `avbtool info_image` on both vbmeta | device dump | 2026-10-05 | device | CROSS-CHECKED |

## REJECTED (item 73) — claims refuted by measurement, do not reintroduce

| Claim | Reality | Refuted by |
|-------|---------|------------|
| vermagic suffix must match | loader ignores release token with CRCs (`same_magic()`) | kernel source |
| `pstore/ramoops` unavailable | active via kernel cmdline, injected by bootloader | device measurement |
| stock kernel is vendor-patched | byte-identical to Google GKI | `cmp` + sha256 |
| usable inactive test slot | other slot holds older firmware | vbmeta compare |
| `download.lineageos.org/devices/lake` is a source | that `lake` is a Motorola G7 Plus | web check |
| `dew` is this device | sibling branch, not `lake` | source tree |
| CI artifacts need login | public signed URLs | fetch script |
| Google-signed modules load "tainted" | refused as protected exports without cert | signature experiment |
| `formattable` failed mount formats | logged and ignored; format needs already-wiped | AOSP source |
| `hispeed_freq` is a schedutil tunable | not a schedutil knob | Kconfig (pending tree re-verify) |
| T0/T2 (`fastboot boot`) is the live device route | not a step; support on this LK is UNKNOWN | `docs/DEVICE-TEST-PROTOCOL.md` rule 1 |
| a new kernel on slot A is the test slot | slot A is older firmware OS3.0.20.0 | PLAN fact 62; protocol rule 3 |
| 1572 is the live kernel-symbol count | live gate number is 2309; the historical 215-module label in KMI-GATES is 1573 and was not recomputed | `tools/gate_kmi_crc.sh`; `data/kmi_abi_union_r12.txt` has 8962 lines |
| Z0 is zero-risk or risk-free | Z0 is a read plus a reboot on the current healthy `boot_b`; recovery from a bad `boot_b` stays unshown | `docs/SAFETY.md` bad-`boot_b` row |
| a rebuilt Image must hash-equal the official unpacked Image | same size 36461056, different bytes (ephemeral key) | PLAN fact 60 |

This file is not a copy of all 67 PLAN rows. `docs/PLAN-AND-FINDINGS.pt-BR.md` stays the measurement log. Rows above are the claims the current gates and protocol rely on, plus claims that must not return.

## BROKEN / UNVERIFIED links (item 74)

Truncated placeholders (`https://api.github.com/.../compare/…`, `.../commits/e91fe14..`)
are BROKEN (404/422). Bot-blocked forum links are UNVERIFIED (403, cannot tell
without a browser). Full triage table: `docs/research/README.md` §"External links".
