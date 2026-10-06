# Lake Kernel Candidates — POCO C75 4G / Redmi 14C (lake, MT6768/MT6769)

**Generated:** 2026-10-05  
**Purpose:** Technical research only — read-only public forge reconnaissance  
**Scope:** GitHub, GitLab, Codeberg, SourceForge, XDA, Reddit, Telegram, Wayback  
**Target:** POCO C75 4G (codename `lake`, model 2410FPCC5G, MT6768/MT6769 Helio G85/G81 Ultra, kernel stock GKI 6.6.89-android15-8, HyperOS 3 / Android 16)

---

## 1. Executive Summary

**No official Xiaomi kernel source for lake has been released.** The only lake-specific public artifacts are:
- DTS files extracted from HyperOS 2 firmware (`mt6768-mainline/downstream-kernel-blobs`)
- TWRP device trees (`lpxx50117/twrp_device_xiaomi_lake`, `Mayuri-Chan/recovery_device_xiaomi_pond`)
- Official ROMs confirming kernel version `6.6.89-android15`

All public MT6768 kernel sources are either:
- 4.14/4.19 vendor kernels for other Xiaomi devices (lancelot, merlin, fire, earth)
- 6.6 mainline/Samsung kernels without lake DTS
- Mirrors/placeholders without boot evidence

**Conclusion:** Building a perfect flashable kernel for lake requires either:
1. Official kernel source from Xiaomi (not available)
2. Reverse-engineering the stock kernel and reconstructing defconfig/DTB from firmware

---

## 2. Candidate Scoring Matrix

### 2.1 Scoring Criteria (0–5)

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Identity lake exata | HIGH | Contém DTS do lake? |
| Versão 6.6.89/KMI compatível | HIGH | Versão do kernel alinhada com stock? |
| Fonte completa e compilável | HIGH | Código fonte completo, sem blobs suspeitos? |
| Evidência de boot real no lake | CRITICAL | Log/foto/issue de boot real? |
| Manutenção ativa | MEDIUM | Último commit recente? |
| Ausência de blobs suspeitos | MEDIUM | Binários pré-compilados suspeitos? |

### 2.2 Candidate Table

| # | Repo | URL | Score | Fact Label | Last Commit | Branch | Kernel Ver | GKI/Vendor | Lake DTS | Boot Proof | License | Notes |
|---|------|-----|-------|------------|-------------|--------|------------|------------|----------|------------|---------|-------|
| 1 | mt6768-mainline/downstream-kernel-blobs | https://github.com/mt6768-mainline/downstream-kernel-blobs | **2/5** | FACT: DTS lake exists; INFERRED: kernel 6.6.30 for lake | 2025-10-17 | main | 5.10.209 (HyperOS 1), 6.6.30 (HyperOS 2) | Vendor | YES | FACT: DTS extracted from real HyperOS firmware | UNKNOWN | Only DTS files, not full kernel source. HyperOS 2 uses 6.6.30. HyperOS 3 uses 6.6.89 (confirmed by official ROMs). |
| 2 | mt6768-mainline/linux | https://github.com/mt6768-mainline/linux | **3/5** | FACT: boots on MT6768 (lancelot); INFERRED: architecture compatible with lake | 2026-02-11 | 6.18, master | 6.18 | Vendor | NO (lancelot only) | FACT: Debian 13 on lancelot (MT6769T) | GPL-2.0 | Mainline Linux 6.18 with MT6768 DTS. Boots on lancelot (MT6769T) with display, touch, GPU. NOT lake. NOT 6.6.89. |
| 3 | mt6768-mainline/android_kernel_samsung_mt6768 | https://github.com/mt6768-mainline/android_kernel_samsung_mt6768 | **2/5** | FACT: Samsung MT6768 6.6 kernel exists; INFERRED: architecture compatible | 2025-10-17 | main | 6.6 | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Samsung A05s / Helio G85 kernel. NOT Xiaomi. No lake DTS. No boot proof for lake. |
| 4 | lpxx50117/twrp_device_xiaomi_lake | https://github.com/lpxx50117/twrp_device_xiaomi_lake | **1/5** | FACT: TWRP device tree for lake exists; INFERRED: DTB extractable | 2025-02-27 | alpha_20250227 | UNKNOWN | Vendor | YES (device tree) | FACT: TWRP boots on real lake hardware | UNKNOWN | TWRP device tree, NOT kernel source. DTB may be extractable. Based on HyperOS 1.0.1.0.UGTMIXM. |
| 5 | Mayuri-Chan/recovery_device_xiaomi_pond | https://github.com/Mayuri-Chan/recovery_device_xiaomi_pond | **1/5** | FACT: recovery device tree for lake/pond exists | 2025-05-19 | twrp-12.1 | UNKNOWN | Vendor | YES | FACT: recovery boots on lake hardware | UNKNOWN | TWRP recovery tree for pond/lake. Init android15-6.6. DTB may be extractable. |
| 6 | Xmatography/recovery_device_xiaomi_lake | https://github.com/Xmatography/recovery_device_xiaomi_lake | **1/5** | FACT: recovery device tree for lake exists | 2026-02-08 | UNKNOWN | UNKNOWN | Vendor | YES | UNKNOWN | UNKNOWN | Fork of Mayuri-Chan/recovery_device_xiaomi_pond. |
| 7 | Baratynsky/recovery_device_xiaomi_moon | https://github.com/Baratynsky/recovery_device_xiaomi_moon | **1/5** | FACT: recovery device tree for pond/lake exists | 2025-06-02 | UNKNOWN | UNKNOWN | Vendor | YES | UNKNOWN | UNKNOWN | TWRP device tree for pond/lake. |
| 8 | mt6768-dev/android_kernel_xiaomi_mt6768 | https://github.com/mt6768-dev/android_kernel_xiaomi_mt6768 | **1/5** | INFERRED: MT6768 kernel source exists; MEASURED: lineage-23.2 branch | UNKNOWN | lineage-23.2 | 4.19 (INFERRED) | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | LineageOS kernel for MT6768 devices. Default branch lineage-23.2. Likely 4.19.x. No lake DTS. No 6.6. |
| 9 | mt6768-dev/android_kernel_xiaomi_earth | https://github.com/mt6768-dev/android_kernel_xiaomi_earth | **1/5** | FACT: earth (Redmi 12C) kernel source exists | UNKNOWN | lineage-23.2 | 4.19 (INFERRED) | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Redmi 12C / Poco C55 kernel. Same SoC family. No lake DTS. |
| 10 | mt6768-dev/android_kernel_xiaomi_fire | https://github.com/mt6768-dev/android_kernel_xiaomi_fire | **1/5** | FACT: fire (Redmi 12) kernel source exists | UNKNOWN | lineage-23.2 | 4.19 (INFERRED) | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Redmi 12 kernel. Same SoC family. No lake DTS. |
| 11 | mubashardev/android_kernel_xiaomi_earth_lineageos | https://github.com/mubashardev/android_kernel_xiaomi_earth_lineageos | **1/5** | FACT: earth kernel with multi-variant builds exists | UNKNOWN | UNKNOWN | 4.19 | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Earth kernel with KSU-Next, SukiSU, SUSFS builds. No lake DTS. |
| 12 | oppo-source/android_kernel_oppo_mt6769 | https://github.com/oppo-source/android_kernel_oppo_mt6769 | **1/5** | FACT: OPPO MT6769 kernel exists | 2023-09-06 | oppo/mt6769_t_13.1.1_a58 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | OPPO A38 kernel for MT6769. NOT Xiaomi. No lake DTS. |
| 13 | Samsung-MT6769-Devs/android_kernel_samsung_mt6768 | https://github.com/Samsung-MT6769-Devs/android_kernel_samsung_mt6768 | **1/5** | FACT: Samsung MT6768 kernel exists | UNKNOWN | lineage-19.1 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Samsung A14 / A14 5G kernel for MT6768. NOT Xiaomi. No lake DTS. |
| 14 | mt6768-S/android_kernel_xiaomi_mt6768 | https://github.com/mt6768-S/android_kernel_xiaomi_mt6768 | **1/5** | INFERRED: fork of mt6768-dev/android_kernel_xiaomi_mt6768 | 2026-06-28 | lineage-23.2 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Fork of mt6768-dev. Same limitations as parent. |
| 15 | LineageOS/android_kernel_xiaomi_mt6768 | https://github.com/LineageOS/android_kernel_xiaomi_mt6768 | **1/5** | FACT: LineageOS MT6768 kernel exists | UNKNOWN | lineage-20 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | LineageOS kernel for MT6768. Likely 4.19.x. No lake DTS. |
| 16 | Redmi-MT6768/android_kernel_xiaomi_mt6768 | https://github.com/Redmi-MT6768/android_kernel_xiaomi_mt6768 | **1/5** | FACT: community MT6768 kernel exists | 2020-12-28 | twelve | UNKNOWN | Vendor | YES (mt6768.dts) | UNKNOWN | UNKNOWN | Old community kernel. Likely 4.14.x. No lake DTS. |
| 17 | ZyCromerZ/android_kernel_xiaomi_mt6768 | https://github.com/ZyCromerZ/android_kernel_xiaomi_mt6768 | **1/5** | FACT: custom MT6768 kernel exists | 2021-02-15 | changelogs | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Custom kernel with overclock claims (Neutrino-LZ GPU 1.018MHz). No lake DTS. |
| 18 | ViP3R-KERNELs/kernel_xiaomi_mt6768 | https://github.com/ViP3R-KERNELs/kernel_xiaomi_mt6768 | **1/5** | FACT: custom MT6768 kernel exists | 2023-04-02 | lineage-20.0 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Custom kernel for MT6768 devices. No lake DTS. |
| 19 | Jbub5/kernel_action_mt6768 | https://github.com/Jbub5/kernel_action_mt6768 | **1/5** | FACT: MT6768 kernel with CI exists | 2024-12-22 | kernel-tree | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | MT6768 kernel with GitHub Actions CI. No lake DTS. |
| 20 | hataketsu/mt6768-mainline-notes | https://github.com/hataketsu/mt6768-mainline-notes | **3/5** | FACT: mainline 6.18 boots on MT6769T (lancelot) | 2026-08-04 | master | 6.18 | Vendor | YES (lancelot) | FACT: display, touch, GPU, USB work | MIT (scripts), GPL-2.0 (drivers) | Documentation + patches for mainline on MT6768. NOT lake. |
| 21 | hataketsu/redmi9-lancelot-mainline | https://github.com/hataketsu/redmi9-lancelot-mainline | **3/5** | FACT: mainline 6.18 with patches for MT6769T | UNKNOWN | main | 6.18 | Vendor | YES (lancelot) | FACT: WiFi, battery, display, touch | MIT/GPL-2.0 | Companion repo to mt6768-mainline-notes. NOT lake. |
| 22 | OWLXS/motorola-lamu-kernel-6.6 | https://github.com/OWLXS/motorola-lamu-kernel-6.6 | **2/5** | FACT: GKI 6.6 kernel for MT6768 (Lamu) | UNKNOWN | UNKNOWN | 6.6 | GKI | UNKNOWN | FACT: boots on moto g05 (MT6768) | UNKNOWN | Motorola Lamu (MT6769/Helio G81 Extreme) GKI kernel. Same SoC family as lake. No lake DTS. |
| 23 | m52xq/motorola_lamu_dump | https://github.com/m52xq/motorola_lamu_dump | **2/5** | FACT: real Lamu firmware dump with kernel 6.6.82 | UNKNOWN | UNKNOWN | 6.6.82 | Vendor | UNKNOWN | FACT: real firmware dump | UNKNOWN | Real MT6769 firmware dump. Kernel 6.6.82. No lake DTS. |
| 24 | Mayuri-Chan/recovery_device_xiaomi_pond | https://github.com/Mayuri-Chan/recovery_device_xiaomi_pond | **1/5** | FACT: pond/lake recovery tree with android15-6.6 init | 2025-05-19 | twrp-12.1 | UNKNOWN | Vendor | YES | FACT: recovery boots on pond/lake | UNKNOWN | Init android15-6.6. DTB may be extractable. |
| 25 | twrpdtgen/android_device_xiaomi_lake | https://github.com/twrpdtgen/android_device_xiaomi_lake | **1/5** | FACT: twrpdtgen output for lake exists | UNKNOWN | UNKNOWN | UNKNOWN | Vendor | YES | UNKNOWN | UNKNOWN | Auto-generated device tree for lake. Not kernel source. |
| 26 | SavedByLight/android_device_xiaomi_lake | https://github.com/SavedByLight/android_device_xiaomi_lake | **1/5** | FACT: device tree for lake exists | 2026-01-29 | android-14.1 | UNKNOWN | Vendor | YES | FACT: "Booting" label in repo | UNKNOWN | Device tree for lake. Not kernel source. |
| 27 | jachuru/android_device_xiaomi_lake | https://github.com/jachuru/android_device_xiaomi_lake | **1/5** | FACT: device tree for lake exists | UNKNOWN | UNKNOWN | UNKNOWN | Vendor | YES | UNKNOWN | UNKNOWN | Device tree for lake. Not kernel source. |
| 28 | mt6768-dev/android_device_xiaomi_mt6768-common | https://github.com/mt6768-dev/android_device_xiaomi_mt6768-common | **1/5** | FACT: common device tree for MT6768 exists | UNKNOWN | lineage-23.2 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Common device tree. Not kernel source. |
| 29 | mt6768-dev/android_device_xiaomi_mt6768-common-legacy | https://github.com/mt6768-dev/android_device_xiaomi_mt6768-common-legacy | **1/5** | FACT: legacy common device tree for MT6768 exists | UNKNOWN | lineage-21 | UNKNOWN | Vendor | UNKNOWN | UNKNOWN | UNKNOWN | Legacy common device tree. Not kernel source. |
| 30 | MiCode/Xiaomi_Kernel_OpenSource | https://github.com/MiCode/Xiaomi_Kernel_OpenSource | **0/5** | FACT: no lake branch/tag exists | N/A | N/A | N/A | N/A | NO | N/A | GPLv2 | Official Xiaomi kernel repo. NO lake source. Issues #40309, #40912, #41071 request lake kernel. |

---

## 3. Top Candidates (Ranked)

### 3.1 #1 — mt6768-mainline/downstream-kernel-blobs (Score: 2/5)

**Why:** Only public lake DTS files. Documents lake kernel versions (5.10.209 HyperOS 1, 6.6.30 HyperOS 2).  
**Limitations:** Not full kernel source. No defconfig. No build scripts. No boot proof for custom kernel.  
**Use case:** Reference for lake DTS, DTBO, and kernel version chain.

### 3.2 #2 — mt6768-mainline/linux (Score: 3/5)

**Why:** Mainline Linux 6.18 with MT6768 DTS. Boots on lancelot (MT6769T) with full graphics stack.  
**Limitations:** NOT lake. NOT 6.6.89. NOT Xiaomi. No lake DTS.  
**Use case:** Reference for mainline MT6768 bringup. Driver patches for WiFi, battery, PMIC.

### 3.3 #3 — lpxx50117/twrp_device_xiaomi_lake (Score: 1/5)

**Why:** Only lake-specific public repo with TWRP boot evidence. DTB may be extractable.  
**Limitations:** NOT kernel source. Based on HyperOS 1.0.1.0 (kernel 5.10/6.6.30 era).  
**Use case:** DTB extraction, boot parameters, partition layout.

---

## 4. Official GKI & Toolchain References

### 4.1 AOSP Kernel/Common

| Item | Value | Source | Fact Label |
|------|-------|--------|------------|
| Commit 5a0ffb447c1d | refs/tags/android15-6.6-2025-06_r12^{} | https://android.googlesource.com/kernel/common | FACT |
| Tags containing 5a0ffb447c1d | android15-6.6-2025-06_r12^{} | git ls-remote | FACT |
| Nearby tags | android15-6.6-2025-06_r10 through r39 | git ls-remote | FACT |
| Corresponding tag for 6.6.89-android15-8 | UNKNOWN (5a0ffb447c1d is android15-6.6-2025-06_r12, NOT 6.6.89) | N/A | UNKNOWN |

**Note:** The stock kernel version `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k` does NOT correspond to any public AOSP tag. The commit `5a0ffb447c1d` is in `android15-6.6-2025-06_r12`, which is a 6.6.30-era GKI, not 6.6.89.

### 4.2 Toolchain

| Item | Value | Source | Fact Label |
|------|-------|--------|------------|
| Clang version for android15-6.6-2025-06_r12 | UNKNOWN | N/A | UNKNOWN |
| Prebuilt clang r510928 | UNKNOWN (not found in public prebuilts) | N/A | UNKNOWN |
| Clang branch for 6.6.89 | UNKNOWN | N/A | UNKNOWN |

**Note:** The specific clang prebuilt version for 6.6.89-android15-8 is not publicly documented. Android 15 GKI builds typically use clang-r510928 or similar, but exact version must be extracted from build.sh or release notes.

### 4.3 KernelSU & Forks

| Repo | URL | 6.6 Support | Lake Support | Fact Label |
|------|-----|-------------|--------------|------------|
| KernelSU | https://github.com/tiann/KernelSU | YES | NO | FACT |
| KernelSU-Next | https://github.com/KernelSU-Next/KernelSU-Next | YES | NO (Issue #731: Redmi 14C flash failed) | FACT |
| SukiSU | https://github.com/SukiSU-Ultra/SukiSU-Ultra | YES | NO | FACT |
| ReSukiSU | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| susfs4ksu | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| WildKernels GKI builder | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |

**Note:** KernelSU-Next Issue #731 shows Redmi 14C (lake) flash failed with "No compatible ramdisk found". init_boot method works.

### 4.4 Lake Blobs & DTBs

| Item | Value | Source | Fact Label |
|------|-------|--------|------------|
| Lake DTB | NOT FOUND | N/A | UNKNOWN |
| Lake DTBO | NOT FOUND | N/A | UNKNOWN |
| Lake vendor_boot | NOT FOUND | N/A | UNKNOWN |
| Lake init_boot | NOT FOUND | N/A | UNKNOWN |
| Lake defconfig | NOT FOUND | N/A | UNKNOWN |
| Lake DTS | YES — `lake_global_images_OS2.0.3.0.VGTMIXM_15.0.dts` | mt6768-mainline/downstream-kernel-blobs | FACT |

**Note:** No public lake DTB, DTBO, vendor_boot, or init_boot found. These must be extracted from stock firmware.

---

## 5. Related Devices (MT6768 Family)

| Codename | Device | SoC | Kernel Source | Version | Lake Compatible |
|----------|--------|-----|--------------|---------|-----------------|
| lancelot | Xiaomi Redmi 9 | MT6769T | YES | 4.14 | NO (different board) |
| merlin | Xiaomi Redmi Note 9 | MT6769T | YES | 4.14 | NO (different board) |
| gale | Xiaomi Redmi 13C | MT6768 | YES | 4.19 | NO (different board) |
| fire | Xiaomi Redmi 12 | MT6768 | YES | 4.19 | PARTIAL (same SoC) |
| earth | Xiaomi Redmi 12C / Poco C55 | MT6768 | YES | 4.19 | PARTIAL (same SoC) |
| selene | Xiaomi Redmi 10 Prime | MT6768 | YES | 4.19 | NO (different board) |
| dew | Xiaomi Redmi 15C / Poco C85 | UNKNOWN | NO (MiCode branch exists, closed) | UNKNOWN | NO |
| pond | Redmi A3 Pro / Poco C75 4G | MT6768 | NO | UNKNOWN | YES (same as lake) |
| warm | Redmi A4 5G / Poco C75 5G | SM4635 | YES | UNKNOWN | NO (Snapdragon) |
| lamu | Motorola moto g05/g15 | MT6769 | YES | 6.6 | PARTIAL (same SoC) |

**Note:** `pond` and `lake` are the same device (Redmi 14C / Poco C75 4G). `warm` is the 5G variant (Snapdragon).

---

## 6. Key Findings & Recommendations

### 6.1 What We Know (FACT)

1. **No official Xiaomi kernel source for lake has been released.**
2. **Lake uses kernel 6.6.89-android15** (confirmed by official HyperOS 3 ROMs).
3. **Lake DTS exists** in `mt6768-mainline/downstream-kernel-blobs` (HyperOS 2 era).
4. **TWRP exists** for lake (`lpxx50117/twrp_device_xiaomi_lake`, `Mayuri-Chan/recovery_device_xiaomi_pond`).
5. **HyperOS 2 uses 6.6.30** on lake (from DTS filename).
6. **HyperOS 1 uses 5.10.209** on lake (from mt6768-mainline README).
7. **AOSP commit 5a0ffb447c1d** is in `android15-6.6-2025-06_r12` (6.6.30-era GKI).

### 6.2 What We Don't Know (UNKNOWN)

1. **Exact stock defconfig** for lake.
2. **Lake DTB / DTBO** (must be extracted from firmware).
3. **Vendor blobs** for lake (must be extracted from firmware).
4. **Exact clang prebuilt version** for 6.6.89-android15-8.
5. **Exact AOSP tag** corresponding to 6.6.89-android15-8.

### 6.3 Recommendations

1. **Extract DTB/DTBO/vendor_boot/init_boot** from stock HyperOS 3 firmware.
2. **Reconstruct defconfig** from:
   - Stock `/proc/config.gz` (if accessible)
   - TWRP device tree kernel modules
   - mt6768-mainline DTS as reference
3. **Use AOSP android15-6.6** as GKI base (tag near android15-6.6-2025-06_r12).
4. **Port lake DTS** from `mt6768-mainline/downstream-kernel-blobs` to mainline 6.6.
5. **Test with init_boot method** (KernelSU-Next Issue #731 shows boot.img method fails).

---

## 7. Fact Labels Legend

| Label | Description |
|-------|-------------|
| FACT | Verified by direct observation (git ls-remote, web search, file listing) |
| MEASURED | Direct measurement from artifact (hash, date, version string) |
| INFERRED | Logical deduction from facts |
| UNVERIFIED | Claim from external source (README, issue) without proof |
| UNKNOWN | Not found / not verifiable |

---

## 8. Sources

- https://github.com/MiCode/Xiaomi_Kernel_OpenSource
- https://github.com/mt6768-mainline/downstream-kernel-blobs
- https://github.com/mt6768-mainline/linux
- https://github.com/mt6768-mainline/android_kernel_samsung_mt6768
- https://github.com/lpxx50117/twrp_device_xiaomi_lake
- https://github.com/Mayuri-Chan/recovery_device_xiaomi_pond
- https://github.com/Xmatography/recovery_device_xiaomi_lake
- https://github.com/Baratynsky/recovery_device_xiaomi_moon
- https://github.com/mt6768-dev/android_kernel_xiaomi_mt6768
- https://github.com/mt6768-dev/android_kernel_xiaomi_earth
- https://github.com/mt6768-dev/android_kernel_xiaomi_fire
- https://github.com/mubashardev/android_kernel_xiaomi_earth_lineageos
- https://github.com/oppo-source/android_kernel_oppo_mt6769
- https://github.com/Samsung-MT6769-Devs/android_kernel_samsung_mt6768
- https://github.com/hataketsu/mt6768-mainline-notes
- https://github.com/hataketsu/redmi9-lancelot-mainline
- https://github.com/OWLXS/motorola-lamu-kernel-6.6
- https://github.com/m52xq/motorola_lamu_dump
- https://github.com/KernelSU-Next/KernelSU-Next/issues/731
- https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/40309
- https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/40912
- https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/41071
- https://android.googlesource.com/kernel/common
- https://github.com/tiann/KernelSU
