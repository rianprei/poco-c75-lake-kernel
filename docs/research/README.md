# Research notes (raw)

These files are the **unedited output of several AI research agents** plus review passes, kept for traceability. **They contain errors.** The verified facts are in [`../PLAN-AND-FINDINGS.pt-BR.md`](../PLAN-AND-FINDINGS.pt-BR.md); when a note and that log disagree, the log is right.

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
