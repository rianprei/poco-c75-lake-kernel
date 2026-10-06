# Research notes (raw)

These files are the **unedited output of several AI research agents** plus review passes, kept for traceability — with one documented exception: machine paths (`/tmp/<agent>-work`, `~/Documentos/mods/...`, agent scratch dirs) were replaced by `<workdir>` / `<lake-kernel>` / `<tabs-agent-os>` so the notes can be published; nothing else was rewritten. **They contain errors.** The verified facts are in [`../PLAN-AND-FINDINGS.pt-BR.md`](../PLAN-AND-FINDINGS.pt-BR.md); when a note and that log disagree, the log is right.

Claims from these notes that were later **refuted by measurement**:

| Claim | Reality |
|---|---|
| A rebuilt kernel's `-ab<buildid>` suffix / timestamp must match, otherwise "Invalid module format" | The loader ignores the release token when modules carry CRCs (`same_magic()`) |
| `pstore/ramoops` is unavailable (no DT node) | It is active: parameters on the kernel command line; the bootloader injects the reserved region |
| Stock kernel is a vendor-patched build | It is byte-identical to Google's public GKI build |
| The device has a usable "inactive test slot" | The other slot holds older firmware (OS3.0.20.0) |
| `download.lineageos.org/devices/lake` is a boot-image source | That `lake` is a Motorola G7 Plus |
| `dew` (Redmi 15C / POCO C85) is this device | Different device; Xiaomi's `dew-v-oss` source branch is a sibling, not `lake` |
| The Google CI artifacts require a login | Public, via the signed URL embedded in the artifact viewer page |
| Google-signed modules would load "tainted" with a rebuilt kernel | Under `MODULE_SIG_PROTECT` they load unsigned and fail on protected exports (hence the cert) |
| `formattable` on `/data` means a failed mount formats the partition | Refuted against AOSP: a formattable partition that fails to mount is logged and ignored (`system/core/init/first_stage_mount.cpp`), and the legacy format path only runs when the partition is *already* wiped **or** the encryption was interrupted (`system/core/fs_mgr/fs_mgr.cpp`, the `wiped = partition_wiped(...)` branch around lines 1632-1634) — see [`../SAFETY.md`](../SAFETY.md) |

## Where the raw device dumps are

The raw dumps of the audited device (`audit/`, `backup-*`, `official-ab13771415/`) were **retained and not published**: they contain device identifiers and partition images. What is published is the distilled evidence — hashes, sizes, symbol/CRC tables and command output — in [`../PLAN-AND-FINDINGS.pt-BR.md`](../PLAN-AND-FINDINGS.pt-BR.md) (facts 1-67), [`../KMI-GATES.md`](../KMI-GATES.md), `data/` and `tools/data/`.

## External links that are NOT verified (UNVERIFIED)

Checked with `curl` (browser User-Agent, `-L`, 2026-10-06) — these answered **403** (bot-blocking or removed; cannot tell without a browser) or did not resolve:

| Link | Status |
|---|---|
| `https://forum.xda-developers.com/t/physwizz-collection.4253081/` (OPENCODE3) | 403 — UNVERIFIED |
| `https://xdaforums.com/t/devlopment-unoffcial-expermintal-orangefox-orangefox-for-poco-c75-redmi-14c.4777584/` (ANTIGRAVITY3 §13) | 403 — UNVERIFIED |
| `https://xdaforums.com/t/galaxy-a14-sm-a145-and-sm-a146-custom-kernels-and-twrps.4558515` (OPENCODE3) | 403 — UNVERIFIED |
| `https://support.hiunlock.com/…id=5110` (ANTIGRAVITY3 §8) | 403 — UNVERIFIED |
| `https://support.halabtech.com/…id=196106` (ANTIGRAVITY3 §10) | 403 — UNVERIFIED |
| `https://www.hardreset.info/devices/poco/poco-c75/recovery-mode/` (ANTIGRAVITY3, key combos) | 403 — UNVERIFIED |
| `https://files.wulan17.dev/d/4e1ab44cd0575a0b9a9a` (ANTIGRAVITY3 §6) | no response (DNS/connection) — UNVERIFIED/likely dead |
| `https://api.github.com/.../compare/…` (CODEX4 §FACT) | truncated placeholder in the note — **broken** (404) |
| `https://api.github.com/repos/MiCode/Xiaomi_Kernel_OpenSource/commits/e91fa14..` (CODEX4 §FACT) | truncated SHA — **broken** (422) |

Everything else cited in these notes (GitHub, `android.googlesource.com`, `source.android.com`, `t.me`) answered 200 on the same run.

## Index of the reports kept here

- `CANDIDATES.md`, `AUDIT_codex.md`, `AUDIT_antigravity.md` — device/repo reconnaissance and independent audits.
- `OPENCODE2_*`, `OPENCODE3_*`, `OPENCODE4_*`, `CODEX2_*`-`CODEX6_*`, `ANTIGRAVITY*` — boot-safety, recovery-firmware, KMI/CRC, config/ABI, signing and repack reviews.
- `REVIEW3_codex_fmea.md` — 28-scenario FMEA of the bring-up sequence, including the `/data` loss analysis behind [`../SAFETY.md`](../SAFETY.md) and the mitigations now required by [`../DEVICE-TEST-PROTOCOL.md`](../DEVICE-TEST-PROTOCOL.md).
