# CODEX4_dew_tree — MiCode `dew-v-oss` (REDMI 15C/POCO C85, MT6769) vs GKI r12 + pipeline sergiofalconp24-hub/dew-kernel

> Data: 2026-10-05. Sem clone (API GitHub bastou: compare payload com 183/183 commits; disco preservado em 51 GB). Nada executado de terceiros; boot.img (67 MB) do repo de terceiros NÃO baixado; só texto via web/raw. `dew_tmp.c` não lido além do necessário (binário+misto — fora do escopo de texto).
> Legenda: `FACT` (URL lida) / `MEASURED` (saída local) / `INFERRED` / `UNVERIFIED` / `UNKNOWN`.

## 0. Posição do dew na família (resumo)

- `FACT` (head `dew-v-oss` = `e91fa1498975bc6e268fa91fffdb855a369fe69c`, 2025-09-19, autor niyongqi@xiaomi.com — `MEASURED` via `https://api.github.com/repos/MiCode/Xiaomi_Kernel_OpenSource/commits/e91fa14...`): mensagem `Kernel: Xiaomi kernel changes for REDMI 15C / REDMI 15C / POCO C85 Android V` + `based on MTK release TAG: lc-master-v-t-alps-release-v0.mp1.rc-V4` + `config file used is dew_defconfig`. Stats: **0 arquivos, +0/-0** (commit marcador vazio).
- `FACT` (`https://api.github.com/.../compare/5a0ffb447c1d...e91fa1498975...`, payload 1.4 MB salvo em `/tmp/opencode/dew_compare.json`): `status: diverged, ahead_by: 183, behind_by: 12041, total_commits: 183` com **183/183 commits no payload**. Autores top: clive.lin 15, Qun-Wei Lin 11, Light Hsieh 7, Chris Li 7, Claude Yen 5, Yang Yang 5; 113/183 com tag `ALPS`, 0 merges `Merge` clássicos (13 são merges de sync `[Do NOT Sync]Merge branch android15-6.6 into alps-*`).
- `INFERRED`: os 183 são **backports/syncs MTK ALPS** sobre base antiga (12041 atrás do r12); delta propriamente Xiaomi = commit vazio. Para o lake (boot = GKI puro Google, fato 18 do plano): o dew **não** serve como fonte de kernel — serve como referência do que a MTK muda fora do GKI e do formato de entrega Xiaomi (marker commit + defconfig externa).

## 1. Os 183 commits por subsistema (soma 183/183 — MEASURED via classificação das mensagens)

| n | subsistema | o que muda (exemplos reais do payload) | relevante p/ lake? | toca KMI/CRC? |
|---|---|---|---|---|
| 22 | mm | folio/deferred-split, vmscan, zram/zsmalloc, memcg, page, oom | SIM (mesma base 6.6; checar se já está no r12) | ARRISCADO se portar (structs de mm) |
| 18 | sched/cpufreq/eas | vendor hooks find_new_ilb/find_energy_efficient_cpu/correcting cpu capacity (Jing-Ting Wu, Yun Hsiang, Peter-TY Tsai) | SIM (EAS/MTK hooks; lake usa sched vendor) | ARRISCADO (hooks mudam prototypes) |
| 15 | mtk-platform (aee/lpm/timer/logs) | aee coredump, lpm k66 idle, MMIO timer workaround, MTK_TIMER off, printk prefix, umh, mrdump | PARCIAL (mesmo SoC; mas lake boot é GKI puro) | NÃO (debug/platform, fora do KMI) |
| 13 | erofs/f2fs/fs | atomic content, bi_size check (Light Hsieh, Ed Tsai) | SIM (erofs é system; r12 já tem parte) | ARRISCADO se portar (fs structs) |
| 13 | merges-sync MTK | `[Do NOT Sync]Merge branch android15-6.6 into alps-*` (clive.lin e outros) | NÃO (só sync) | NÃO |
| 11 | mte (memory tagging) | esr/cpuhp/tag-match/SCTLR_EL1/SW trigger | NÃO p/ lake (MTE off no user) | NÃO (debug path) |
| 9 | ufs/mmc/block | ufs err-handler bypass (Peter Wang) e outros | SIM (storage; mas lake usa vendor) | ARRISCADO se portar |
| 9 | virt/pkvm/gzvm | pKVM FFA bypass, gzvm debugfs, ramdisk_node_list p/ pKVM | NÃO (lake sem pKVM ativo) | NÃO |
| 8 | net-extra (skb/GRO) | GRO fraglist-null KE, skb use-after-free | SIM (rede) | ARRISCADO se portar (skb structs) |
| 8 | kbuild/config | **inclui `c02444777107 [ALPS08687112] ANDROID: gki_defconfig: disable CONFIG_MODULE_SIG_PROTECT`** | SIM — prova que árvore MTK desliga SIG_PROTECT e o stock lake (PROTECT=y) NÃO veio dela | NÃO (só config) |
| 6 | net/wireless | wifi/bt/mac80211 | SIM (lake usa wlan vendor) | ARRISCADO se portar |
| 5 | drivers-misc | soc/clk/phy/i2c/misc | PARCIAL | caso a caso |
| 4 | dma-buf/heap | `dma_buf_get_each`, mtk_heap_debug (+1 revert do par) | SIM (dmabuf é KMI sensível) | **PROIBIDO portar sem re-gate** |
| 4 | iommu/iova | iova debug log | PARCIAL | NÃO (debug) |
| 3 | usb/typec | revert USB-not-work (Jeremy Chou) + outros | SIM (USB) | ARRISCADO se portar |
| 3 | drm/display/gpu | display/gpu | NÃO (display é vendor/lk) | NÃO |
| 2 | sound/audio | usb offload callback (Jason Liu) +1 | PARCIAL | caso a caso |
| 2 | thermal/power | thermal/power | SIM (mesma família) | caso a caso |
| 2 | tracing/debug | overflow get_free_elt (Tze-nan Wu) +1 | NÃO | NÃO |
| 1 | arm64/arch/dt | arch/arm64 | NÃO (1 commit) | caso a caso |
| 1 | binder/ipc | binder | SIM (binder é GKI; ver se já no r12) | **PROIBIDO sem gate** |
| 1 | kbuild/device_modules | `support builtin drivers from device_modules` (Miles Chen) | SIM (modelo de build MTK) | NÃO (build, não CRC) |
| 23 | outros-resto | cgroup, timer genérico, correções diversas sem keyword | a triar | caso a caso |
| **183** | **total** | | | |

- Detalhe do diff de arquivos (`MEASURED`, `files` do compare): **truncado em 300** (`files_in_payload: 300`): 207 `arch/` + 61 `Documentation/` + 27 `android/` + base. Lista completa sem clone parcial é impossível pela API (limite 300, sem paginação) — diferença explicada, não "falta".
- Por autor/org (`INFERRED`): ~tudo MTK ALPS (113 ALPS-tagged + syncs de clive.lin); Xiaomi = só o marker vazio. `UNVERIFIED`: vínculo empregatício individual (nomes @mtk vs @xiaomi não checados um a um).

## 2. Head commit + `dew_defconfig` + DTS do dew

- Head (`MEASURED` §0): commit vazio, só metadados (TAG MTK + nome da config). `git diff --stat` via clone parcial: **dispensado** — a API já prova `stats.total 0`; clone (~GB) não se justifica com 51 GB livres.
- `dew_defconfig` (`MEASURED`): **NÃO existe** em `dew-v-oss:arch/arm64/configs/` (lista API: `amlogic_gki.fragment, crashdump_defconfig, db845c_gki.fragment, defconfig, fips140_gki.fragment, gki_defconfig, microdroid_defconfig, rockpi4_gki.fragment, virt.config` — sem `dew_defconfig`). Conclusão: a config citada no marker vive fora do kernel (no repo do sergio: `configs/dew_current.config`, 211483 B — ver §4; comparar com stock é tarefa do dono do dew, fora do nosso escopo lake).
- DTS/DTBO do dew (`MEASURED`): `arch/arm64/boot/dts/mediatek/` tem 105 entradas e **0** com `dew/6769/6768/6765` — DT do dew não está no kernel (vive em `vendor_boot/dtb`, como no lake). Outras tentativas: `git ls-remote --heads` filtrado (`lake/dew/delos/pond/mt6768/mt6769/mt6765/emerald/fleur/light/selen` → só `dew-v-oss`, `emerald_r-u-oss`, `fleur-s-oss`, `light-u-oss`, `selene-r-oss`, `bsp-aristotle-s-oss`; **nenhum `lake-*`**); `MiCode/kernel_devicetree` (só tem `README.md` — sem dew/lake); code search GitHub `dew_defconfig org:MiCode` → **401 Requires authentication** (`LOCKED`, sem token). Comparação dew_defconfig×stock×gki_defconfig: **não executável** sem a defconfig (motivo exato acima).

## 3. Outros branches MiCode da família MT6768/MT6769/MT6765 (Android 15/16, kernel 6.6?)

`MEASURED` (`git ls-remote --heads`, 266 branches + head-commit via API):

| branch | aparelho (msg do head) | data head | Android | família? | serve p/ lake? |
|---|---|---|---|---|---|
| `dew-v-oss` | REDMI 15C/POCO C85 | 2025-09-19 | V (15) | SIM (MT6769) | irmão, não lake |
| `emerald_r-u-oss` | Redmi Note 14S | 2025-04-03 | U (14) | SIM provável (MT6769/G99) | NÃO (Android velho) |
| `fleur-s-oss` | Redmi Note 11S | 2023-08-21 | S (12) | SIM provável (MT6769/G96) | NÃO (velho) |
| `light-u-oss` | POCO M4 5G/Redmi 10 5G/11 Prime 5G/Note 11E | 2026-06-02 | U (14) | NÃO (Dimensity 700/MT6833) | NÃO |
| `selene-r-oss` | Redmi 10 Prime | 2021-11-16 | R (11) | NÃO (MT6762) | NÃO |
| `bsp-aristotle-s-oss` | Xiaomi 13T | 2023-10-20 | T (13) | NÃO (Dimensity 8200) | NÃO |

Sufixo `-v/-u/-s/-r/-t` = Android 15/14/12/11/13 (`FACT`, convenção de release Xiaomi). **Nenhum branch `lake-*` existe; nenhum da família com Android 15/16 + 6.6 além do `dew-v-oss`.** Kernel-version por branch não verificado sem clone (`UNVERIFIED`, não necessário: Android já desqualifica).

## 4. sergiofalconp24-hub/dew-kernel como REFERÊNCIA DE PROCESSO (só texto lido)

`FACT` (API repo: `default_branch build-inicial`, 14294 KB, sem licença, 0 stars, criado 2026-09-20; README+GUIA+4 `ci/*.sh`+workflow+2 `flash/*.sh` lidos via raw; `boot.img` 67 MB e `dew_tmp.c` NÃO baixados):

- Pipeline (`.github/workflows/build-kernel.yml`, 4776 B + `ci/`, `flash/`, `configs/`): dispatch (ksu si/no, perfil equilibrado/bateria/rendimiento, release opcional) ou push `build-*` → checkout `MiCode/...:dew-v-oss` em `kernel/` → cache ccache+clang → `get_clang.sh` (r510928 via Gitiles TEXT+base64, fallback branch `$CLANG_VER`, fallback proton) → `apply_ksu.sh` (clone tiann/KernelSU@main, symlink `drivers/kernelsu`, `CONFIG_KSU=y` in-tree) → `apply_customization.sh` (patches `ci/patches/*.patch` se aplicam limpo, senão warning e segue base) → copia `configs/dew_current.config`→`.config` → `make LLVM=1 ... Image.gz modules` (clang+aarch64-linux-gnu CROSS+LLVM_IAS+ccache 10G) → `package_boot.sh` (header stock + `Image.gz` novo + footer AVB stock) → artifact `out/` (+ release draft opcional).
- Repack (`package_boot.sh`, 1839 B, python3 embutido): exige magic `ANDROID!` + `AVBf`; preserva header 0x1000 (só `kernel_size@8`), zona kernel até `avb-0x1000`, footer do stock; saída 64 MiB. Flash (`flash-boot.sh` 819 B / `restore-stock.sh` 507 B): só `boot_<slot-ativo>`, resto proibido; restore reflashea stock.
- ERROS/RISCOS concretos (para o nosso fluxo): (1) `KSU_BRANCH=main` flutuante = build não reproduzível (nós pinamos `fa8311f6`/tag — ver CODEX2); (2) `apply_customization.sh` com `patch --dry-run || warning` **segue base em silêncio** se patch não aplica (nós exigimos FAIL/gate); (3) `make -j$(nproc)` + ccache 10G sem `--jobs` cap = OOM em host pequeno; (4) afirmação `header v4 no-estándar (campos reordenados)` **sem prova** (nossos `unpack_bootimg` no lake mostram v4 padrão; o dew pode diferir, mas o repo não anexa dump/offset); (5) `Image.gz → Image ... magic 0x4d5a40fa` é **suspeito** (`0x4D5A` = MZ/DOS; magic ARM64 Image é `0x644D5241` "ARM\x64" no offset 0x38 — provável leitura errada do offset); (6) lacuna codename: README/GUIA dizem `dew = Redmi 14C/POCO C75` mas o marker Xiaomi diz `REDMI 15C/POCO C85` — **contradição não resolvida** (nosso plano: lake = POCO C75/Redmi 14C; tratar qualquer `dew≈lake` como `UNVERIFIED`); (7) `fastboot boot` recomendado sem evidência de suporte no dew (nosso plano Q3 mantém UNKNOWN); (8) sem licença + 2 commits + 0 stars = sem revisão externa.
- Ideias úteis: matriz dispatch (ksu/perfil/release), cache de toolchain+ccache no CI, `dew_current.config` versionada (211483 B ≈ nosso stock), `package_boot.sh` como referência de repack com footer preservado, regra "só boot_<slot>" + restore-stock espelhando nosso F5/F6.

## 5. UTIL p/ LAKE (1 linha)

Irmão MTK como espelho de processo e de delta MTK-vs-GKI (inclusive SIG_PROTECT desligado na MTK), nunca como fonte de código: lake usa GKI puro + vendor fechado, e o dew não tem defconfig/DTS no kernel.

---
### Auto-revisão
- Rebaixado: vínculo individual MTK/Xiaomi por autor (`UNVERIFIED`); kernel-version dos branches antigos (`UNVERIFIED`); qualquer equivalência `dew≈lake` (`UNVERIFIED`, contradição §4).
- Não achado (tentativas registradas): `dew_defconfig` na árvore (lista `arch/arm64/configs` via API); DTS dew em `dts/mediatek` (105 entradas, 0 match); `lake-*` em 266 branches; `dew` em `MiCode/kernel_devicetree` (só README); code search org MiCode (401 sem token); `files` completos do compare (API trunca em 300, sem paginação).
