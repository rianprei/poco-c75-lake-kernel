# Reproducing the builds

Build commands live in [`scripts/build.sh`](../scripts/build.sh). Verification and repack are invoked directly from `tools/`. Nothing here touches a phone.

## Prerequisites

- Linux x86-64; **80 GiB free disk** (the script checks `83886080` KiB; source ≈ 12 GB with partial clone, Bazel output the rest); **12+ GB RAM** (the build needs ~6–8 GB; close browsers — an out-of-memory kill mid-build wastes hours).
- `git`, `python3`, `curl`, `openssl`, `avbtool` (from AOSP `kernel/prebuilts/build-tools` or your distro), `unpack_bootimg` (AOSP mkbootimg; the host check in §5), and Google's `repo` launcher (`git clone https://gerrit.googlesource.com/git-repo`, put it on `PATH`).

## Environment and a second build

`scripts/build.sh` reads four variables. The defaults are in the script header.

| Variable | Default | Effect |
|---|---|---|
| `WORK` | `$HOME/lake-build` | Checkout (`$WORK/src`) and outputs (`$WORK/out`) |
| `CPUS` | `nproc` | `--local_cpu_resources` for Bazel |
| `RAM_MB` | `8000` | `--local_ram_resources` for Bazel |
| `REPO_NO_VERIFY` | unset | `1`, `true`, or `yes` passes `--no-repo-verify` and skips the repo launcher's GPG check. Anything else is refused. This is an explicit opt-out of a security check. |

`control` and `cert` both require a pristine tree. `cert` applies two patches and copies the certificate into `common`, which contaminates that checkout. A second `cert`, or `control` after `cert`, is refused (`patches already applied … run clean first`). Between rounds:

```bash
scripts/build.sh clean     # git checkout of build/kernel and common; removes only the copied cert if untracked
scripts/build.sh record cert   # optional: write $WORK/out/build-record-cert.txt (also run automatically after control and cert)
```

`clean` does not delete `$WORK/out`. `record <mode>` can be run on its own; `control` and `cert` already call it.

## 1. Source: the exact revisions Google built

The official CI artifact `manifest_13771415.xml` lists **36** projects at the revisions used for the kernel running on the device (`manifests/manifest_13771415.xml`). `manifests/pinned.xml` is the same file with one change: the monthly branch name `android15-6.6-2025-06` no longer exists upstream, so `common` is fetched by the tag `android15-6.6-2025-06_r12` instead.

`scripts/build.sh sync` bootstraps with `repo init -b common-android15-6.6-2025-06` (the manifest project's branch name, which still exists) and then re-inits from `pinned.xml`. The monthly branch cited above is the one that was removed; it is not the `-b` argument.

```bash
scripts/build.sh sync
```

At the end of sync, `check_all_projects` enforces the SHA revision of every project that is pinned by SHA (35 of 36, including `build/kernel` `4039bcfd…`). `common` is pinned by tag, so the script prints `pinned by TAG … resolved SHA recorded, not enforced` and continues. The resolved SHA is written to `$WORK/sync-record.txt` as `common_HEAD`. The r12 commit observed when this repo was measured was `5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143`; that string is not a failing gate. The bundled compiler (`prebuilts/clang/.../clang-r510928`) reports *"based on r510928 … LLVM 477610d4d0d9…"*, the same banner as the stock kernel.

## 2. Control build (no changes)

```bash
scripts/build.sh control        # wall time is not a gate; one logged control build was ~25 min at 3 CPUs (fact 60). No 6-core timing is recorded here.
```

This is the official target (`//common:kernel_aarch64_dist`, `--config=stamp`) with `SOURCE_DATE_EPOCH` set to the tag's commit time. Expected, and measured:

| Check | Expected |
|---|---|
| `cmp "$HOME/lake-build/out/dist_control/vmlinux.symvers" data/official-vmlinux.symvers` | **byte-identical** (PLAN fact 60) |
| `tools/gate_kmi_crc.sh $HOME/lake-build/out/dist_control/vmlinux.symvers` | `compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0` → `PASS` |
| `LC_ALL=C diff` of `$HOME/lake-build/out/dist_control/.config` (the file `scripts/build.sh control` writes via `--dist_dir`) against `data/official-kernel_aarch64.config` | **0 differences** in that text (`zcat` of the device `/proc/config.gz`, not the `.gz` bytes) |
| `System.map` (type, name) | 0 differences of names and types; addresses differ. Measured per PLAN fact 60; no comparison command is recorded in this repo |
| `Image` | same size (36,461,056 B) but **not** byte-identical: the ephemeral signing key and the version banner change the layout |

The banner of a local build is `6.6.89-android15-8-4k` (no `-g<hash>-ab<id>` suffix). By the reading of `same_magic()` (`common/kernel/module/version.c`, tag `android15-6.6-2025-06_r12`), the release token should not block a module that carries CRCs. That is not tested on a device.

## 3. Cert build (Google module-signing certificate embedded)

A rebuilt kernel signs its own modules with a fresh key. The stock GKI modules in `system_dlkm` are signed by *Google's* key; with `CONFIG_MODULE_SIG_PROTECT=y` a module the kernel cannot verify is treated as unsigned and is refused when it exports protected symbols (`rfkill_*`, `arc4_*`). In this inventory those imports are Wi-Fi only (`cfg80211.ko`, `mac80211.ko`). Bluetooth on a device was not measured. The fix is to also trust Google's **public** certificate, `certs/google_gki_ab13771415_modsign_cert.pem`, which `scripts/build.sh` copies into the tree.

```bash
scripts/build.sh cert
```

This applies two patches (the Kleaf wrapper `define_common_kernels` does not forward the `system_trusted_key` attribute that `kernel_build` already supports; `common/BUILD.bazel` then sets it) and copies the certificate into `common/`. The config diff that this page can show is the one line in [`KMI-GATES.md`](KMI-GATES.md) (`CONFIG_SYSTEM_TRUSTED_KEYS`). Fact 65 records two certificates inside the cert-build `Image` (ephemeral key plus the Google cert); that image is not in this repo, so "two certificates" stays a cited measurement, not a command you can re-run from a checkout alone.

## 4. Verify before anything else

Fetch `official/can.ko` before the verify commands below.

```bash
tools/fetch_official_artifacts.sh Image can.ko                                # official/Image and official/can.ko
tools/selftest_gates.sh                                                       # → SELFTEST PASS
tools/gate_kmi_crc.sh $HOME/lake-build/out/dist_cert/vmlinux.symvers          # → see output below
tools/verify_modsig.sh $HOME/lake-build/out/dist_cert/Image official/can.ko   # → PASS (Google-signed module, when the Image holds that cert)
tools/verify_modsig.sh $HOME/lake-build/out/dist_control/Image official/can.ko # → FAIL (no Image certificate validates the module signer)
```

Measured, for the control and the cert build alike (`data/official-vmlinux.symvers` gives the same):

```
$ tools/gate_kmi_crc.sh $HOME/lake-build/out/dist_cert/vmlinux.symvers
modules.files=557 modules.unique=370
symbols.required=4138 symbols.reference_exports=8795 symbols.reference_provides=2309
compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0
export_type_mismatches=0 namespace_mismatches=0
PASS
# the script does not print a status line; the shell's $? is 0 when the verdict is PASS
```

The fetch in the block above is sha256-checked. See [`KMI-GATES.md`](KMI-GATES.md) for the data files and their metrics.

## 5. Repack into a boot image (host only)

`ORIG_BOOT` is a stock boot v4 image. This repo does not publish that image; the protocol keeps a hash-checked backup. `KERNEL_GZ` is gzip of the built `Image` (`gzip -c Image > KERNEL_GZ`). The tool refuses input whose magic is not `1f8b`.

`tools/repack_boot_v2.py ORIG_BOOT KERNEL_GZ OUT --drop-signature` replaces only the kernel of a stock boot v4 image, validates the gzip by real decompression, refuses to overwrite files or to exceed the partition, and regenerates the AVB footer with `avbtool`. Project choices, which are also the tool defaults: `--footer-algorithm NONE` (avbtool itself is invoked with `--algorithm NONE`) and `--rollback-index 0`. The footer is therefore **unsigned** and pins no rollback protection; `--drop-signature` discards Google's 16 KiB *GKI boot signature* block (it covers the old kernel and cannot be re-signed). That combination is only acceptable on a device whose bootloader is **unlocked** (`verifiedbootstate=orange` — the state of the audited device). On a **locked** bootloader this image was not measured. Reading AVB suggests an unsigned footer would fail verification; that reading is untested. Do not flash it on that basis. Verify the produced image before it leaves the host (`avbtool info_image --image OUT`, `unpack_bootimg --boot_img OUT`), and remember that the RAM path itself (`fastboot boot`) is **UNKNOWN** on `lake` — see [`DEVICE-TEST-PROTOCOL.md`](DEVICE-TEST-PROTOCOL.md) (no RAM-boot step in the protocol).

**Do not flash the result without reading [`SAFETY.md`](SAFETY.md).**

### Signature vocabulary (five different things)

- **GKI boot signature**: 16 KiB block appended by Google covering the shipped kernel; cannot be re-signed; `--drop-signature` discards it (refused by default).
- **AVB footer** (`AVBf`, 64 bytes at image end): `avbtool add_hash_footer` output; carries `original_image_size`, `vbmeta_offset`, and `vbmeta_size`.
- **VBMeta**: the metadata blob the footer points at (hash descriptors per partition). Algorithm and rollback index live in this blob.
- **Verified boot**: the bootloader's runtime enforcement (orange = unlocked, tolerates descriptor mismatch; locked = rejects unsigned).
- **Module signing**: `CONFIG_SYSTEM_TRUSTED_KEYS` certificate checked by the kernel at `modprobe` time — independent of the four above.
- **VTS note** (not a host gate): removing the GKI boot signature block changes the image layout CTS/VTS may fingerprint; a VTS run against a repacked image is untested and could flag the missing signature — declared, not verified.
