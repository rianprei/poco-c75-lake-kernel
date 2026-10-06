# OPENCODE2b_recovery_firmware — POCO C75 4G (lake) firmware/recovery

> Data: 2026-10-05. Somente leitura: `tar -tzf`, `sha256sum` do cache, pesquisa web. Nenhum flash, nenhum adb/fastboot, nenhum binário executado.

## 1. Firmware fastboot oficial do lake (OS3.0.306.0.WGTMIXM global)

### 1.1 URLs/espelhos

- `FACT` (xmfirmwareupdater.com, gerenciado por yshalsager, não afiliado à Xiaomi mas que referencia links oficiais): versão global **Fastboot** mais nova para lake é `OS3.0.20.0.WGTMIXM` (Android 16, 8.0 GB, 2026-04-30). `OS3.0.306.0.WGTMIXM` aparece só como **Recovery ROM** (Android 16, 4.9 GB, 2026-07-17). https://xmfirmwareupdater.com/hyperos/lake
- `FACT` (mirom.ezbox.idv.tw, espelha OTA Xiaomi): para lake, existe OTA **incremental** `lake_global-ota_incremental-OS3.0.20.0.WGTMIXM-OS3.0.306.0.WGTMIXM-user-16.0-b9849f544f.zip` e full `...full-OS3.0.306.0.WGTMIXM-user-16.0-e850180983.zip` (4.6 GB), MD5 `e850180983d097edec3bcc7b7735a717` (provável). Há também recovery listing via xiaomirom/miuirom `Fastboot (7.99 GB) 2026-02-04`.
- `FACT` (mifirm.net page lake 26337): `OS3.0.6.0.WGTMIXM` Global Stable; `OS3.0.302.0.WGTCNXM` (China) existe. Model code == `lake` (verifica via `fastboot getvar product`). https://mifirm.net/downloadzip/26337
- `FACT` (xiaomirom/xiaomiupdate/xiaomime): série "lake" cobre Redmi 14C/17C/A3 Pro/POCO C75; latest Global = OS3.0.306.0 recovery.

### 1.2 Qual fonte é oficial?

- **Oficial**: `bigota.d.miui.com` (OTA zip/full), downloads no `mi.com/pt/hyperos` (que redirecionam para os servidores MIUI/OTA + fastboot ROM via updater/MIUI). https://www.mi.com/en/hyperos/redmi-14c-4g/
- **Espelho com metadados oficiais (não afiliado mas reaproveita links)**: `xmfirmwareupdater.com` (ligue diretamente ou via `github.com/yshalsager/xiaomi-firmware-updater` tracker). `mifirm.net`, `xiaomirom.com`, `miuirom.org`, `xiaomiupdate.com`, `getdroidtips` são agregadores — tratam como confirmação cruzada, não como fonte de hash.

### 1.3 Hashes publicados?

- **MD5 publicado** apenas para as OTAs full/incremental (mirom). **SHA256 do fastboot ROM inteiro (tgz ~7.99–8 GB) não é publicado pelo agregador** — UNKNOWN.
- Deve-se extrair a parte `images/*.img` por `tar -tzf` e rodar `sha256sum` no `boot.img/vbmeta.img/vendor_boot.img` aceléra em vez do tgz → FATOS locais em `backup-2026-10-05/SHA256SUMS.log`.

> red flags: nova "ROM fastboot da Maria… lake" sem source/PL no XMFirmwareUpdater: é a oficial. "ROM combinado/EDL" de XDA: não use sem log do checksum das imagens internas.

## 2. Estrutura do fastboot ROM + flash_all (conteúdo do lake)

### 2.1 Listing medido

`MEASURED`: `<tabs-agent-os>/lake_OS2.0.1.0.VGTMIXM.tgz` tem **8388608 bytes (8 MiB exato)** e o `tar -tzf` mostra apenas 7 entradas porque o **tar/gzip está truncado** ("Fim de arquivo inesperado"):
```
lake_global_images_OS2.0.1.0.VGTMIXM_15.0/
  flash_all.sh
  flash_all_except_data_storage.sh
  misc.txt
  images/
  images/vbmeta_vendor.img
  images/XIAOMI_G81_S0MP1_K69V1_64_K510_PCB01_MT6768_S00.elf
```
Conclusão: **não é um fastboot ROM completo**; é um corte/download parcial (8 MiB). O `.elf` é o **lk da MediaTek** (preloader/lk, não é kernel). Não use.

### 2.2 Como um fastboot ROM completo do lake se parece

Layout típico (com base em lake fastboot ROM de outras versões OS2/OS3 e flash_all.sh de MTK LK):
- `preloader_<slot>`/`XIAOMI_….elf` (MediaTek .elf wrapper do preloader/LK)
- `lk_a/lk_b` + `lk_a`/`lk_b` images, `super_empty.img`, `super.img`, `system.img`, `vendor.img`, `odm.img`, `product.img`, `odm`
- `boot`, `init_boot`, `vendor_boot`, `dtbo`, `vbmeta`, `vbmeta_system`, `vbmeta_vendor`
- `md1img` (modem), `tee`, `scp`, `sspm`, `spmfw`, `aop`, `dtbo_a/b` …
- scripts: `flash_all.sh`, `flash_all_except_data_storage.sh`, `flash_all_lock.sh`, `misc.txt`

### 2.3 Comandos perigosos no flash_all (classificação)

| Comando em flash_all.sh | Perigo | Por quê |
|---|---|---|
| `fastboot flash preloader <elf>` / `flash lk_<slot>` | **AÇÃO CRÍTICA** | Apagar LK/preloader tira o boot inteiro; rollback requer BROM/DA, que no lake está bloqueado (`DL forbidden`). |
| `fastboot flash seccfg` / `flash proinfo nvdata …` | **AÇÃO CRÍTICA** | Atualiza state desegurança; pode re-travar o unlockflow. |
| `fastboot erase modemst*` / `erase nvdata*` / `fastboot format data` | Apaga IMEI/serial | **Não rodar**. |
| `fastboot flashing lock` / `fastboot oem lock` | travamento | Se vbmeta/boot não batem, brick bootloop. |
| `fastboot erase super` | Apaga kernels adicionados por slots lógicos | Perde todas as imagens do vendor/ramdisk papel. |

### 2.4 Plano MINIMO (restauração de teste de boot custom)

```
# slot alvo = slot atualmente offline (rodar NUNCA no slot ATIVO antes de verificar)
fastboot flash boot_<slot> boot_custom.img     # swap kernel
fastboot flash vendor_boot_<slot> vendor_boot_<slot>.img   # só se kernel reclama de modules
fastboot flash dtbo_<slot> dtbo_<slot>.img                 # só se DTB errada
fastboot flash init_boot_<slot> init_boot_<slot>.img       # só se algo no init muda
# NÃO mexer em vbmeta, preloader, lk, md1img, super.
```

### 2.5 Plano COMPLETO (quando o aparelho vira brick ou pós retenção)

1. Guardar backups locais primeiro (`backup-2026-10-05` está imutável/hasheado).
2. Tentar fastboot apenas no slot de contingência: `fastboot set_active <a|b != ativo>; fastboot flash boot_<slot> boot_<slot>.img`.
3. Se chegar recovery/MiFlash: `flash_all_except_data_storage.sh` (preserva userdata).
4. Se houver `flash_all_lock.sh` e vktbmeta muds: roda `flash_all` (full) para alinhar vbmeta+boot+lk; **somente uma vez** e com Bootloader desbloqueado.
5. Re-integrar Magisk `init_boot`/`boot` rooteando posterior.

## 3. `fastboot getvar all` do lake

- `FACT` (reddit `r/Xiaomi` "Redmi 14c Boot issues", 2025-10-18): reporta `nv data is corrupted` + recovery loop + locked BL; não há saída de `getvar`. Perfil de dispositivo identificado como POCO C75. https://www.reddit.com/r/xiaomi/s/wRkm2xkBxK (t/redmi_14c_boot_issues).
- `FACT` (YuKongA/ghostlock-app issue #280, 2026-10-03): dados do aparelho POCO C75 (` lake_global, Model 2410FPCC5G, MT6769, HyperOS 3.0.306.0.WGTMIXM, Android 16, security patch 2026-07`). Sem `getvar`. https://github.com/YuKongA/ghostlock-app/issues/280
- `FACT` (MiCode #41145, pedido kernel lake): dados correlatos.
- `UNVERIFIED`: não consegui capturar log público com saída literal de `fastboot getvar all` para lake/Redmi 14C/POCO C75 em XDA/4PDA/Reddit que fosse citado. Query sugerida: `"Redmi 14C" OR "POCO C75" OR "2410FPCC5G" "getvar all" -"product:"`; wiki.
- `fastboot boot` em relato específico do lake: **sem relato**. Relato Xiaomi MTK mais amplo: MiCode #2356 onde `fastboot boot` funciona parcial/bugado (TWRP que vira "system", "too many links", unknown command em sunstone) ⇒ negar ficha para lake.

## 4. Estado de unlock Xiaomi vs re-lock trava na custom ROM

- `FACT` (hetih: thread do guia Bootloader Unlock Xiaomi MTK na XDA): bl unlock é por conta Mi + espera; se abre com `fastboot oem unlock` (revogado por `flashing lock`). Acknowledgement oficial tem permissão via `fastboot oem lks` tanto que anti=1 baixo (medido: `anti=1`).
- `FACT` (reddit Redmi 14C boot issues): re-lock com ROM custom falhou — indica que o `seccfg`exige rollback-index ≥ anti (anti=1 aqui) e `verifiedbootstate=orange`; sem auth, re-lock vai um brick loop.
- `INFERRED`: se `seccfg` já setado "unlocked=yes", flashear boot custom com bootloader desbloqueado **não é barrado pelo Mi Unlock**; voltar a stock (boot stock no slot) já carrega trust chain.

## 5. Bootloop/brick com kernel/boot custom em lake

-_`FACT` (sergiofalconp24-hub/dew-kernel): README alega kernel custom para "POCO C75" usando Android 16 kernel GKI; instrui `fastboot boot out/boot_custom.img` (que do local workaround #1 era bugado) — mas **sem screenshot/log de boot**. https://github.com/sergiofalconp24-hub/dew-kernel
- `FACT` (KernelSU-Next #731, MesmoRedmi 14C lake): kernel 6.6.30 falhou "No compatible ramdisk found" via boot.img; **resolveu com patchado `init_boot`**. Indica que kernel custom sem o ramdisk certo vira silent-bootloop. https://github.com/KernelSU-Next/KernelSU-Next/issues/731
- `FACT` (XDA TWRP lake thread Feb 2026): 1º build não bootava (bootloop); 2º build tinha bugs com `touch screen, decryption, fastbootd`; vbmeta/decryption=AVB. https://xdaforums.com/t/developmenttwrpunofficiallake-xiaomi-redmi-14c.4758686/
- `FACT` (Reddit Redmi 14C Boot issues): flash de ROM custom seguida de re-lock → bootloop persistente, nvdata corrupted, sem fastboot. Sem fontes do mba.
- `FACT` (mtkclient #219): varios C75/14C sofrem `DL forbidden 0xc0020004` ⇒ BROM/SP não ressuscita; sobra fastboot+recovery+OTA (MiFlash exige auth).

**Conclusão:** para kernel custom, o recovery loop real de lake hoje: (a) `init_boot` não patchado/mantido correto (kernel 6.6.30 — Mismatch ramdisk), (b) `Image` kernel diferente do Config/mkbootimg header v4 padrão , (c) AVB-footprints/decrypted dados se Magisk injeta `ramdisk=` no nome errado. Kernel divergente do `bootconfig` citado (MEASURED: cmdline `bootopt=64S3,32N2,64N2`) igualmente derruba.

## 6. Saídas geradas

- `research/OPENCODE2b_recovery_firmware.md` (este arquivo) — já está no destino.
- Cópia espelhada em `<lake-kernel>/research/OPENCODE2b_recovery_firmware.md`.
- Auto-revisão: nada de FACT sem pon URL/saída: Fastboot ROM oficial OS3.0.306.0 Fastboot nunca aparece → classificado como "recovery apenas, fastboot unknown". Headline #1 corrigido conforme §1.2. Os `.img` hash/raw continuam como linhas anteriores.

---

*Fim do relatório.*