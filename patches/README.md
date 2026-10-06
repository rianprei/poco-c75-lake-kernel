# Patches

**The applicable form is the pair `0001` + `0002`** — that is exactly what `scripts/build.sh cert` applies, with `git apply --check` first so a mismatch fails loudly (see [`../docs/BUILD.md`](../docs/BUILD.md) §3):

| File | Applies to | What it does |
|---|---|---|
| `0001-kleaf-forward-system_trusted_key.patch` | `kernel/build` (`kleaf/common_kernels.bzl`) | forwards the `system_trusted_key` attribute that `kernel_build` already supports but `define_common_kernels` does not pass through |
| `0002-common-embed-google-gki-cert.patch` | `common` (`BUILD.bazel`) | sets `system_trusted_key` to the certificate copied into `common/` |

`system_trusted_key.patch` is a **combined reference copy**: the same hunks as `0001` + `0002` concatenated into one file, kept because the review note that produced it (`docs/research/OPENCODE4_review_codex5.md`) refers to that single artifact. **Nothing applies it** — applying it *in addition to* `0001`/`0002` fails (`git apply --check` would report the hunks already applied), and applying it *instead of* them would need `git apply --include=…` per repository (the two hunks target two different checkouts). Use `0001` + `0002`; treat this file as history.

Neither patch changes exported symbols or CRCs: the measured effect of the cert build is a single config line (`CONFIG_SYSTEM_TRUSTED_KEYS=…`) and an extra certificate inside `Image` — see `docs/KMI-GATES.md` and fact 65 of `docs/PLAN-AND-FINDINGS.pt-BR.md`.

Licenses: `0001` modifies AOSP `kernel/build` (Apache-2.0); `0002` modifies the Android Common Kernel `BUILD.bazel` (GPL-2.0-only). See `../NOTICE.md`.
