# OPENCODE2d_bringup_runbook — POCO C75 4G (lake)

> Data: 2026-10-05. Somente leitura/pesquisa. Nenhuma escrita no aparelho.

---

## PARTE A — FMEA (plano v2)

### F0 Pré-requisitos host
| Falha | Severidade | Probabilidade | Detecção pré-flash | Mitigação | Evidência de pass |
|---|---|---|---|---|---|
| `repo`/`bazelisk` ausente | funcionalidade | alta | `repo --version` falha | install sem root (cargo/AUR), avisar antes | saída de `repo --version` |
| `df`/`free`/disco insuficiente | bootloop/host | alta | `df -h /home` <50 GB, `free` <12 GB | Usar disco externo, aviso ao dono | `df`/`free` com 50 GB+ / 12 GB+ |
| Arch python version mismatch | funcionalidade | média | `python3 --version` > 3.12 quebra autotools antigos | usar hermetic copy do kernel tree | `tools/bazel --version` ok |

### F1 Backup completo
| Falha | Severidade | Detecção pré-flash | Mitigação | Evidência |
|---|---|---|---|---|
| sha diff entre aparelho e host | brick | `sha256sum(audit/...)/sysfs-src` | regravar dump | `sha256sum -c` 42/42 ok |
| Faltam peças (vbmeta_vendor_b, lk, preloader_raw, seccfg, nvram, proinfo…) | brick (BROM path falha) | listing do backup | completar rotas | listing bate com conhecimento de partições (by-name) |
| Sem cópia externa | perda de dados | `rsync ... /mnt/ext` ausente | backup externo (curto) | saída do `rsync` e `sha256sum -c` externo |
| Disco único preenchido | truncamento | `df` ~88% usado | copiar fora e limpar | `du -sh backup*` + apagar caches |

### F2 Checkout fonte
| Falha | Detecção pré-flash | Mitigação | Evidência |
|---|---|---|---|
| `repo sync` falha porque upstream `android15-6.6-2025-06` movido para `deprecated/` (manifests referencia o ref inexistente) | `git ls-remote` do branch | usar `manifest_13771415.xml` via `-m` e pin em cada projeto | `git -C common rev-parse HEAD` == 5a0f… |
| Tag r12 errado | `git describe` não bate | cat trecho do Makefile | `grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL)' common/Makefile` = 6/6/89 |
| Kernel recompilado diverge de boot_b porque `BUILD_NUMBER`/chave efêmera diferente | F3 G-REPRO | ter em mente que strings são iguais nao provam igualdade | `sha256 Image == a023…` (se não, investigar manifests/config) |

### F3 Build de controle
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| `sha256 Image` desigual do stock -> build não-reproduzido | sha256 comparação com `a023…` | Investigar config/tag/toolchain | Opção A: sha igual -> pass; B: strings/diffconfig |
| `.config` diverge: LTO_THIN, CFI, SCS, MODVERSIONS, LOCALVERSION"-4k", CFI_CLANG ausente | `diff` output | Regenerar com gki_defconfig/Kleaf hermetic | `diff(authorized, actual)` vazio ou explicado |
| `repo`/bazel cache corrompido | vários | `bazel clean --expunge` | build segundo tempo igual |

### F4 GATE-KMI-CRC
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| Script não encontra símbolos por formatação `vendor_required_crcs.txt` | saída vazia | Correr gate log dos 2 arquivos | '0 mismatch 0 missing' |
| CRC divergente num símbolo | loops FAIL, print MISMATCH | voltar F3 e diff config | "PASS" do script + `grep MISMATCH` vazio |
| Módulos vendor com 2 CRCs por siannos em GKI puro | validations | - | `dump_modcrcs.py` sem duplas |
| VERMAGIC com `g810fd09a116c` no Image novo | strings do novo Image | exigir bater com `_g5a0f…` | `strings Image | grep '^6\.6\.89'` trecho correto |

### F5 Repack
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| `avbtool add_hash_footer --algorithm NONE` diferente do stock (sha1 rsa key vs NONE) | `info_image` do new vs stock | **testar e aceitar footer sem alg apenas em orange** | ambos listados |
| `kernel_size` @8 não atualizado | header parse | parse com python ou `unpack_bootimg` | `unpack_bootimg` extrai kernel esperado |
| compressão inadequada (Image não Image.gz) | `file` | usar gzip igual ao stock depois do build | `file(out/dist/Image)` igual |
| Tamanho > 64 MiB | `stat` | imagem de boot truncada | `boot*.img` ≤ 64 MiB exato |

### F6 Teste real (boot)
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| `fastboot boot` não suportado | UNKNOWN `fastboot boot boot_b.img` | **não planejar nele**; usar slot inativo | log "unknown command" |
| Bootloop por config misteriosa | contagre boot_successful == 0 | set_active b ao cold-boot + backup do boot slot *a* intacto | `set_active b` + boot normal |
| AVB/verity barrando em orange | vbmeta algo | calter vbmeta nao necessario; não usar `--disable-verity` | orange estado + boot continua |
| Ramdisk faltando (KernelSU) => "No compatible ramdisk found" | 1ª vez no init | patchar init_boot, nao boot | `getprop sys.boot_completed == 1` |
| Kernel errado em slot errado | `adb shell getprop ro.boot.slot_suffix` | `set_active` correct slot + `flash_all_*` rollback | output coincide |
| `uname -r` ainda retorna ab13771415 | strings aboovar | usar `strings Image` com ab13771415 vs novo | `strings` novo diferente or matches expected |

### F7 Estabilidade
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| Panics intermitentes | `dmesg -T | grep -iE 'panic|oops|thermal'` | stress com `timeout`, `thermal_zone` logs | 30 min parse limpo |
| `boots-sys` não `sys.boot_completed` nunca 1 | `getprop` | restart manual | getprop = 1 |
| RAM leak forçado | meminfo/e meminfo leaks | manter `adb shell watch cat/sys/kernel/debug/...` | sem oom |

### F8 Review adversarial
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| Autor decide "OK" | revisão humana | agente não-author revisa | checklist assinado |
| Diff de config mentiroso | re-extrair | `./diffconfig`? | csv vs stock idêntico |

### F9 Promoção
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| Flashar em slot em uso | `getvar current-slot` antes | `set_active …` ?tmp | slot claro |

### F10 Customização (KSU)
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| Conflito com Magisk | reboot loop + magisk overwrite | UM root por vez | boot funciona + `magisk`/user adb |
| TRIM poda export KSU (se exports toolset lends needkust) | strict mode falha | expandir kmi list | abi diff vazio |
| KernelSU substitui bootctl | slot unbootable classifier | manter bootctl no init_boot | `bootctl` presente |

### F11 OC
| Falha | Detecção | Mitigação | Evidência |
|---|---|---|---|
| OC excede limite termal | `thermal_zones`/throttle | valores reduzidos → passo menor | 30min estável |
| DTB corrompido/apendo overlay induz panic | `fastboot flash dtbo_a dtb.img` swap de dtbo_doe s com dts errado | manter dtbo backups | imagem supressavei loaded |
| UPower/CPU_DVFS Vermagic mismatch | opa `lsmod` | kernel atualizado + vendor_dlkm meta | modules loaded |

### 15 FUROS reais
1. **F6 critério `wc -l /proc/modules` ≈ 429** — não prova correto; módulos esperados são 557+79+153; keep tolerável diff de `?`, sem formal.
2. **G-REPRO byte-idêntico do Image com chave efêmera** — impossível se a chave dev gera a cada build; gate deve aceitar só diff de cert/public key.
3. **F2 não verifica que `repo sync` realmente rodou**: ref `android15-6.6-2025-06` está em `deprecated/` → `repo sync` de `common` falha sem pin explícito.
4. **F5 produz footer AVB algoritmo NONE, mas gate exige "idêntico ao original"** — em orange basta garantir tamanho/avblob; exigir igualdade está errada.
5. **F6 Verificar com `adb shell uname -r`** — uname igual ao stock mesmo com novo kernel; gate fraco.
6. **F1 ainda pendente em "cópia fora do disco principal"** quando todo o pipeline depende do backup 42-item para rollback → deixa de ser gate.
7. **Q3 (fastboot boot stock) não tem roda registro**; premissa repetida sem teste.
8. **F7 `stress-ng` por termux** — não está instalado (`MEASURED",`repo/bazel/bazelisk MISSING,未复制 termux-tools ...) need adb/bash loop.
9. **`dump_modcrcs.py` + `gate_kmi_crc.sh` rodam com vendor_required_crcs.txt** mas o plano não previne que essa lista perca módulos em `df.size` NUC tál (codemeeter proof) — verificar linha count vs expected.
10. **F8 não nomeia agente de review** — fica em branco.
11. **F9 vs §teste real** inconsistência: F9 diz "flashar em boot_b?", mas runbook espera kernel custom em slot A (boot_a/novo + set_active A) enquanto B stock; schedule "manter B stock" não contradicho, porém passo de flash silent.
12. **F11 edit de DTB/dtbo não documentado com tools** — `dtc` não está instalado measured.
13. **`fastboot getvar slot-successful:_a`** depende de bootctl executar; se kernel aborta antes, success nunca é marcado → fallback ao slot original não é provado.
14. **`.hermes/plans` referencia `tools/bazel` mas F0 não garante `jre`+deps de script de bazel** certos.
15. **F10 `rm common/android/abi_gki_protected_exports_*`** mencionado como atalho que inferniza ABI; risco de Wi-Fi/BT INVERTIVÁVEL (protected).

## PARTE B — Runbook & Observabilidade

### Early-boot / módulos essenciais

Do `vendor_boot_b vb_b_r00` ramdisk (format inicial): `audit/modules/ramdisk/vb_b_r00/` contém apenas o placeholders EXT4 (o audit tem os .ko como vb_a_r00__* ) para o first_stage_init. `modules.load` para ramdisk tem hook like:

```
nxp_i2c.ko, fhctl.ko, btif_drv.ko, connadp.ko,
mtk-cqdma.ko, mtk-dvfsrc-*, mt6768_dcm.ko,
gf_fingerprint/sil_fingerprint, syscon-reboot-mode,
mali_prot_alloc_mt6768_r49.ko, mali_mgm_mt6768_r49.ko, mali_kbase_mt6768_r49.ko,
```
(ver `head -30 audit/modules/modules.load`). 

Dependências críticas por caminho:
- **UFS/eMMC**: runtime mostra `mmcblk0`, `mmcblk1` (e não UFS): módulos `mtk-cqdma`, `storage/mtk` fornecem access; sem eles o init não lê super/vendor_dlkm → falha.
- **Display/LCM**: `lcm_name=dsi_panel_c3n_46_03_0c_dsc_vdo` (cmdline) → driver do painel embutido no ramdisk; falha de `fb`/`dsi` vira tela preta silenciosa.
- **Clock/ regulators**: `clk-mt6768`, `mtk_dcm`; geram as máscaras usadas por `mt6768_dcm`.
- **Pmic/bateria**: `Upower.ko`, `mtk_battery_oc_throttling.ko`, `mt6768_pmic.ko`, `mtk_lbat`; sem eles o Android pode reboot-loop por battery/pstate.
- Se um desses falhar, o log aparece em `/sys/fs/pstore` como last kernel panic; o boot não completa `sys.boot_completed` e o slot fica `slot-unbootable`.

### Observabilidade

**v2 (CORRIGIDO por fato 42): NÃO há ramoops registrado no DT do `lake` — 0 nós.**

- `audit` mostra cmdline com `ramoops.mem_address=0x4d010000 ramoops.mem_size=0xe0000`, e config
  `CONFIG_PSTORE_RAM=y`, mas SEM device tree node chamado `ramoops` → o kernel custom não monta
  last_kmsg automaticamente. O caminho de crash real é **MediaTek AEE/mrdump → expdb → /data/aee_exp**
  (`audit/proc` mostra `aee_aed.pureason=reboot`, `mrdump` hostid). o driver `aee_aed.ko`/`mrdump` é
  dependência dura (ramdisk early-boot).
- Para obter snapshots de crash de forma confiável: ler `/data/aee_exp`/aee_bs_log/… depois do restauro.
- `/sys/fs/pstore` aparece mountado apenas quando um .lc recorda; mas com DT sem nó, sua cobertura não
  é garantida.

### Fallback A/B e slot success

**v2 (CORRIGIDO por fato 43): fallback A/B automático = UNKNOWN.**

- LK LK proprietário do Xiaomi lake NÃO expõe retry/set_active/boot_para (verificado: nenhum grep em
  gemini-lk/app/mt_boot retornou retry_count/boot_para/ab_boot). O mecanismo AOSP documentado está em
  https://source.android.com/docs/core/ota/ab/ab_implement mas **não há prova aplicada ao lake**.
- Teclas: `set_active b` por fastboot é o procedimento comprovado; o fallback automático só "mais
  provável" — não promise.

### Observabilidade (v1 histórico, mantido como referência do audit)

**v1 anterior afirmou ramoops/pstore verificado; corrigida acima via fato 42.**

- `audit/config.stock`: `CONFIG_PSTORE=y`, `CONFIG_PSTORE_RAM=y`, `CONFIG_PSTORE_COMPRESS=y`, validação de `SYSTEM_TRUSTED_KEYS=""`, etc.
- `audit/proc/cmdline.txt`: `ramoops.mem_address=0x4d010000 ramoops.mem_size=0xe0000 ramoops.pmsg_size=0x80000 ramoops.console_size=0x40000`.
- `audit/proc/mounts.txt`: `pstore /sys/fs/pstore pstore rw,…` → persistente entre slots lousa proveniente do mesmo endereço de RAM (red boots com base do sistema novo); se for reboot duro com queda de energia, o RAM de last_kmsg limita.
- `aee_aed.pureason=reboot`, `mtk_printk_ctrl.disable_uart=1`, `log_buf_len=2M`: transcrição kernel→aee persistido em expdb/mdata? Event tracker: `/data/aee` acervo.
- `proc/mounts` depois daaber a value show `/sys/fs/pstore`; leitura:
  ```
  adb shell ls /sys/fs/pstore
  adb shell cat /sys/fs/pstore/console-ramoops*
  ```
   ou local PC:
  ```
  adb pull /sys/fs/pstore <workdir>
  ```
- Se não aparecer pstore (kernel custom sem os configs), substituto: **contruct presageador**: copiar de uma build com `CONFIG_PSTORE`, OU usar sinais físicos (LED vermelho de morte real kernel panics, `vibrate` no watchdog `wdt` não estand; `aee` não dispara sem kernel sync) — mais robusto: manter `dmesg` em loop via `adb shell` durante boot inicial (early-stage: `adb shell 'dmesg -w'` antes de panic).

### Runbook bring-up (cada passo tem saída esperada)

**(a) Pré-condições**
```
$ adb devices -l            # ? device: model laker…
$ adb shell getprop sys.boot_completed
1
$ adb shell cat /proc/cmdline | grep -oE 'ramoops[^ ]+'
ramoops.mem_address=0x4d010000 ramoops.mem_size=0xe0000 …
$ adb shell ls /dd ..

$ fastboot getvar current-slot
current-slot: b
```
Todos esperados; se não, rollback antes de continuar.

**(b) Flashar somente boot_a**
```
$ fastboot set_active a     # esperado: "Setting active slot to 'a'... OKAY"
$ fastboot flash boot_a /path/boot_custom.img   # writers: "Sending 'boot_a'", "Writing... OKAY"
$ fastboot reboot          
```
Critério: boot log mostra kernel novo; `adb shell uname -r` = mesma string prevista (ex.: `6.6.89-android15-8-<gitsha>-ab13771415-4k`) + `adb shell getprop sys.boot_completed` == "1"; `dmesg | grep -iE 'warn|err'`, free of unknown_symbol.

**(c) Validar**
```
$ adb shell getprop sys.boot_completed   # == "1"
$ adb shell cat /proc/uptime             # > 60 s
$ adb shell dumpsys boot_completed?   # if returns 0/data, OK
```

**(d) Reverter**
```
$ fastboot reboot bootloader
$ fastboot set_active b
$ fastboot reboot
# se no shell:
$ adb reboot bootloader   # mesmo
$ adb shell reboot
```
Teclas do lake: `Vol+ + Power` → recovery (Vol+ (power) menu; `Vol+ + Power` exchanges `fastboot`). Vol- + Power = fastboot. `Vol- para Recovery teacher` even descritas região. **Fastboot key: Vol- + Power** (Xiaomi MTK family; `Vol- + Power` + power lever — fonte: XDA "Redmi Note 13 fastboot" + μ:##conhecimento): https://xdaforums.com/t/redmi-note-13-unlocking-bootloader-with-orange-state.4631641.

**(e) Se não responder (bootloop)**
- T0: segurar Power 10 s para forced reboot. Se voltar ao mesmo slot e bootloop continua:
- T0+30 s: `adb devices` vazio + `fastboot devices` mostra fastboot:
  ```
  fastboot set_active b
  fastboot reboot
  ```
- T0+2 min: se fastboot desaparece após 1–2 boots, o fastboot está no secondary slot; ainda deve responder aos comandos de teclas.
- Se não: não mexer mais; desligar 3 init; esperar30 s; voltar ao loop de avaliação.

> **NUNCA fazer:** apagar/formatar `userdata`, `erase cache/metadata`, `fastboot flashing lock`, `fastboot oem lock`, flash de `preloader/lk`, substituir/erase `super`. Lista derivada: `fastboot? flashing_lock` em disabled; `preloader` alterado = sem recovery; BROM/mtkclient bloqueado em DL forbidden.

### Fallback A/B e slot success

`INFERRED` de AOSP `ab_implement`: o bootloader decrementa `slot-retry-count` e, após esgotar, marca `slot-unbootable` e boota no outro slot; Android o marca sucesso no boot completo (`bootctl`). Para lake isso não tem log concreto capturado (`UNKNOWN`). Se um slot não bootar, e o bootctl nunca rodar, `slot-retry-count` cai para 0 e o slot é marcado unbootable — confirmando que fallback automático **só é provável**; formalmente `UNKNOWN` para este aparelho. Forçar manualmente: `fastboot set_active b` (slot original).

### Tabela sintoma → causa → diagnóstico → ação (mínimo 15 linhas)

1. `adb` não detecta, mas fastboot está ok → slot wrong / android side adb off. → `adb devices` leak? → `fastboot set_active b`.
2. Bootloop com `PGate` inativo → Image de boot danificado → `unpack_bootimg` load ai → restaurar `boot*.img` do backup.
3. `fastboot getvar current-slot` vê o wrong slot → erro no set_active → `set_active a` + reboot.
4. "No compatible ramdisk found" (magisk/KernelSU) → init_boot não patchado → patch init_boot, não boot.
5. Wi-Fi morto → cfg80211/mac80211 faltando módulos GKI assinados → `lsmod | grep cfg80211` → flash system_dlkm adequado.
6. "exports protected symbol" → vendor module carga tráfico protegido → `dmesg | grep EACCES` → whitelist RTOM.
7. AVB  "verification failed" → boot com lock state → retry set_active de rollback.
8. kernel panic early "Failed to mount /vendor" → DT wrong → check `file fdt_size`, reverter dtbo.
9. DTC simbol mismatch → DT depois que kernel loading: `openssl cms` inclusive → usar dtb do boot original.
10. `dmesg` vazio no boot novo → ramoops não montado → check pstore present ou use termo.
11. `img trg` show wrong localversion → *-ab…* mismatch estímulo → imagens novo ddrer.
12. "nvdata corrupted" → restore ROM oficial, não fix por boot.
13. Recovery lost após Magisk reboot → magisk install state corrupto → restore boot_a stock.
14. MTK DA fatal`DL forbidden` → preloader locked → NUNCA flash, usar `fastboot`/`recovery` only.
15. "Too many links" ao usar fastboot boot → divisor MTK → não usar `fastboot boot`, usar slot test.
16. "Invalid module format" → vermagic mismatch → ajustar kernel tags, não modules.
17. "Unknown symbol"  → CRC mudou → gate KMI CRC FAIL.
18. "adb devices" menciona "Recovery" mas se nulo → "recovery mode" OTA → `fastboot devices` works, `fastboot flash` init.
19. "Formato ericulty NOC" SDM error/help → eMMC corrup copy system_linear frg → reverter super dd of ar mais um pouco.
20. Tela preta transiente after exc resto launcher Logo off por driver LCM → dbg camera/log por device call.

---

*Fim do relatório.*