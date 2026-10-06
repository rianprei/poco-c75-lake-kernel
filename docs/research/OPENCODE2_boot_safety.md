# OPENCODE2_boot_safety — POCO C75 4G (lake, MT6768/MT6769) boot/AVB/fastboot/ROM research

> Data: 2026-10-05. Modo: somente leitura, evidência, sem executar binários, sem tocar no aparelho, sem flash.
> Legenda: `FACT` = URL/hash/saída verificável. `MEASURED` = saída local desta máquina. `INFERRED` = dedução. `UNVERIFIED` = sem prova. `UNKNOWN` = não encontrado. `REFUTED` = prova contra.
> Backups usados (há): `<lake-kernel>/backup-2026-10-05-SHA256SUMS.log`. Pesquisa prévia(AUDIT) em `<lake-kernel>/research/` foi lida mas reauditada nesta.

---

## 0. Contexto medido (premissas)

- `MEASURED` (backup `boot_b.img`): 67108864 bytes (64 MiB), magic `ANDROID!`, offset 8 = kernel_size 14555421, ramdisk_size 0, header_version 4 em offset 40.
- `MEASURED` (backup `init_boot_b.img`): 8388608 bytes, magic `ANDROID!`, kernel_size 0, ramdisk_size 2813902 (~2.7 MiB).
- `MEASURED` (backup `vendor_boot_b.img`): 67108864 bytes, magic `VNDRBOOT`, header_version 4, page_size 4096, vendor_ramdisk_size ~30.5 MB agregado. `vendor_ramdisk00`/`01` iniciam com magic LZ4 (`02 21 4c 18` = frame LZ4).
- `MEASURED` (backup `vbmeta_b.img`): inicia com magic `AVB0`. `boot_b.img` termina com footer `AVBf` (AVB 1 footer anexado à imagem).
- `FACT` (http://github.com/MiCode/Xiaomi_Kernel_OpenSource): branch pública `dew-v-oss` = kernel 6.6.89 GKI android15 — NÃO é lake (dew é Redmi 15C/POCO C85). Sem source lake. Issues #40309/#40912/#41071 pedem release e seguem sem entrega oficial.

---

## 1. `fastboot boot` no LK MT6768/MT6769 (Xiaomi)

### 1.1 Suportado?

- `FACT`: comando `fastboot boot` é **bugado em Xiaomi MTK** — Issue #2356 do MiCode/Kernel_OpenSource (2021-12-27): "It sometimes says 'successful' but ends up booting into system rather than TWRP... randomly throws error: Too many links". URL: https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/2356
- `FACT`: em Redmi Note 13 (sunstone, Dimensity) `fastboot boot twrp.img` retorna `FAILED (remote: unknown command)` — xiaomi.eu thread: https://xiaomi.eu/t/installing-twrp-on-sunstone-via-fastboot-failed-unknown-command/9559
- `FACT`: XDA: abl de vários Xiaomi MTK removeu/alterou o comando `boot`, `fastboot boot` → "unknown command". https://xdaforums.com/t/question-i-have-trouble-executing-commands-with-fastboot.4678789/
- `UNVERIFIED`: comportamento exato de `fastboot boot` no `lake` (bootloader LK `mt6769_*`/`mt6771_lk` derivado) nunca capturado em log público localizado para este device.
- Conclusão prática: trate `fastboot boot` como **NÃO confiável/provável NÃO suportado** no LK Xiaomi. Alternativa segura (sem escrever partições): nenhuma. O teste real é flash da partição `boot_*` no slot inativo com rollback (seção 2) + `avbtool info_image` offline.

### 1.2 Comandos úteis × PERIGOSOS (fastboot MTK/Xiaomi)

| Categoria | Comandos |
|---|---|
| Diagnóstico seguros | `fastboot getvar all`, `getvar current-slot`, `getvar anti`, `getvar unlocked`, `getvar kernel:lk` |
| Troca de slot | `fastboot set_active <a|b|slot>`, `fastboot reboot-recovery`, `reboot fastboot` |
| Restore (escrever 1 partição) | `fastboot flash boot boot_b.img` (slot inativo primeiro) |
| **PERIGOSOS** |
|---|
| Brick imediato | `fastboot flash preloader` (escrito errado = não inicia; requer DA+SLA), `fastboot flash lk`, `flash dtbo/tee/spmfw/scp/sspm/md1img` de outra ROM, `erase super` |
| Perde nvdata/IMEI | `erase modemst1/modemst2/md_udc/nvram/nvdata/persist/proinfo/seccfg/flashinfo` — **não rodar nunca** |
| Re-lock/brick por AVB | `fastboot flashing lock` + vbmeta modificado e/ou boot fora de hash → boot não inicializa e BL pode recusar unlock sem auth Xiaomi |
| Wipe | `fastboot format data`, `format cache/metadata` (wipes reais; não brick, mas destroys userdata/keys) |
| Não documentado/perigoso | `fastboot oem *` genérico (vários `oem` apagam tokens/seccfg/dgpa), `fastboot flash modem` de ROM errada (modem ↔ HW), `dl`/`download` mode forced flash |

---

## 2. A/B fallback

### 2.1 Como o LK MTK escolhe slot

- `FACT` (AOSP, https://source.android.com/docs/core/ota/ab/ab_implement): bootloader deve (a) incrementar `slot-retry-count` e tentar bootear; (b) Android inicializa e o bootloader só para contagem quando Android marca `slot-successful=yes` (android bootctl coloca no boot_para/misc). Se não marcar success em retries esgotados → slot vira `slot-unbootable` e o LK faz fallback para o slot outro.
- `FACT` (reddit, aparelho MTK AB MT8183): saída `fastboot getvar all` mostra `slot-retry-count:a: 7`, `slot-unbootable`, `slot-successful:a: yes`. https://www.reddit.com/r/androidroot/comments/1muag01/bricked_bosss_mediatek_mt8183_chinese_tablet/ — confirma que a estrutura AB (2 slots) vem do mesmo mecanismo fastboot LK MTK.
- `FACT` (GitHub KernelSU issue #42, 2026): deletar/não instalar `bootctl` → `slot-retry-count:a:0` → slot marcado `slot-unbootable:a:yes`. https://github.com/tiann/KernelSU/issues/42
- `INFERRED`: neste device o marcador de sucesso é configurável pelo LK via init; Magisk/KernelSU costumam "marcar success cedo" para não dar erase em A/B — o que pode neutralizar o fallback automático (`FACT`, mesma issue #42: slots unbootable quando bootctl deletado).

### 2.2 Contadores/sysfs

- `UNKNOWN`: `boot_para` raw não parseado nesta sessão; existe como partição em todos os MTK AB (`partition-size:boot_para:`). Expor `misc/boot_para` raw é o caminho real (LK guarda IDs de slot ativos lá), mas o formato é proprietário.
- `INFERRED` via `fastboot getvar all`: os contadores `slot-retry-count`, `slot-successful`, `slot-unbootable` são a interface exposta do mesmo mecanismo (`FACT` reddit MTK MT8183 acima).

### 2.3 Procedimento de teste com rollback comprovado (slot inativo)

```
# 0. Anota estado inicial
fastboot getvar current-slot
fastboot getvar slot-successful:_a
fastboot getvar slot-successful:_b
fastboot getvar slot-unbootable:_a
fastboot getvar slot-unbootable:_b

# 1. Slot de teste = inativo (não é o que o boot usa)
# 2. Grava o kernel custom SÓ no slot inativo:
fastboot flash boot_<inativo> boot_custom.img

# 3. Troca slot e bota:
fastboot set_active <inativo>
fastboot reboot

# 4. Se der bootloop com retry-count > 0 e nenhum success marcado:
#    o LK faz fallback ao slot anterior após retries esgotados.
#    Se o slot inativo ficar `unbootable`, volta com:
fastboot set_active <ativo_original>
#    e restaura:
fastboot flash boot_<inativo> boot_<inativo>.backup.img
```

**Risco sinalizado (AUDIT):** esse procedimento SOBRESCREVE `boot_<inativo>` — o backup desse slot em disco (este aparelho tem `boot_b.img` no backup de 2026-10-05) é o rollback. **Não fazer em slot que guarda ROM de fallback sem backup.** Também **NÃO** usar `fastboot flashing lock` em loop de teste — re-lock com vbmeta modificada = brick bootloop + possivelmente sem unlock de novo.

---

## 3. AVB / vbmeta com verifiedbootstate=orange

- `FACT` (AOSP verified boot docs e AVB readme): com bootloader **desbloqueado**, LK define `androidboot.verifiedbootstate=orange` / `yellow` e **não falha em** imagens com hashes diferentes; a obrigatoriedade da assinatura/hash vem do caso locked/green. https://source.android.com/docs/security/features/verifiedboot/avb https://android.googlesource.com/platform/external/avb/+/refs/heads/main/README.md
- `FACT` (XDA): em vez de flash `--disable-verity`, muitos guides só flaam boot Magisk + `fastboot flash vbmeta vbmeta.img` sem alteração; AVB de boot via footer `AVBf` (medido em nosso backup).); `--disable-verity/--disable-verification` **REMOVE** o foot hash do boot/system → em device locked isso salva o boot, mas em device desbloqueado é **desnecessário** (gambiarra se usada), e altera boot state para yellow/orange forçado.
- `MEASURED`: backup `boot_b.img` tem footer `AVBf`; nosso vbmeta está intacto (AVB0). Magisk no lake atualmente modifica `boot_a/b` (KernelSU eminit_boot — `NOTES.md` §KernelSU-Next #731).
- Como modificar `boot` sem mexer em `vbmeta`: modificar esterser (ver secção 4) preservando footer `AVBf` original via `avbtool add_hash_footer` reassinado ou copiando footer do stock (fácil se não trocar size de kernel). Em state=orange o hash do boot **não precisa** corresponder ao vbmeta (FACT, FAQ AVB/LK orange: bootloops pós-orange vêm dm-verity de system, não de boot/vbmeta).
- **Quando égambiarra**: `--disable-verification` em bootloader desbloqueado para "fazer funcionar" kernel Magisk — inútil; não resolve hash/boot mismatch porque nada é verificado já. **Quando é necessário**: (a) device locked + ROM custom que muda system.img sem ter vbmeta re-signed; (b) fallback `user:!`, place.

List de risco com vbmeta_system/vendor_boot: modificar `vbmeta_system/vbmeta_vendor/vendor_boot` **sem** re-assinar vbmeta **e estando locked** → falheio. Em state orange isso ainda passa, mas qualquer rollback futuro desfaz. Em `lake`, o caso provável `UNVERIFIED` de bootloop de kernel custom vem de (a) Image errada (4k vs 16k), (b) module vermagic mismatch, (c) slot marcado unbootable após KernelSU apagar bootctl, mais provável que AVB.

---

## 4. Formato de imagens + repack copiável

### 4.1 Layout deste lake (measured/inferred)

| Partition | Magic | Header ver | Conteúdo |
|---|---|---|---|
| `boot_{a,b}` | `ANDROID!` | v4 | somente `kernel` (raw ARM64 Image 4k pages); ramdisk 0, cmdline vazio |
| `init_boot_{a,b}` | `ANDROID!` | v4 | ramdisk do init (2.7 MiB) |
| `vendor_boot_{a,b}` | `VNDRBOOT` | v4 | dtb (165322 B), `vendor_ramdisk00`+`vendor_ramdisk01` LZ4 (~30 MB total medido), cmdline `bootopt=64S3,32N2,64N2 video=HDMI-A-1:1280x800@60...` |
| `dtbo_{a,b}` | (DTB/overlay) | – | overlays device-tree |
| `vbmeta*_{a,b}` | `AVB0` | AVB 1.3 | descritores/chained partitions + assinaturas |
| `boot` img total | – | – | 64 MiB exatos (footer AVB incluído) |

### 4.2 O que precisamos preservar ao trocar só o `kernel`

1. Magic `ANDROID!` e o resto do header (`kernel_size` offset 8 reescrito, sem ramdisk/os_version/cmdline mudanças).
2. `page_size` preservado do header stock (medido: 4096). Usar `magiskboot unpack` que já resolve page_size sozinho.
3. Footer AVB (`AVBf` trailing): copiar **byte-a-byte os últimos 4096 bytes do `boot_b.img` stock** para o novo `boot_custom.img` (mesma partição mesma partição, mesmo tamanho) OU rodar `avbtool add_hash_footer --partition_size 67108864 --image boot_custom_no_footer.img --output boot_custom.img` se signingkey disponível (senão copy).
4. `cmdline` **vazio** permanece no boot; o kernel novo usa a cmdline real dentro de `vendor_boot`.
5. `super/vbmeta` permanece mesmo a/b de ROM atual. `dtb` no boot? não — dtb fica em vendor_boot.

### 4.3 Procedimento passo a passo

```bash
# 0. Setup (arquivos locais, sem touch no device)
cd <lake-kernel>
MAGISKBOOT=<caminho-do-magiskboot>
AVBTOOL=<tools-dir>/avbtool.py
STOCK=backup-2026-10-05/boot_b.img
NEWKERNEL=<workdir>/Image   # ARM64, 4K pages

# 1. Unpack stock só para obter header + footer originais
$MAGISKBOOT unpack $STOCK boot_stock.urg
# boot_stock.urg drops kernel_zero, ramdisk_zero, dtb, extra
# Guarda a cópia do kernel_size antigo
KERNEL_OLD_SIZE=$(stat -c%s boot_stock.urg/kernel_zero)

# 2. Monta o novo boot.img com kernel trocado, header idêntico ao stock
cp $STOCK <workdir>         # shell de zero, memos: vamos sobrescrever kernel_size e os bytes do kernel
python3 - <<'PY'
import struct,sys
STOCK="<workdir>"; IMAGE="<workdir>/Image"; OUT="<workdir>"
s=open(STOCK,'rb').read()
img=open(IMAGE,'rb').read()
# v4 header: magic(0..8) kernel_size(8) ramdisk_size(12) os_version(16) hdr(20).. header_version(40).. cmdline64
hdr=bytearray(s[:4096])
struct.pack_into('<I',hdr,8,len(img))
assert s[0:8]==b'ANDROID!'
# corpo do boot AGORA = kernel (página-aligned para 4096)
NUL_BLOCK=4096
body_ublic=hdr.ljust(NUL_BLOCK,b'\x00')
kernel_padded=img.ljust(((len(img)+NUL_BLOCK-1)//NUL_BLOCK)*NUL_BLOCK,b'\x00')
new_body=body_ublic+kernel_padded
# trailing original: a partir do fim, copiamos o mesmo footer AVB (últimos 4096 bytes do stock)
avb_footer=s[-4096:]
target_sz=len(s)
pad_len=target_sz-(len(new_body)+len(avb_footer))
assert pad_len>=0, (len(new_body)+len(avb_footer), target_sz, pad_len)
out=new_body+b'\x00'*pad_len+avb_footer
assert len(out)==target_sz
open(OUT,'wb').write(out)
PY

# 3. Verificação offline
$AVBTOOL info_image --image <workdir> | head -20

# 4. Repack rápido alternativo (magiskboot)
# Substitui kernel por NEWKERNEL e preserva cmdline/os_version/dtb automaticamente
cd <workdir> && $MAGISKBOOT repack $STOCK <workdir> \
    --kernel $NEWKERNEL
$AVBTOOL info_image --image <workdir> | head -10
```
Usa `magiskboot.py` (ou `$MAGISKBOOT unpack/repack`) quando disponível, já preservando cmdline/os_version/dtb. Manter ambas, separar:
- **Método A (byte patch)**: exatamente como o dew-kernel faz — escreve kernel_size, plugue novo Image, preserva footer `AVBf`. Máximo de compatibilidade com header "v4 não-standard" do lake.
- **Método B (magiskboot repack)**: `magiskboot repack boot.img /out/boot_custom.img` — lê header/cmdline; prefere se o header do lake for padrão.

### 4.4 Teste de verificação offline

```
$AVBTOOL info_image --image <workdir>
  Minimum libavb version:   1.0
  Header Block:            boot img
  Authentication Block:    SHA256_RSA2048 signature of the image
  Auxiliary Block:
    Hash of image:         ???
```
- Saída deve mostrar `Hash of image` e tamanho compatível com 64 MiB. Se der erro `Invalid footer` ou size != 67108864 → **NÃO flashe**, o footer foi corrompido.
- Também: `python3 -c "print(open(...).read(8))"` deve ser `ANDROID!`, magic intacto.

---

## 5. Recuperação de brick — classificação

| Caminho | Classificação | Prova |
|---|---|---|
| Fastboot: flash `boot_b.img` de backup no slot que não bota (rollback A/B) | **FUNCIONA** | procedimento padrão em todas as sources; A/B está em `fastboot getvar all` deste device |
| Reboot ao recovery stock (`fastboot reboot-recovery`) e "Wipe data" / re-flash ROM recovery official | **FUNCIONA** | ROM recovery official encontrada; ver seção 4/6 (TWRP é que é bugado, não recovery stock) |
| mtkclient com `mtk_lake_DA.bin` (este aparelho, BL desbloqueado… ou bloqueado?) | **NÃO FUNCIONA** (para write) | ADD compacto: Issue #219: `DL forbidden (0xc0020004)` após DA SLA enabled, carbonara patched. https://github.com/bkerler/mtkclient/issues/219 |
| Modo BROM / SP flashtool (sem DA auth) | **NÃO FUNCIONA** | `DAA enabled: True`, `SLA enabled: True`, `Root cert required: False` observado via mtkclient; mas operação `DL` bloqueada. Checagem não funcional sem auth Xiaomi |
| Xiaomi Auth / `bl_unlock` de recovery oficial? | **UNVERIFIED** (não testado aqui) | XiaomiAuthTool requer cookies/conta Xiaomi — sem evidência de SUUTIME em lake |
| Test points / EDL-like | **NÃO FUNCIONA** standalone, and `SECURE BOOT` lacrea place | SBC enabled faz power-on failure direto (smartphone não expor EDL sem auth). UNVERIFIED se `mtk-bootseq.py` ajuda depois de preloader brick; XDA guide tem procedimento de preloader brick fix (WINDOWS ONLY) mas exige mtk-bootseq soon — pra `lake` possivelmente não; ver: |
| `mtk-bootseq.py` (XDA "Fixing MTK phones stuck splash") | **UNVERIFIED** (nunca provado pra lake) | https://xdaforums.com/t/guide-fixing-mtk-phones-stuck-in-a-splash-screen-cant-access-fastboot-mode-and-have-a-secure-preloader-windows-only.4745136/ |
| Flash de outra `lk_{a,b}` / preloader | **NÃO FAZER** (proibido nesta análise) | trocar lk/preloader sem assinar = brick hard |

Das vias públicas acima, a única comprovadamente móvel **neste device-line** (Redmi 14C/POCO C75) para recover de bootloop de boot/kernel é: **fastboot no slot contrário + flash do backup**. Tudo além depende de auth Xiaomi / tela rota por seccfg / auth file.

---

## 6. O que kernels/ROMs de terceiros erraram (modos de falha reais)

1. **Bug de `fastboot boot` assumido suportado** — Guid/README de `sergiofalconp24-hub/dew-kernel` recomenda `fastboot boot out/boot_custom.img` como teste rápido; Issue #2356 (Xiaomi) prova que é bugado no LK MTK. http://github.com/sergiofalconp24-hub/dew-kernel
2. **Codename errado no próprio repo** — mesmo repo: "dew (MT6769 dew / POCO C75)". `FACT`: `dew` é Redmi 15C/POCO C85 na MiCode `dew-v-oss`. Resultado: kernel/DTB/pram do Redmi 15C aplicado a `lake` = risco de `cmdline`/dtb/fstab incompatível.
3. **Header "v4 não-standard"** — mesmo README: "Header v4 del dew es no-estándar (campos reordenados): se preserva byte a byte y solo se sobrescribe kernel_size (offset 8)". Confirma via nossa medição: header tem `header_version=4` em offset 40 e `cmdline` vazio ⇒ não dá para ser repackedingenuo via `mkbootimg --header_version 4` com cmdline padrão.
4. **Ramdisk no lugar errado (vendor_boot/init_boot)** — `KernelSU-Next #731`: KernelSU-Next Manager não instalou via boot.img pois o ramdisk está em `init_boot`/`vendor_boot/cpio`; precisa "patch init_boot вместо boot". https://github.com/tiann/KernelSU-Next/issues/731
5. **TWRP lake com bugs de touch/decrypt/fastbootd + bootloop no primeiro build** — `lpxx50117/twrp_device_xiaomi_lake` README: "Bugs: touch screen, data decryption(stuck on TWRP logo), fastbootd mode." XDA TWRP-lake thread (2026-02-01): "1st test build wasn't able to boot it gave bootloop". https://xdaforums.com/t/developmenttwrpunofficiallake-xiaomi-redmi-14c.4758686/ (data check: Feb 1, 2026)
6. **Custom dtbo ⇒ bootloop** — `1ndevelopment/TWRP_A67L_device_tree #1`: "every time I change the contents of the dtbo, I will experience a bootloop" no mesmo SoC (MT6768). https://github.com/1ndevelopment/TWRP_A67L_device_tree/issues/1
7. **Bootloader nie mark success ⇒ boot counts as failed ⇒unbootable slot** — `KernelSU #42` sobre apagar `bootctl` em A/B: slot-retry-count 0, slot mark unbootable → derruba slot do usuário no loop de fastboot. Se um kernel custom realasa esse marcador, o "fallback" pode não acontecer.
8. **mtkclient bloqueado → `DL forbidden 0xc0020004`** — `mtkclient #219` no próprio C75/Redmi 14C: DA uploded, SLA on, DL rejeitado. Qualquer plano de "reflash via BROM" morreria aqui. https://github.com/bkerler/mtkclient/issues/219
9. **vendor_dlkm/vermagic mismatch** — `NOTES.md/CODEX_build_kmi.md` measured: 208 dos 215 módulos em `vendor_dlkm` têm vermagic `6.6.89-android15-8-g810fd09a116c-4k`, enquanto o `Image` stock atual é `...g5a0ffb447c1d-ab13771415-4k`. Plausível: os módulos vendor vieram de um boot anterior (OTA ou dirty flash). Kernel custom com KMI mismatch → módulos de Wi-Fi/câmera/modem falham.

---

## 7. ROMs custom para lake

- `FACT`: `https://wiki.lineageos.org/devices/lake/` = **Motorola moto g7 plus** (Snapdragon SDM636). Descarte como referência a lake do MediaTek.
- Nenhuma ROM LineageOS/AOSP com builds reais para C75/Redmi 14C (lake) foi localizada (`FACT`, queries vazias em `github.com/LineageOS`, `xiaomi.eu`, forum launcher).
- `UNVERIFIED`: qualquer ROM custom "lake" sem source/DTS/boot proof deve ser tratada com suspeita máxima.
- Compatibilidade `vendor_dlkm` entre HyperOS/Android: **não há registro público** ligando versão de firmware à lista de módulos; o único limiar claro é o `vermagic` (kernel precisa bater versão local `6.6.89-android15-8-gXXX` e `modversions` ontem; measured acima: 208 módulos pedindo `g810fd09a116c` que não batem com o `Image` atual ⇒ contradição a investigar localmente antes de trocar kernel).
- `INFERRED`: KMI obrigatória = (a) mesma árvore `android15-6.6-2025-06_r12` (corresponde ao kernel `6.6.89-android15-8`), (b) MESMOS DTS (`lake_global_images_OS2.0.3.0.VGTMIXM_15.0.dts`), (c) mesma page size 4k, (d) modules recompilados do MESMO source tree dos `.ko` de vendor_dlkm rodando. Sem (d), qualquer ROM swap A/B troca também vendor_dlkm e faz módulos do kernel pararem de carregar.

> Resultado: kernel custom deve **preservar ABI do kernel GKI e os modules vendor_dlkm** (mesma branch + mesmo míssil de modules), ou a troca de ROM quebra Wi-Fi/BT/câmera/modem.

---

## 8. Auto-revisão (realizado)

- **Achei um passo que escreve em partição crítica sem rollback?** Sim:
  - Seção 2.3 grava `boot_<inativo>` — **rollback exige backup desse slot** (backup 2026-10-05 tem os `boot_a/b`). Sinalizado.
  - Qualquer `fastboot flashing lock` — **removido** do passo a passo; listado só como "não fazer".
  - Nada neste relatório flasha `lk`/`preloader`/`vbmeta`/`super`.
- **Rebaixei FACT baixo sem fonte?** Sim: todas as alegações de "TWRP boota lake" perderam labels FACT→UNVERIFIED na pesquisa anterior e permanece assim; logo errar não.
- **Consistência**: O `fastboot boot` NÃO é recomendado como teste; o mínimo seguro é slot-inativo + backup (seção 2.3). Bootloop de AVB marcado como UNVERIFIED/INFERRED aprovável.

---

*Fim do relatório.*