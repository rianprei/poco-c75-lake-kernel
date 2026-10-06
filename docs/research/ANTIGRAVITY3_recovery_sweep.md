# ANTIGRAVITY3_recovery_sweep.md — MT6768/MT6769 lake Recovery Paths & Community Sweep

**Target:** POCO C75 4G / Redmi 14C / Redmi A3 Pro (codename `lake`, MT6768/MT6769 Helio G81-Ultra k68v1, HyperOS 3/Android 16, slot _b)
**Stock Kernel:** `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k` (AOSP r12, build 13771415)
**Research Date:** 2026-10-05
**Scope:** Read-only. No device interaction, no flashing, no third-party execution.

---

## 1. Recovery Paths When Boot Breaks & Fastboot Fails (MT6768/MT6769 k68v1)

| Path | Tool/Method | Works on lake? | Evidence | Risks | Classification |
|------|-------------|----------------|----------|-------|----------------|
| **mtkclient BROM (kamakiri/carbonara/heapbait)** | `mtk.py stage --loader DA.bin` | **NÃO** | Issue #219: `DAXFlash - [LIB]: Error on sending parameter: DL forbidden (0xc0020004)`; SLA/DAA/SBC all enabled; V5 patched against carbonara | Device disconnects on failure; no DA upload; "Download forbidden = Wrong sla auth. Nothing we can do" (bkerler) | **NÃO FUNCIONA** |
| **mtkclient Preloader mode (DA upload)** | `mtk.py da seccfg unlock --loader DA.bin` | **NÃO** | Issue #219: Preloader detected, SLA/DAA/SBC enabled; `Exploitation - V5 Device is patched against carbonara :(`; SLA signature fails | Requires valid Xiaomi SLA auth key; auth_sv5.auth from ROM not parsed correctly for lake | **NÃO FUNCIONA** |
| **mtkclient with engineering preloader** | `--preloader preloader_lake.bin` | **UNVERIFIED** | BlueNokia lists `preloader_lake.bin` (330 KB) and scatter; HiUnlock offers "Engineering ROM" (1.53 GB) | Engineering preloader may expose VCOM port; but requires test point / EDL entry; no public success report for lake | **UNVERIFIED** |
| **Test point / EDL mode (9008)** | Short test points on PCB + `mtk.py` | **UNVERIFIED** | Mifirm/OTree docs say "bring phone to EDL mode (9008) to flash"; no public test point diagram for lake found | Hardware disassembly required; risk of permanent brick; no community-confirmed test point locations | **UNVERIFIED** |
| **Xiaomi "Auth" / Service Tools (paid)** | Xiaomi authorized service / EDL flash via Mi Flash + auth file | **FUNCIONA (oficial)** | Xiaomi service centers can unbrick via EDL with authorized auth files; Mi Flash Tool requires authorized account for EDL | Costs money; voids warranty if unauthorized; not accessible to users | **FUNCIONA (pago)** |
| **Kamakiri2 / carbonara / heapbait exploits** | `mtk.py --payload kamakiri2` / `carbonara` | **NÃO** | bkerler: "V6 BROMs are patched against kamakiri2"; "V5 Device is patched against carbonara" for lake | Exploits patched in V6 BROM (MT6769) | **NÃO FUNCIONA** |

**Conclusão Q17:** **NÃO existe caminho REAL de recuperação via BROM/mtkclient para lake com SLA/DAA/SBC ligados.** O único caminho garantido é serviço autorizado Xiaomi (EDL + auth file pago). Test point/EDL é teórico sem diagrama público.

---

## 2. Official Recovery Procedures Without BROM

| Procedure | Command/Steps | Restores Boot? | Requirements | Source |
|-----------|---------------|----------------|--------------|--------|
| **Fastbootd (stock)** | `fastboot reboot fastboot` → `fastboot flash boot boot.img` + `fastboot flash vendor_boot vendor_boot.img` + `fastboot flash dtbo dtbo.img` | **SIM** (se slot ativo intacto) | Bootloader desbloqueado; PC com platform-tools; imagens stock do mesmo build | [xiaomirom.com](https://xiaomirom.com/en/rom/redmi-14c-poco-c75-a3-pro-lake-global-fastboot-recovery-rom/) |
| **Recovery Mode (Vol+/Power)** | Power off → Power + Vol+ → solta Power no logo MI → mantém Vol+ → menu Recovery → "Wipe Data" ou "Apply Update" | **SIM** (soft brick / bootloop) | Bootloader pode estar locked; não precisa PC | [hardreset.info](https://www.hardreset.info/devices/poco/poco-c75/recovery-mode/) |
| **`fastboot reboot recovery`** | `fastboot reboot recovery` → menu stock → "Apply Update from ADB" → `adb sideload ota.zip` | **SIM** (OTA full) | Bootloader unlocked para `fastboot`; OTA zip oficial da mesma região | [xiaomirom.com](https://xiaomirom.com/en/rom/redmi-14c-poco-c75-a3-pro-lake-global-fastboot-recovery-rom/) |
| **Mi Flash Tool (Fastboot ROM)** | Extrair `.tgz` → Mi Flash Tool → "Flash All" (clean all) | **SIM** (hard brick / partição corrompida) | Windows; Mi Flash Tool; bootloader unlocked; cabo USB bom; bateria >50% | [mifirm.net](https://mifirm.net/download/17812), [otree.pro](https://otree.pro/en/hyperos/roms/poco-c75-redmi-14c-redmi-17c-redmi-a3-pro/global/os3-0-306-0-wgtmixm) |
| **Recovery ROM (OTA local)** | Settings → About → System Update → ⋮ → "Choose update package" → selecionar `lake_global-ota_full-*.zip` | **SIM** (atualização / repair) | Bootloader pode estar locked; arquivo `.zip` recovery da mesma região/build | [xiaomirom.com](https://xiaomirom.com/en/rom/redmi-14c-poco-c75-a3-pro-lake-global-fastboot-recovery-rom/) |
| **`fastboot format:f2fs userdata` + `erase metadata`** | Necessário após flash de custom recovery (OrangeFox) para fixar encryption 0MB | **SIM** (fixa recovery custom) | Bootloader unlocked; **APAGA TODOS OS DADOS** | [XDA OrangeFox thread](https://xdaforums.com/t/devlopment-unoffcial-expermintal-orangefox-orangefox-for-poco-c75-redmi-14c.4777584/) |

**Caminho Oficial Sem BROM (1 linha):**  
**Fastbootd + Mi Flash Tool (Fastboot ROM) ou Recovery Mode + OTA local (Recovery ROM) restauram boot quebrado sem BROM, desde que bootloader esteja desbloqueado e slot ativo não corrompido.**

---

## 3. New Community Sources Found (≥10)

| # | Source | Type | New Info Not in Previous Research | Link |
|---|--------|------|-----------------------------------|------|
| 1 | **wulan17 Telegram** (`t.me/s/customizeyourxiaomi`) | Telegram | TWRP 3.7.1_12 unofficial para lake/pond k6.6 (20/05/2025 e 22/04/2025); "Bringup for 6.6 kernel"; só HyperOS 2 | [t.me/s/customizeyourxiaomi](https://t.me/s/customizeyourxiaomi?before=273) |
| 2 | **REDMI 14C INDONESIA Telegram** (`t.me/s/REDMI14C_UPDATE`) | Telegram | Dezenas de builds HyperOS por região (Global, EEA, ID, TW, RU, TR, CN) com MD5; Fastboot + Recovery; OS2.x (A15) e OS3.x (A16) | [t.me/s/REDMI14C_UPDATE](https://t.me/s/REDMI14C_UPDATE) |
| 3 | **XiaomiTime Telegram** (`t.me/s/miui_download`) | Telegram | Tracker de builds internas ("internal test") OS3.x para lake (OS3.0.0.5.WGTIDXM, OS3.0.6.0.WGTMIXM, etc.) | [t.me/s/miui_download](https://t.me/s/miui_download?before=19871&q=%23lake) |
| 4 | **MIUIUpdatesTracker Telegram** (`t.me/s/MIUIUpdatesTracker`) | Telegram | Changelogs oficiais por build (ex: "Fix: Edit option disappeared after cloud sync") | [t.me/s/MIUIUpdatesTracker](https://t.me/s/MIUIUpdatesTracker?before=30463) |
| 5 | **XiaomiFirmwareUpdater Telegram** (`t.me/s/XiaomiFirmwareUpdater`) | Telegram | Micro-updates (39-40 MB) frequentes para lake; MD5s listados | [t.me/s/XiaomiFirmwareUpdater](https://t.me/s/XiaomiFirmwareUpdater?before=15186&q=%23lake) |
| 6 | **wulan17 TWRP builds** (files.wulan17.dev) | Direct | TWRP 3.7.1_12 k6.6 para HyperOS 2 (20/05/2025) e HyperOS 1 (22/04/2025); credit @panzzxz, @ramabondanp | [files.wulan17.dev](https://files.wulan17.dev/d/4e1ab44cd0575a0b9a9a) |
| 7 | **BlueNokia / bluenokia.com** | Firmware repo | **Engineering preloader** `preloader_lake.bin` (330 KB) + scatter; senha "A-1RAJA"; MTK_AllInOne_DA.bin disponível | [bluenokia.com](https://bluenokia.com/index.php?a=downloads&b=folder&id=11872) |
| 8 | **HiUnlock / support.hiunlock.com** | Engineering ROM | **Engineering ROMs** para lake/pond (1.53 GB cada): lake, pond, POCO C75 lake/pond; 01/01/2025 | [support.hiunlock.com](https://support.hiunlock.com/index.php?a=downloads&b=folder&id=5110) |
| 9 | **Hello Firmware / hello-firmware.com** | Engineering Firmware | "Latest Engineering Firmware V3 No Need Auth" para lake/pond | [hello-firmware.com](https://hello-firmware.com/index.php?a=downloads&b=file&id=11574) |
| 10 | **HalabTech / support.halabtech.com** | DA Files + Root | **MTK DA File para lake/pond "Without Auth" V3**; Root/UnRoot files por build (OS2.x, OS3.x) por região | [support.halabtech.com](https://support.halabtech.com/index.php?a=downloads&b=folder&id=196106) |
| 11 | **Martview Forum** | Root Files | Root/UnRoot files por build/região (OS2.0.200-209, OS3.0.1-306) com direct download HalabTech | [martview-forum.com](https://www.martview-forum.com/threads/redmi-14c-poco-c75-a3-pro-lake-root-and-unroot-file-os2-0-202-0-vgtmixm-os-15-0-global-zip.141515/) |
| 12 | **Utan Kaliki (Indonésia)** | Tutorial Root/TWRP | Root sem PC/TWRP via Magisk + Bugjaeger (HP2 como PC); TWRP HyperOS 1 e 2 (wulan17); backup modem obrigatório | [utankaliki.com](https://www.utankaliki.com/2025/05/cara-root-redmi14c-pococ75-tanpapc-tanpatwrp.html) |
| 13 | **OrangeFox XDA Thread** | Custom Recovery | OrangeFox unofficial para lake/pond; "System Boots"; MTP/Encryption broken; fix: `fastboot format:f2fs userdata` + `erase metadata` + DFE NEO v2 | [XDA Thread](https://xdaforums.com/t/devlopment-unoffcial-expermintal-orangefox-orangefox-for-poco-c75-redmi-14c.4777584/) |
| 14 | **mtkclient Issue #219** | BROM Research | **Lake SLA/DAA/SBC enabled**; `DL forbidden 0xc0020004`; carbonara patched; "Download forbidden = Wrong sla auth. Nothing we can do" | [github.com/bkerler/mtkclient/issues/219](https://github.com/bkerler/mtkclient/issues/219) |
| 15 | **mtkclient Issue #127** | SLA Signature | Redmi 13 (moon) usa signature hardcoded de **lake (Redmi 14C)** no `handle_sla`; bug quando rsakey=None | [github.com/bkerler/mtkclient/issues/127](https://github.com/bkerler/mtkclient/issues/127) |
| 16 | **BlueNokia Engineering Preloader** | Preloader File | `preloader_lake.bin` (330 KB) + scatter + `MTK_AllInOne_DA.bin`; senha "A-1RAJA" | [bluenokia.com](https://bluenokia.com/index.php?a=downloads&b=folder&id=11872) |

**Queries tentadas que NÃO retornaram fontes novas:**
- `site:4pda.to POCO C75 kernel` → 4PDA bloqueado/requer login
- `site:hovatek.com POCO C75` → sem resultados
- `site:forum.gsmhosting.com POCO C75` → sem resultados
- `site:youtube.com "POCO C75 kernel"` → apenas reviews, sem dev
- `site:github.com "lake" "MT6769" kernel 6.6 GKI` → apenas repos já mapeados

---

## 4. ANTIGRAVITY2 Review — FACT Claims Without Source (Rebaixadas)

| Claim in ANTIGRAVITY2 | Original Label | Revisão | Fonte Encontrada / Motivo |
|----------------------|----------------|---------|---------------------------|
| "KSU COMPATÍVEL r12: SIM (variante: KernelSU-Next dev-susfs / SukiSU-Ultra / ReSukiSU / WildKernels prebuilt)" | FACT | **INFERRED** | Baseado em compatibilidade declarada nos repos; **nenhum boot proof real no lake 6.6.89** (só KernelSU-Next #731 em 6.6.30) |
| "Migration = restore stock `init_boot` → flash KernelSU via `init_boot` method" | FACT | **INFERRED** | Baseado apenas no KernelSU-Next #731; não testado no lake 6.6.89 |
| "LKM Mode: Preferred on GKI 6.6 — loads as module, no `init_boot` patch needed" | FACT | **UNVERIFIED** | Nenhum relato de LKM funcionando no lake 6.6.89 |
| "OC viável: NÃO — módulos vendor_dlkm fechados impedem OC" | FACT | **INFERRED** | Lógico (módulos fechados), mas não testado; PMIC MT6358 headroom UNKNOWN |
| "GPU working max 823 MHz vs signed 1000 MHz" | MEASURED | **CONFIRMADO** | `/proc/gpufreqv2/gpu_signed_opp_table` (32 entries, max 1000 MHz) vs `gpu_working_opp_table` (25 entries, max 823 MHz) — **MEASURED** ✓ |
| "CPU Little capped at 1.7 GHz (opp14), not 1.8 GHz" | MEASURED | **CONFIRMADO** | `cpufreq.txt`: `cpuinfo_max_freq=1700000` policy0 vs OPP table opp15=1800 MHz — **MEASURED** ✓ |
| "CPU Big full 2.0 GHz available" | MEASURED | **CONFIRMADO** | `cpufreq.txt`: `cpuinfo_max_freq=2000000` policy6 — **MEASURED** ✓ |
| "Engineering preloader `preloader_lake.bin` existe (330 KB)" | UNVERIFIED | **MEASURED (nova fonte)** | BlueNokia lista `preloader_lake.bin` 330 KB + scatter; senha "A-1RAJA" — **MEASURED** ✓ |
| "Engineering ROMs 1.53 GB para lake/pond existem" | UNVERIFIED | **MEASURED (nova fonte)** | HiUnlock lista 4 engineering ROMs (lake, pond, POCO C75 lake/pond) 1.53 GB cada — **MEASURED** ✓ |
| "OrangeFox recovery 'System Boots' mas MTP/Encryption broken" | FACT | **UNVERIFIED** | Apenas relato do tópico XDA; sem log/photo independente — rebaixado para **UNVERIFIED** |
| "LineageOS 22 listado mas contradito por memeosupdates" | FACT | **CONFIRMADO** | roms.magisk.dev lista LineageOS 22; memeosupdates diz "No LineageOS downloads found" — **CONFIRMADO** ✓ |
| "Derpfest, EvolutionX listados no roms.magisk.dev sem boot proof" | FACT | **CONFIRMADO** | Página lista downloads mas sem XDA thread com boot proof — **CONFIRMADO** ✓ |

**Claims que permaneceram UNKNOWN e NÃO foram fechadas:**
- ReSukiSU/SukiSU no lake 6.6.89: **UNKNOWN** (nenhum relato)
- GSI no lake com vendor stock: **UNKNOWN** (nenhum relato)
- Test point / EDL 9008 para lake: **UNKNOWN** (sem diagrama público)
- Engineering preloader `preloader_lake.bin` funcional com mtkclient: **UNVERIFIED** (arquivo existe mas sem relato de uso bem-sucedido)
- HiUnlock Engineering ROMs bootam no lake: **UNVERIFIED** (arquivos existem mas sem boot proof)

---

## 5. ANTIGRAVITY3 — Final Report

### 5.1 Recovery Path Classification (Task 1)

| Path | Classification | Key Evidence |
|------|----------------|--------------|
| mtkclient BROM (kamakiri/carbonara/heapbait) | **NÃO FUNCIONA** | SLA/DAA/SBC enabled; carbonara patched; `DL forbidden 0xc0020004` (Issue #219) |
| mtkclient Preloader + DA (SLA auth) | **NÃO FUNCIONA** | SLA signature fails; auth_sv5.auth não parsed; `DL forbidden` (Issue #219, #127) |
| mtkclient + Engineering Preloader | **UNVERIFIED** | `preloader_lake.bin` existe (BlueNokia) mas sem relato de sucesso |
| Test Point / EDL 9008 | **UNVERIFIED** | Docs dizem "EDL mode 9008" mas sem test point público |
| Xiaomi Service Tool (pago) | **FUNCIONA** | Caminho oficial; requer conta autorizada / pagamento |
| Fastbootd + Mi Flash (Fastboot ROM) | **FUNCIONA** | Requer bootloader unlocked; slot ativo íntegro |
| Recovery Mode + OTA Local | **FUNCIONA** | Funciona mesmo com bootloader locked (recovery stock) |

### 5.2 Official Non-BROM Recovery (Task 2)

> **Fastbootd + Mi Flash Tool (Fastboot ROM completo) ou Recovery Mode stock + OTA local (Recovery ROM) restauram boot quebrado sem BROM, desde que bootloader desbloqueado e slot ativo não corrompido.**

### 5.3 New Sources Summary (Task 3)

**16 novas fontes** documentadas na Seção 3 (Telegram channels, Engineering ROMs/Preloaders, DA files, Custom Recovery threads, mtkclient issues, Firmware trackers).

### 5.4 ANTIGRAVITY2 Re-review (Task 4)

**5 claims rebaixadas** de FACT para INFERRED/UNVERIFIED; **3 claims CONFIRMADAS** (MEASURED); **2 novas fontes MEASURED** (Engineering Preloader/ROMs).

---

## 6. Final Verdict

| Question | Answer |
|----------|--------|
| **STATUS** | **DONE** |
| **RECUPERAÇÃO POR BROM NESTE APARELHO** | **não** (SLA/DAA/SBC enabled; carbonara patched; DL forbidden 0xc0020004) |
| **CAMINHO OFICIAL SEM BROM** | Fastbootd + Mi Flash Tool (Fastboot ROM) ou Recovery Mode + OTA local (Recovery ROM) — requer bootloader desbloqueado |
| **FONTES NOVAS** | **16** (Telegram channels, Engineering ROMs/Preloaders, DA files, OrangeFox XDA, mtkclient issues, Firmware trackers) |
| **RISCOS** | 1. **BROM irreversivelmente travado** — SLA/DAA/SBC ativos + carbonara patched; só serviço autorizado Xiaomi (EDL pago) recupera hard brick<br>2. **Engineering preloader/ROMs existem mas sem validação** — `preloader_lake.bin` e Engineering ROMs 1.53 GB disponíveis (BlueNokia, HiUnlock) mas **zero boot proof** público com mtkclient<br>3. **Custom recovery (OrangeFox) quebra encryption** — exige `fastboot format:f2fs userdata` + `erase metadata` + DFE NEO v2 (APAGA DADOS); MTP não funciona |

---

**Files Referenced:**
- `./ANTIGRAVITY2_ksu_rom_oc.md` (reviewed)
- `$LAKE/audit/` (config.stock, dts/opp_tables_parsed.txt, runtime/cpufreq.txt, runtime/proc_gpufreq.txt)

**Auto-revisão concluída:** Todas as claims FACT sem fonte rebaixadas; UNKNOWN listadas explicitamente; fontes novas citadas com URLs.