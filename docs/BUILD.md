# Reproducing the builds

All commands are wrapped in [`scripts/build.sh`](../scripts/build.sh). This page explains what they do and what to expect. Nothing here touches a phone.

## Prerequisites

- Linux x86-64; **~80 GB free disk** (source ≈ 12 GB with partial clone, Bazel output the rest); **12+ GB RAM** (the build needs ~6–8 GB; close browsers — an out-of-memory kill mid-build wastes hours).
- `git`, `python3`, `curl`, `openssl`, `avbtool` (from AOSP `kernel/prebuilts/build-tools` or your distro), and Google's `repo` launcher (`git clone https://gerrit.googlesource.com/git-repo`, put it on `PATH`).

## 1. Source: the exact revisions Google built

The official CI artifact `manifest_13771415.xml` pins **every** project (36) to the revision used for the kernel running on the device (`manifests/manifest_13771415.xml`). `manifests/pinned.xml` is the same file with one change: the monthly branch `android15-6.6-2025-06` no longer exists upstream, so `common` is fetched by the tag `android15-6.6-2025-06_r12` instead.

```bash
scripts/build.sh sync
```

Gates run at the end of the sync: `common` must be `5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143`, `build/kernel` `4039bcfd…`. The bundled compiler (`prebuilts/clang/.../clang-r510928`) reports *"based on r510928 … LLVM 477610d4d0d9…"*, the same banner as the stock kernel.

## 2. Control build (no changes)

```bash
scripts/build.sh control        # ≈25 min on 3 cores, ≈12 min on 6
```

This is the official target (`//common:kernel_aarch64_dist`, `--config=stamp`) with `SOURCE_DATE_EPOCH` set to the tag's commit time. Expected, and measured:

| Check | Expected |
|---|---|
| `dist_control/vmlinux.symvers` vs Google's | **byte-identical** (`cmp`) |
| `bazel-bin/common/kernel_aarch64_config/out_dir/.config` vs the device's `/proc/config.gz` | **0 differences** |
| `System.map` symbol (type, name) set | 0 differences (addresses differ) |
| `Image` | same size (36,461,056 B) but **not** byte-identical: the ephemeral signing key and the version banner change the layout |

The banner of a local build is `6.6.89-android15-8-4k` (no `-g<hash>-ab<id>` suffix). That is harmless: the module loader ignores the release string when modules carry CRCs.

## 3. Cert build (Google module-signing certificate embedded)

A rebuilt kernel signs its own modules with a fresh key. The stock GKI modules in `system_dlkm` are signed by *Google's* key; with `CONFIG_MODULE_SIG_PROTECT=y` a module the kernel cannot verify is treated as unsigned and is refused when it exports protected symbols (`rfkill_*`, `arc4_*`, Bluetooth). The fix is to also trust Google's **public** certificate, which is embedded in Google's own image (`certs/…pem`).

```bash
scripts/build.sh cert
```

This applies two patches (the Kleaf wrapper `define_common_kernels` does not forward the `system_trusted_key` attribute that `kernel_build` already supports; `common/BUILD.bazel` then sets it) and copies the certificate into `common/`. Measured result: the config differs from stock by **one line** — `CONFIG_SYSTEM_TRUSTED_KEYS="google_gki_ab13771415_modsign_cert.pem"` — and the image embeds **two** certificates.

## 4. Verify before anything else

```bash
tools/gate_kmi_crc.sh   $HOME/lake-build/out/dist_cert/vmlinux.symvers      # → PASS
tools/verify_modsig.sh  $HOME/lake-build/out/dist_cert/Image official/can.ko # → PASS (Google-signed module)
tools/verify_modsig.sh  $HOME/lake-build/out/dist_control/Image official/can.ko # → FAIL (no cert: proves the need)
```

See [`KMI-GATES.md`](KMI-GATES.md).

## 5. Repack into a boot image (host only)

`tools/repack_boot_v2.py ORIG_BOOT KERNEL_GZ OUT --drop-signature` replaces only the kernel of a stock boot v4 image, validates the gzip by real decompression, refuses to overwrite files or to exceed the partition, and regenerates the AVB footer with `avbtool` (`--algorithm NONE`, rollback 0). It refuses by default to drop Google's 16 KiB *GKI boot signature* block — pass `--drop-signature` to confirm (it covers the old kernel and cannot be re-signed).

**Do not flash the result without reading [`SAFETY.md`](SAFETY.md).**
