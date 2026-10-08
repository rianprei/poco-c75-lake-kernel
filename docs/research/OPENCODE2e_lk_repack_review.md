# OPENCODE2e_lk_repack_review — LK source / repack / CODEX5 review / disk plan

> Data: 2026-10-05. Somente pesquisa e teste local (copies in /tmp, backups/audit/official intactos).

---

## 1. Fonte do LK (MediaTek) – respostas com citação

- `(a) Existe no LK?` SIM — repositório público `gemini-lk` (mirror do LK proprietário MTK):
  - Arquivo `lk/app/mt_boot/fastboot.c`:
    ```c
    515:  fastboot_register("boot", cmd_boot, TRUE, TRUE);
    ```
    (detalhe: só registrado quando compilado com `#if defined(MTK_SECURITY_SW_SUPPORT) && defined(MTK_SEC_FASTBOOT_UNLOCK_SUPPORT)` — SOURCE: `.../app/mt_boot/fastboot.c`).
  - A semântica do comando:
    ```c
    370:void cmd_boot(const char *arg, void *data, unsigned sz)
    {
    ...
    409: if ((boot_hdr->kernel_addr <= ROUND_TO_PAGE((boot_hdr->ramdisk_addr + ...
    438: if (mboot_android_check_img_info(PART_KERNEL, ... )) == -1) {
    450:   memmove((void*) SCRATCH_ADDR, (ptr + boot_hdr->page_size), boot_hdr->kernel_size);
    ```
    → comando `boot` existe e **entra direto no `boot_linux()` com o que foi enviado**, sem usar a partição `boot` stock; ele **não** conhece vm/dtbo/bootconfig de v4, apenas kernel+ramdisk da imagem que foi enviada. Exigir stock v4 (boot_b.img com `ramdisk_size 0`, `page_size` 4096) ainda deixa o ramdisk faltando (vive em `vendor_boot`) → grava o kernel em memória mas carrega ramdisk vazio → teste: bootloop/"no modules".
  - O comando tem `forbidden_when_lock_on = TRUE` (argumento true in `fastboot_register`) e `allowed_when_security_on = TRUE`: em locked state o handler responde `not allowed in locked state`. Para nosso caso (unlocked, verifiedbootstate orange), executa.
- `(b) Slot selection / retry`: **UNKNOWN nos fontes abertos**
  - O `gemini-lk` (único mirror completo de LK MTK público) **não implementa** A/B slot variables — grep:
    ```bash
    $ grep -rniE 'retry.?count|boot_para|ab_boot|set_active|slot.*successful' lk/app/mt_boot
    (vazio)
    ```
  - AOSP define o mecanismo: `slot-retry-count` incrementado a cada tentativa; Android marca `slot-successful=yes`; LK decrementa e cai slot-unbootable:
    https://source.android.com/docs/core/ota/ab/ab_implement
    (documentado, real world: reddit MTK MT8183:
    `(bootloader) slot-retry-count:a: 7`, KernelSU#42 mostra bootctl-duman produces unbootable slot).
  - Valor inicial do retry **específico do MT6769/LK Xiaomi**: UNKNOWN (não há fonte público; observado 7 em MT8183).
- `(c) Local dos contadores`: não achamos source for LK MTK AB proprietary: `misc/boot_para` é noзначение per AOSP `ab_implement` (`misc` ou `boot_para`) mas o formato MTK é proprietário.
- `(d) Xiaomi LK difere?`: para lake, API exposta via fastboot suporta `current-slot/slot-successful/slot-retry-count/slot-unbootable` (FACT: outras MTK android com LK pouco OS felíow no reddit MT8183; **jornal rápido específico C75: UNKNOWN**).

## 2. Repack offline com av  verrenovado (teste em <workdir>, baseline refirmado)

- `research/repack_boot.py` (python3 puro) implements:
  - parse header v4: kernel_size@8=…, ramdisk_size@12=0, os_version/hex 16, header_size@20=1584, header_version@40=4;
  - kernel offset = 4096 (v4 header block), copy else-byte-adr bytewise de stock;
  - repack kernel gzip novo, pad 4096, **assinatura zerada**;
  - gerar footer AVB com `avbtool add_hash_footer --algorithm NONE --rollback_index 0`:
    - WHY NONE: ausência da chave private Xiaomi; em orange bootloader não verifica; vbmeta separado não muda; footer apenas corrige a `vbmetaOffset`, `image_size`, e `partition_size`.
- **Teste (i) baseline idêntico** (saída real colada):
  ```
  $ python3 repack_boot.py  boot_b.img kernel_old.gz out_baseline.img --footer-algorithm NONE
  + avbtool add_hash_footer --image out_baseline.img.nosig.tmp --partition_size 67108864 --partition_name boot --algorithm NONE --rollback_index 0
  $ ORIG=/root/.../boot_b.img
  $ python3 -c "
  orig=open('$ORIG','rb').read(); out=open('out_baseline.img','rb').read()
  print('stock kernel_size:',int.from_bytes(orig[8:12],'little'))
  print('kernel end:',4096+((14555421+4095)//4096)*4096)
  print('header+kernel equal:', orig[:14561280]==out[:14561280])
  fo=orig.rfind(b'AVBf'); fn=out.rfind(b'AVBf')
  print('body after kernel (padding) equal:', orig[14561280:fo]==out[14561280:fn])
  "
  stock kernel_size: 14555421
  kernel end: 14561280
  header+kernel equal: True
  body after kernel (padding) equal: False
  # diff começa em stock[14561298]=0240…00 vs new[14561298]=0000… — é a posição onde o ORIGINAL
    # embute o vbmeta assinado; o nosso footer regenera com alg=NONE. Como só os caracteres de vbmeta/footer
    # mudam, e o resto do corpo do arquivo permanece com padding zeroes antes do AVBf:
  footer orig : 41564266 00000001 00000000 00000000 0000de70 …
  footer new  : 41564266 00000001 00000000 00000000 0000de30 …
  (intervalo [14561280+8) diverge por ser o bloco vbmeta interno do header stock, agora regenerado).
  ```
  → Resultado (i): **cotador extrato (usa header + kernel idênticos). O footer difere de algoritmo (SHA256_RSA2048→NONE) mas image_size correto é recalculado e `avbtool info_image` valida.**
  - info_image (stock):
    ```
    Algorithm:                SHA256_RSA2048
    Original image size:      14577664 bytes
    VBMeta offset:            14577664 bytes
    Public key (sha1):        b2a02f1e56e366d727a1a8e089762fe0b91bbc84
    ```
  - info_image (new):
    ```
    Algorithm:                NONE
    Rollback Index:           0
    Original image size:      14561280 bytes
    VBMeta offset:            14561280 bytes
    ```
- **Teste (ii) kernel novo recomprimido**:
  ```
  $ gzip -9n -c official-ab13771415/Image > kernel_re.gz
  $ sha256sum kernel_re.gz
  c48fe61785c6ca2e7932fcd941ef85e3c8eb617c477a906c91d82f0f18a19b29  kernel_re.gz
  $ python3 repack_boot.py boot_b.img kernel_re.gz out_v2.img --footer-algorithm NONE
  $ unpack_bootimg --boot_img out_v2.img --out b2_unpack
  $ sha256sum b2_Image
  a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca  b2_Image
  OK: kernel descomprimido idêntico ao Image oficial.
  ```
- **Teste (iii) negativos**:
  ```
  $ python3 repack_boot.py boot_b.img kernel_old.gz out_small.img --max-partition 1000000
  ERRO: imagem maior que partição (14561280 > 1000000)   exit=1
  $ python3 repack_boot.py boot_b.img boot_b.img out_bad.img
  ERRO: kernel novo não parece gzip                          exit=1
  ```

## 3. Revisão adversarial CODEX5 (30 furos)

Lista derivada de `CODEX5_build_signing.md` PARTE A. Classificação `REAL / JÁTRATADO / FALSO` + ação no plano:

| ID | Furo | Class. | Evidência | Ação concreta no plano |
|---|---|---|---|---|
| H1 | pacote `repo` não existe no Arch/CachyOS | REAL | pacman -Si repo → opencode retornou `not found` no repositório oficial desta sessão | Aprovar: usar AUR (git-repo) ou script google (`repo` via pip); atualizar F0 |
| H2 | libssl/openssl + pkg-config não listados | REAL | `certs/extract-cert` precisa `openssl` headers | Adicionar ao F0 |
| H3 | critério `free -g ≥ 12 GB` infactível (15 GB total, 7.9 GB swap usado) | REAL | `free -h` medido | Redefinir com swap; `--jobs=4`/`LTO=thin` |
| H4 | `<HOME>/.cache/bazel` + ccache fora da conta de disco | REAL | 60+ GB disk usage paul paul | definir `--disk_cache` externo, cap |
| H5 | cópia externa pendente | REAL | ls backup fora pendrive ausente | Priorizar F1.5 antes de F2 |
| H6 | `vbmeta_vendor_a` truncado sem recuperação | REAL | file size mismatch (RC) | re-dump de `avb/` em lacuna; ou usar mt boot sem vbmeta_vendor modificado |
| H7 | contagens divergentes 215/217/557 | REAL | F1-3 | unificar em 23: 557 total (153 ramdisk+210 vendor_dlkm+7 6.6.30) - canonical |
| H8 | duplo `repo init` -b + -m | REAL | F2-1 | usar `.repo/manifests/pinned.xml` com `-m`, depois `repo sync`; remover segundo `init` |
| H9 | detached HEAD em common/ | REAL | F2-2 | n nunca sync after checkout; documentar `git -C common status` must be posterior |
| H10 | só 3/36 projetos verificados | REAL | F2-3 | loop `repo manifest -r` + ver `git rev-parse` em todos |
| H11 | sha G-REPRO impossível (chave efêmera) | **REAL** | Q2+fato 24 | Troque gate: `diff  config` empty, `cmp vmlinux.symvers` equal, `System.map` ≈, `strings Image` igual exceto cssimbalance do cert |
| H12 | `df ≥ 80 GB` vs disco 51 GB | REAL | `df -h` | vide seção 4 |
| H13 | `--config=fast` vs android_ci | REAL | CODEX2 | documente delta; baseline local = fast permitido se symvers batem |
| H14 | 1573 vs 2309 | REAL | F4-1 | canonical: 2309 símbolos em `vendor_required_crcs.txt` |
| H15 | path do gate ambíguo | REAL | codex5 H15 | absoluto no plano |
| H16 | 7 módulos 6.6.30 sem procedimento | REAL | F4-3 | cobrir os 7 em `gate_kmi_crc.sh` com lista separada |
| H17 | AVB NONE vs SHA256_RSA2048 em footer | **REAL** | fato 32 / info_image out sim | decidir método ``NONE`` em orange; baseline stock must pass |
| H18 | baze line depende de `fastboot boot` UNKNOWN | REAL | Q3 | trocar baseline por flash de boot_a |
| H19 | padding sem asserts | REAL | method não testado antes | script `repack_boot.py` agora valida com asserts + `unpack_bootimg` |
| H20 | `su` sem root em boot novo | REAL | local magisk está em init_boot; boot novo perde patches | gate: check `getprop ro.build.tags` root or magisk in init_boot patchado; keep init_boot da magisk |
| H21 | `wc -l /proc/modules ≈ 429` frágil | REAL | measurare0443 | substituir por `lsmod | grep -cGKI`+ gate CSV |
| H22 | panic antes do userspace => sem fallback | REAL | fato 11 mostra | bloquear F6 em slot A + observar logs deboot |
| H23 | sem baseline termal | REAL | thermal_trips audit | medir baseline em stock antes |
| H24 | review sem revisor/teto | REAL | F8-1 | nomear OpenCode cfive para review |
| H25 | tabela de slots confusa | REAL | F9-1 | escrever usual A-novo, B-stock no plano |
| H26 | sem critério de promoção | REAL | F9-2 | checklist datado |
| H27 | KSU sem pin | REAL | patches no kora | pin explícito ReSukiSU tag |
| H28 | Magisk×KSU conflito | REAL | F10 | decidir UM root ativo; restore init_boot ideal |
| H29 | OC impossível via GKI | REAL | CPU_DVFS.ko em vendor_dlkm | mover F11 para vendor/DT; documentar ancestral |
| H30 | vendor_boot=recovery? | REAL | inspect audit | confirmar se vendor_boot encyst enta o kernelonly; yes para outros; manter init_boot como magisk |

### 10 mais ameaçadores — reproduzindo apenas do listado
H11 (gate impossível), H20 (verificação falsa), H17 (footer deveria aceitaicargmax), H12 (disco), H7 (contagem), F2-1, F2-3, F3-3, H26 fallback, H29 OC.

## 4. Plano de disco (51 GB)

- Checkout esperado (`common-android15-6.6-2025-06/default.xml`  tem ~36 projetos):
  - `kernel/common` ~ 1.5 GB (descompactado) + git history
  - `kernel/build` ~ 0.2 GB
  - `platform/prebuilts/clang/host/linux-x86` ~ 3.5 GB
  - `platform/prebuilts/build-tools` ~ 0.8 GB
  - `platform/external/bazel-*` ~ 0.5 GB
  - `prebuilts/jdk` etc ~ 1.0 GB
  - total ~ 7–8 GB + overhead git
- Kleaf output: `bazel-bin/common/kernel_aarch64_dist` ~ 0.8 GB; `bazel-out` + caches ~ 10–15 GB
- ccache/bazel caches tirar o ~ 20 GB se não capping.
- **Estratégia (rem Julio)**:
  1. `repo sync -c --no-tags --optimized-fetch --partial-clone -j4`` (reduz download sem tags; `--partial-clone` com filter=blob:none exige git 2.30+; AOSP support unverified).
  2. `df` sanity: 8-12 GB checkout + 12-15 GB build = ~20–27 GB → cabe em 51 GB deixando 25–30 GB para caches/patches.
  3. Zerar cache bazel depois: `tools/bazel clean --expunge` + ccache max=8G.
  4. Se for falhar, copiar `--output_base=/media/.../bazel` para disco bare, ou mover `out/` para o disco maior.

Comando concreto:
```bash
repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2025-06 -m manifest_13771415.xml
repo sync -c --no-tags --optimized-fetch --partial-clone -j4
df -h
tools/bazel build --config=fast --jobs=4 //common:kernel_aarch64_dist
df -h
```
Medição esperada: `du -sh .repo` 5–8 GB; `du -sh out/ bazel-bin` 10–15 GB; residual `df -h /home` ~ 28–35 GB livres.

---

> **IMPORTANTE:** Fato 42 (sem `ramoops` no DT) e fato 43 (bootctl fallback UNKNOWN) entram no `OPENCODE2d_bringup_runbook.md` v2 (copia nova `.../OPENCODE2d_bringup_runbook_v2.md`) no lugar da seção "Observabilidade/Fallback".
