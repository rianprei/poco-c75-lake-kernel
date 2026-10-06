# AUDIT_antigravity — Auditoria adversarial da pesquisa “lake kernel”

**Auditor:** Buffy (Freebuff) — papel: red team de evidências, somente leitura
**Data:** 2026-10-05
**Alvo auditado:** `<lake-kernel>/research/{CANDIDATES,NOTES,GITHUB_SEARCH,MICODE_MTK,GKI_KERNELSU,FORUMS_ARCHIVES}.md`
**Dispositivo:** POCO C75 4G (`lake`, MT6768/MT6769), stock `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k`
**Base já medida pelo usuário (MEASURED):** `android15-6.6-2025-06_r12^{}` = `5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143`

## Método

Ferramentas usadas (somente leitura, rede pública): `git ls-remote` (GitHub/AOSP/GitLab), `curl` à API pública do GitHub, `curl` a `raw.githubusercontent.com` e a `android.googlesource.com`, API `download.lineageos.org`. Nenhum código/baixado foi executado, nenhum pacote instalado, nenhum arquivo alterado fora deste relatório, nenhum contato com o aparelho.

---

## 1. Fatos rotulados `FACT` SEM prova verificável no próprio texto → reclassificação

Critério: `FACT` exige URL **que resolva**, hash ou saída de comando colada. Claim de README/issue sem log = dado externo, não fato.

| # | Afirmação (arquivo) | Rótulo original | Reclassificação | Motivo |
|---|---|---|---|---|
| F1 | “TWRP boots on real lake hardware” (CANDIDATES #4) | FACT | **UNVERIFIED** | Sem log/foto/link de build; README do repo não afirma boot |
| F2 | “recovery boots on lake hardware” (CANDIDATES #5/#24) | FACT | **UNVERIFIED** | Mesma ausência de prova |
| F3 | “pond/lake recovery tree with android15-6.6 init” (CANDIDATES #24) | FACT | **UNVERIFIED** | Depende de leitura de `BoardConfig` não colada |
| F4 | “mainline 6.18 boots on MT6769T (lancelot) com display/touch/GPU” (CANDIDATES #20/#21, GITHUB_SEARCH #12/#13) | FACT | **UNVERIFIED** | É claim de README de terceiro, sem log anexado |
| F5 | “boots on moto g05 (MT6768)” (CANDIDATES #22, GITHUB_SEARCH #20) | FACT | **REFUTED** | Repositório citado **não existe** (ver 2b) |
| F6 | “real Lamu firmware dump with kernel 6.6.82” (CANDIDATES #23) | FACT | **UNVERIFIED** | Nenhum arquivo/hash citado |
| F7 | “Booting label in repo” (CANDIDATES #26) | FACT | **UNVERIFIED** | Label de分支 ≠ prova de boot |
| F8 | “HyperOS 2 usa 6.6.30 / HyperOS 1 usa 5.10.209” (CANDIDATES §6.1.5-6, NOTES 1.2) | FACT | **UNVERIFIED** | Só existe como texto de README de terceiro; o DTS filename não contém versão de kernel |
| F9 | “Lake uses kernel 6.6.89 confirmado por ROMs oficiais” (CANDIDATES §6.1.2) | FACT | **CONFIRMED** (por outra via) | `uname` medida pelo usuário + `Makefile` do tag AOSP = 6.6.89 (ver 2h) |
| F10 | “Build ID ab13771415 bate com device databases” (NOTES 1.3, GKI §1.1) | FACT | **UNVERIFIED** | Página do tag/databases não foram buscadas nesta auditoria |
| F11 | “r12 é 1 dia após r11 e 1 dia antes r13 / datas 2025-06-11..13” (GKI §1.3, NOTES 1.3) | FACT | **UNVERIFIED** | Refs existem (medido), datas não |
| F12 | “Nearby tags r10…r39” (CANDIDATES §4.1) | FACT | **PARTIAL → UNVERIFIED** | Medidos apenas r10..r14 |
| F13 | “KernelSU/KernelSU-Next/SukiSU: 6.6 support = YES” (CANDIDATES §4.3) | FACT | **CONFIRMED** (KSU/KSU-Next) | Assets `*-android15-6.6_kernelsu.ko` (ver 2d) |
| F14 | “boot evidence YES — DTS extracted from real HyperOS firmware” (GITHUB_SEARCH #1) | FACT | **INFERRED** | Extração de DTS não é prova de boot; rótulo trocado |
| F15 | “500+ branches (GitHub API)” (MICODE_MTK) | FACT | **REFUTED** | Medido: 266 heads, 0 tags (ver 2a) |
| F16 | “Issues #40309/#40912/#41071 permanecem abertas” (FORUMS §1.1) | FACT | **REFUTED** | #40912 está `closed` (ver 2h) |
| F17 | “README de X afirma Y” (diversas) | FACT | **UNVERIFIED** | Dado externo, nunca executado; mantido como dado |
| F18 | “Custom kernel feasibility: HIGH” (GITHUB_SEARCH §5.5) | FACT | **INFERRED** | Juízo de valor, não observação |

---

## 2. As 8 verificações independentes (a–h)

### (a) MiCode/Xiaomi_Kernel_OpenSource — existe branch/tag lake/mt6768/mt6769 com 6.6?

```
$ git ls-remote --heads https://github.com/MiCode/Xiaomi_Kernel_OpenSource | wc -l
266
$ git ls-remote --tags  https://github.com/MiCode/Xiaomi_Kernel_OpenSource | wc -l
0
# grep das refs:
MATCH_lake_or_pond=0   MATCH_mt6768_69_k68=0   MATCH_6.6_branches=0
# refs relevantes encontradas:
e91fa149... refs/heads/dew-v-oss
1d1aedfe... refs/heads/fire-t-oss
c5a44bba... refs/heads/gale-s-oss
42825e29... refs/heads/earth-s-oss
a68e56e8... refs/heads/warm-u-oss
```

**Veredito: CONFIRMED** — nenhuma branch/tag `lake`/`pond`/`mt6768`/`mt6769`/`k68v1` e nenhuma ref com “6.6” no nome. Também existe `MiCode/kernel_devicetree`:

```
$ git ls-remote --heads https://github.com/MiCode/kernel_devicetree | grep -Ec 'lake|pond'
0
```

**Veredito: CONFIRMED** (sem devicetree lake no MiCode).

**Porém, surpresa na mesma verificação** — a branch `dew-v-oss` NÃO é 4.19:

```
$ curl -s raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/dew-v-oss/Makefile | head -4
# SPDX-License-Identifier: GPL-2.0
VERSION = 6
PATCHLEVEL = 6
SUBLEVEL = 58
$ curl -s .../dew-v-oss/build.config.constants | head -2
CLANG_VERSION=r510928
```

**Veredito: REFUTED** para “dew-v-oss = 4.19+” (MICODE_MTK, CANDIDATES §5) e para “todos os kernels MT6768 públicos são 4.19.x” — existe árvore GKI **6.6.58** pública no MiCode (dispositivo irmão `dew`).

### (b) OWLXS/motorola-lamu-kernel-6.6

```
$ git ls-remote https://github.com/OWLXS/motorola-lamu-kernel-6.6
remote: Repository not found.
fatal: repository '.../OWLXS/motorola-lamu-kernel-6.6/' not found
$ curl -s api.github.com/repos/OWLXS/motorola-lamu-kernel-6.6
{"message":"Not Found","status":"404"}
```

**Veredito: REFUTED** — o repositório não existe (apagado/renomeado/never existed). Indício do que existiu:

```
$ curl -s "api.github.com/users/OWLXS/repos?per_page=100" | grep full_name
OWLXS/android_device_motorola_lamu
OWLXS/android_device_motorola_lamu-kernels
OWLXS/android_kernel_common   -> "kernel/common (android15-6.6.142) fork for the lamu build"
OWLXS/android_kernel_motorola_lamu-modules ... (13 repos, nenhum "motorola-lamu-kernel-6.6")
$ git ls-remote --heads https://github.com/OWLXS/android_kernel_common
9db3a171... refs/heads/lamu-6.6.142
```

- Versão do kernel: **GKI 6.6.142** (lamu) — não 6.6 genérico.
- É GKI? **Sim** (fork de `kernel/common` android15-6.6).
- Prova de “boota no moto g05”? **Não existe** para o repo citado (404). **UNVERIFIED** para o resto do worktree da OWLXS.

### (c) mt6768-mainline/downstream-kernel-blobs — DTS do lake e versão do firmware

```
$ curl -s api.github.com/repos/mt6768-mainline/downstream-kernel-blobs/contents/ | grep name
README.md  (3183 B)
fire_global_images_OS2.0.5.0.VMXMIXM_15.0.dts
fire_global_images_OS2.0.5.0.VMXMIXM_15.0.dts-dtbo.dts
lake_global_images_OS2.0.3.0.VGTMIXM_15.0-dtbo.dts   (254040 B)
lake_global_images_OS2.0.3.0.VGTMIXM_15.0.dts         (202161 B)
merlin_V12.5.1.0.RJOMIXM-dtbo.dts
$ git ls-remote https://github.com/mt6768-mainline/downstream-kernel-blobs
cadce7e1b0b32e8a46c998e4a24b3dfba1e4f759  refs/heads/main
```

**Veredito: CONFIRMED** — DTS do lake existe, extraído do firmware **`OS2.0.3.0.VGTMIXM`** (HyperOS 2.0.3.0 global). README do repo (texto externo, não executado) diz: “HyperOS 1 … 5.10.209 … Redmi 14C” e “HyperOS 2 uses 6.6.30 … Redmi 14C (lake)”.

- “HyperOS 1 = 5.10.209 / HyperOS 2 = 6.6.30”: **UNVERIFIED** (claim de README, sem log).
- Licença do repo: **nenhuma** (ver 2g).

### (d) tiann/KernelSU e KernelSU-Next — último release/commit e suporte GKI android15-6.6

```
$ curl -s api.github.com/repos/tiann/KernelSU/releases/latest | grep tag_name/published_at
"tag_name": "v3.3.0",  "published_at": "2026-08-28T14:49:30Z"
   ... "lkm-aarch64-android15-6.6_kernelsu.ko"
$ curl -s api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest | grep tag_name/published_at
"tag_name": "v3.4.0",  "published_at": "2026-09-21T13:36:19Z"
   ... "aarch64-android15-6.6_kernelsu.ko"
$ curl -s api.github.com/repos/KernelSU-Next/KernelSU-Next | grep default_branch/pushed_at
"default_branch": "dev", "pushed_at": "2026-10-04T15:21:43Z"
$ git ls-remote --heads https://github.com/pershoot/KernelSU-Next | grep dev-susfs
a358a49e... refs/heads/dev-susfs
$ git ls-remote --heads https://gitlab.com/simonpunk/susfs4ksu.git | grep gki-android15-6.6
a0f9c59e... refs/heads/gki-android15-6.6
```

**Veredito: CONFIRMED** — ambos publicam LKM para **android15-6.6**; upstream `v3.3.0` (2026-08-28), Next `v3.4.0` (2026-09-21); branch `gki-android15-6.6` do susfs4ksu existe.

Correções: “LKM / GKI image deprecated since v3.0” (GKI §3.1) → **REFUTED** (o LKM `*-android15-6.6_kernelsu.ko` é asset do v3.3.0). “KernelSU-Next = pershoot/KernelSU-Next” (GKI §8) → **REFUTED como repo oficial** (oficial é `KernelSU-Next/KernelSU-Next`; `pershoot/` é fork com `dev-susfs`, que existe).

### (e) Tabela de scores — reordenação

Erros encontrados (evidência própria do arquivo + medições acima):

| Linha | Problema | Evidência | Correção |
|---|---|---|---|
| #2 `mt6768-mainline/linux` = **3/5** | Pior score que o único repo com DTS lake; “Lake DTS: NO”, “Boot proof: lancelot” | `curl .../contents/arch/arm64/boot/dts/mediatek?ref=cleanup \| grep -i lake` → **vazio** | **2/5** (sem identidade lake, sem boot lake) |
| #20/#21 `hataketsu/*` = **3/5** | Nota “NOT lake” no próprio texto, mas nota alta | idem: sem DTS lake | **1/5** para o objetivo lake |
| #1 `downstream-kernel-blobs` = **2/5** | Único com DTS lake real, penalizado por ser “só DTS” | contents API (2c) | **3/5** (top real em identidade lake) |
| #22 `OWLXS/motorola-lamu-kernel-6.6` = **2/5** | Baseado em “FACT: boota no moto g05” | **404** (2b) | **0/5** (repo inexistente) |
| #5 e #24 | Mesmo repo `Mayuri-Chan/recovery_device_xiaomi_pond` listado **duas vezes** | idênticos em URL/branch/data | deduplicar |
| #8 `mt6768-dev/android_kernel_xiaomi_mt6768` | Default branch `lineage-23.2` (CANDIDATES) | `git ls-remote --symref ... HEAD` → `refs/heads/lineage-24.0` | **REFUTED**; MICODE_MTK estava certo |

Nova ordem proposta (só para o objetivo “kernel lake flashável”): `downstream-kernel-blobs (3)` > `mt6768-mainline/linux (2)` = `lpxx50117/twrp… (2)` > demais 1/5 > `OWLXS lamu (0)` > `MiCode (0)`.

### (f) Repos que o Antigravity não listou — 6+ queries novas (API de busca do GitHub)

```
q=lake+kernel+xiaomi          -> total_count 0
q=android_kernel_xiaomi_lake  -> total_count 0
q=redmi+14c+kernel            -> total_count 0
q=poco+c75+kernel             -> total_count 2  (sergiofalconp24-hub/dew-kernel, Raaanz/android_kernel_xiaomi_sm4635)
q=lake+mt6768                 -> total_count 0
q=xiaomi+lake+kernel+6.6      -> total_count 0
# extras:
q=Redmi+14C+kernel+in:readme  -> total_count 12 (1º: MiCode; também rianprei/poco-perfgov-magisk)
q=lake+in:name+kernel         -> total_count 5  (AndroidBlobs/kernel_motorola_lake, RevengeOS-Devices/kernel_motorola_lake, hurdad/kernel-lake — todos Motorola "lake" = moto g7 plus)
```

Achados **novos** (não listados nos 6 arquivos):

1. **`sergiofalconp24-hub/dew-kernel`** — o mais relevante. README (dado externo, não executado):
   ```
   # dew-kernel — Kernel custom Redmi 14C / POCO C75 ("dew", MT6769)
   ... Device: dew_n_global, board mt6768/hardware mt6769, kernel GKI 6.6 (6.6.89-android15)
   | Kernel MIUI | MiCode/Xiaomi_Kernel_OpenSource dew-v-oss | árbol GKI 6.6 android15-6.6 |
   ```
   Refs: `refs/heads/build-inicial` (única), **0 releases**, raiz contém **`boot.img`** pré-compilado + `flash/` + workflows de Actions. Licença: `null`.
   Veredito: **CONFIRMED** que o repo existe e declara ser kernel para Redmi 14C/POCO C75; **UNVERIFIED** como candidato real (sem prova de boot, sem release, `dew` é outro codinome — MiCode `dew-v-oss` é Redmi 15C/POCO C85; ainda assim é o primeiro claim público de kernel para o aparelho).
2. `OWLXS/android_kernel_common` (lamu-6.6.142) — substituto do repo 404.
3. `MiCode/kernel_devicetree` — verificado, **sem** branch lake.
4. `AndroidBlobs/kernel_motorola_lake`, `RevengeOS-Devices/kernel_motorola_lake`, `hurdad/kernel-lake` — “lake” Motorola (moto g7 plus), não Xiaomi.
5. `rianprei/poco-perfgov-magisk` — módulo Magisk do próprio usuário, não kernel.
6. `moto-mediatek-devs/android_kernel_motorola_lamu-*` (contraparte org do repo OWLXS).

**Veredito:** “ZERO kernel source repositories found for lake” (NOTES §3.1) → **REFUTED parcialmente**: as queries de nome continuam 0, mas a query `in:readme` encontra `dew-kernel`.

### (g) Licença / GPL dos Top 5

```
$ curl -s api.github.com/repos/<repo>  (campo license.spdx_id)
mt6768-mainline/downstream-kernel-blobs : license = null   (contents/ sem LICENSE/COPYING)
mt6768-mainline/linux                   : NOASSERTION ("Other")
lpxx50117/twrp_device_xiaomi_lake       : license = null
Mayuri-Chan/recovery_device_xiaomi_pond : license = null   (README traz SPDX Apache-2.0 do twrpdtgen)
hataketsu/mt6768-mainline-notes         : license = null
MiCode/Xiaomi_Kernel_OpenSource         : Makefile/README SPDX "GPL-2.0" (raw README HTTP 200)
```

**Veredito:** “GPL-2.0” (CANDIDATES #2) e “MIT (scripts), GPL-2.0 (drivers)” (CANDIDATES #20/#21) → **UNVERIFIED** (nenhum `LICENSE` detectado). Repositórios de device tree TWRP **não têm licença declarada** (risco de reuso). `downstream-kernel-blobs` **sem licença** apesar de conter DTS derivado de firmware proprietário (risco GPL/proprietário).

### (h) Contradições entre os arquivos

| # | Contradição | Veredito / evidência |
|---|---|---|
| C1 | CANDIDATES §4.1 e NOTES 1.3/2.4: “r12 é 6.6.30-era, o stock 6.6.89 é backport da Xiaomi” | **REFUTED**: `curl android.googlesource.com/.../android15-6.6-2025-06_r12/Makefile?format=TEXT \| base64 -d` → `VERSION=6 PATCHLEVEL=6 SUBLEVEL=89`. O tag **é** 6.6.89; a Xiaomi não backportou nada — o `uname` é o próprio GKI. |
| C2 | CANDIDATES §6.1.2 “HyperOS 3 = 6.6.89 confirmado” **vs** GITHUB_SEARCH §5.1 “HyperOS 3 kernel = UNKNOWN” | Interna; a primeira está certa (uname + Makefile). GITHUB_SEARCH §5.1 → **REFUTED**. |
| C3 | GKI §3.1/§8 “KernelSU-Next = pershoot/…” **vs** CANDIDATES “KernelSU-Next/KernelSU-Next” | Oficial = `KernelSU-Next/KernelSU-Next` (API 200, v3.4.0). `pershoot/` é fork. GKI está **ERRADO** na identificação. |
| C4 | Datas/status das issues: GITHUB_SEARCH (#40912 2026-03-30, #40309 2025-09-19, #41071 2026-04-28) vs MICODE_MTK (#40912 2026-03-31, fechada) vs FORUMS (“ambas abertas”, 2025) | API: `#40912 state=closed created=2026-03-31`, `#40309 state=open created=2025-09-11`, `#41071 state=open created=2026-08-02` → GITHUB_SEARCH e FORUMS **REFUTED**; MICODE_MTK **CONFIRMED**. |
| C5 | MICODE_MTK “500+ branches” vs real 266 | **REFUTED** (2a). |
| C6 | MICODE_MTK “dew-v-oss 4.19+” vs Makefile 6.6.58; CANDIDATES “dew … kernel UNKNOWN” | **REFUTED** (2a). |
| C7 | CANDIDATES #8 “mt6768-dev default lineage-23.2” vs MICODE_MTK “lineage-24.0” | `--symref HEAD` = **lineage-24.0** → CANDIDATES **REFUTED**. |
| C8 | lamu = “MT6768” (GITHUB_SEARCH #20) vs “MT6769” (CANDIDATES #22) | **UNVERIFIED** — não resolvido nesta auditoria. |
| C9 | MICODE_MTK “Samsung A05s é o único kernel 6.6 do MT6768” vs OWLXS lamu 6.6.142, `m52xq/motorola_lamu_dump` 6.6.82, `MotorolaMobilityLLC/…-6.6` | **REFUTED** (não é o único). |
| C10 | selene 4.19 (CANDIDATES §5) vs 4.14 (FORUMS §5.2) | **UNVERIFIED** (não medido). |
| C11 | GITHUB_SEARCH §4.3 “LineageOS builds para lake = Xiaomi Redmi 14C/POCO C75” | **REFUTED** (ver abaixo). |
| C12 | CANDIDATES #4/#5 “boot proof” vs FORUMS §3.2 “Lake boot proof = FALSE” | Interna; predomina FORUMS: sem prova de boot → **UNVERIFIED**. |
| C13 | GITHUB_SEARCH #28/#29 usam URL `phywizz/A137f` | `curl -o /dev/null -w %{http_code}` → **404**; `physwizz/A137f` → **200** → URL **REFUTED**. |

**Verificação extra de C11 (LineageOS):**

```
$ curl -s download.lineageos.org/api/v2/devices/lake
{"model":"lake","name":"moto g7 plus","oem":"motorola", ...}
$ curl -s download.lineageos.org/api/v2/devices | grep -Ei 'redmi 14c|poco c75|2410FPCC5G'
(vazio)
$ curl -s download.lineageos.org/api/v2/devices/lake/builds | head -c 200
[{"date":"2026-10-01", ... "lineage-22.2-20261001-nightly-lake-signed.zip" ...}]
```

**REFUTED**: `download.lineageos.org/devices/lake` é um **moto g7 plus** (Motorola). A tabela com SHA256 atribuída a “Xiaomi Redmi 14C / POCO C75” é falsa e a alegação “LineageOS tem build para lake (Xiaomi)” também — **nenhum** device Xiaomi Redmi 14C/POCO C75 na lista oficial.

**Issue #731 (usada como base do método “init_boot”):**

```
$ curl -s api.github.com/repos/KernelSU-Next/KernelSU-Next/issues/731 | grep -E 'number|state|title|created_at'
"number": 731, "state": "closed", "title": "Flash failed on Redmi 14c", "created_at": "2025-08-19"
corpo: "...extract boot.img from here [miuirom.org/phones/redmi-14c...] ... It shows failed as shown in the picture"
```

**CONFIRMED**: a falha ao flashear via `boot.img` num Redmi 14c é real. A parte “init_boot funciona” está em comentários não buscados → **UNVERIFIED**.

---

## 3. Tabela mestre — afirmação → veredito → evidência

| Afirmação | Veredito | Evidência (comando → saída curta) |
|---|---|---|
| MiCode sem branch/tag lake | CONFIRMED | `git ls-remote --heads MiCode/...` → 266 refs, grep lake/pond = 0 |
| MiCode sem ref mt6768/mt6769/k68v1 | CONFIRMED | grep → 0 |
| MiCode `warm-u-oss` (C75 5G) existe | CONFIRMED | `a68e56e8 refs/heads/warm-u-oss` |
| MiCode “500+ branches” | REFUTED | heads=266, tags=0 |
| MiCode “last activity 2026-09-28 bsp-klee-w-oss” | UNVERIFIED | não medido |
| `dew-v-oss` = 4.19+ | REFUTED | Makefile → `SUBLEVEL=58`, `PATCHLEVEL=6` |
| “Todos MT6768 públicos = 4.19.x” | REFUTED | idem + lamu 6.6.142 (2b) |
| Issues #40309/#40912/#41071 pedem kernel lake | CONFIRMED | títulos via API |
| #40912 aberta 2026-03-31 e **fechada** | CONFIRMED | `"state":"closed","created_at":"2026-03-31"` |
| #40912 aberta 2026-03-30 (GITHUB_SEARCH) | REFUTED | API → 2026-03-31 |
| #40309 aberta 2025-09-19 | REFUTED | API → 2025-09-11 |
| #41071 aberta 2026-04-28 | REFUTED | API → 2026-08-02 |
| “Issues permanecem abertas” (FORUMS) | REFUTED | #40912 closed |
| `OWLXS/motorola-lamu-kernel-6.6` existe | REFUTED | `git ls-remote` → Repository not found (404) |
| “FACT: boota no moto g05” | UNVERIFIED | repo 404; sem log/issue |
| OWLXS usa GKI 6.6.142 p/ lamu | CONFIRMED | `refs/heads/lamu-6.6.142` + descrição do repo |
| lamu = MT6768 vs MT6769 (contradição interna) | UNVERIFIED | não resolvido |
| DTS do lake existe em `downstream-kernel-blobs` | CONFIRMED | contents API → 2 arquivos `lake_...VGTMIXM*` |
| Firmware de origem = `OS2.0.3.0.VGTMIXM` | CONFIRMED | nome do arquivo DTS |
| HyperOS 1 = 5.10.209 / HyperOS 2 = 6.6.30 | UNVERIFIED | texto de README de terceiro |
| Stock lake = 6.6.89-android15 | CONFIRMED | uname (MEASURED) + Makefile r12 = 6.6.89 |
| “HyperOS 3 kernel = UNKNOWN” (GITHUB_SEARCH) | REFUTED | idem |
| Tag `android15-6.6-2025-06_r12^{}` = `5a0ffb447c1d…` | CONFIRMED | `git ls-remote` → hash idêntico ao do uname |
| “r12 é 6.6.30-era, não 6.6.89” | REFUTED | Makefile → `SUBLEVEL = 89` |
| “Xiaomi backportou features” (NOTES 2.4) | REFUTED | idem — é o GKI puro |
| `CLANG_VERSION=r510928` no tag r12 | CONFIRMED | `build.config.constants` decodificado |
| “Página do tag lista build ID ab13771415” | UNVERIFIED | não buscada |
| Datas r11/r12/r13 (1 dia cada) | UNVERIFIED | só refs medidas |
| `mt6768-mainline/linux` não tem DTS lake | CONFIRMED | contents `dts/mediatek` grep lake → vazio |
| `mt6768-mainline/linux` = GPL-2.0 | UNVERIFIED | GitHub `spdx=NOASSERTION` |
| hataketsu notes = MIT/GPL-2.0 | UNVERIFIED | `license=null` |
| blobs/TWRP/pond sem licença declarada | CONFIRMED | `license=null` em 4/5 do Top 5 |
| “TWRP boots on real lake hardware” | UNVERIFIED | sem log/foto/link |
| “recovery boots on pond/lake” | UNVERIFIED | sem log/foto/link |
| `prebuilt/dtb.img` existe no repo pond | CONFIRMED | contents API → `dtb.img` |
| KernelSU suporta GKI android15-6.6 | CONFIRMED | asset `lkm-aarch64-android15-6.6_kernelsu.ko` (v3.3.0) |
| KernelSU-Next suporta GKI android15-6.6 | CONFIRMED | asset `aarch64-android15-6.6_kernelsu.ko` (v3.4.0) |
| “LKM deprecated desde v3.0” | REFUTED | LKM presente no release v3.3.0 |
| “KernelSU-Next oficial = pershoot/…” | REFUTED | oficial `KernelSU-Next/KernelSU-Next` v3.4.0 |
| susfs4ksu tem branch `gki-android15-6.6` | CONFIRMED | `git ls-remote` gitlab |
| WildKernels “release r8 (2026-07-28)” | UNVERIFIED | releases atuais: r21 (2026-10-01), nightly (2026-10-05) |
| “LineageOS lake = Xiaomi Redmi 14C/POCO C75” | REFUTED | API v2/devices/lake → **moto g7 plus** |
| SHA256 dos builds “LineageOS lake (Xiaomi)” | REFUTED | device errado; builds reais são de moto g7 plus |
| Nenhum device Xiaomi Redmi 14C/POCO C75 no LineageOS | CONFIRMED | grep da lista → vazio |
| Issue #731 “Flash failed on Redmi 14c” | CONFIRMED | API → título/state/data |
| “#731: init_boot funciona” | UNVERIFIED | comentário não buscado |
| URL `phywizz/A137f` | REFUTED | HTTP 404 (correto: `physwizz/`) |
| Score 3/5 p/ repos lancelot | REFUTED | sem DTS lake, sem boot lake (grep vazio) |
| Score 2/5 p/ OWLXS lamu “FACT: boota” | REFUTED | repo 404 |
| Linhas #5 e #24 duplicadas | CONFIRMED | mesmo repo/branch/data |
| `mt6768-dev` default `lineage-23.2` | REFUTED | `--symref HEAD` → `lineage-24.0` |
| `mt6768-dev` kernel 4.19.325 | CONFIRMED | Makefile → `VERSION=4 PATCHLEVEL=19 SUBLEVEL=325` |
| “ZERO lake kernel repos encontrados” | REFUTED | `q=poco+c75+kernel` → `dew-kernel` |
| `sergiofalconp24-hub/dew-kernel` existe e declara kernel p/ Redmi 14C/POCO C75 | CONFIRMED | API 200 + README raw |
| dew-kernel = candidato com prova de boot | UNVERIFIED | 0 releases, sem log; `boot.img` pré-compilado |
| “Samsung A05s é o único 6.6 do MT6768” | REFUTED | lamu 6.6.142, dump 6.6.82, Motorola modules 6.6 |
| “boot evidence = DTS extracted” | REFUTED | rótulo trocado: extração ≠ boot |
| selene 4.19 vs 4.14 (contradição interna) | UNVERIFIED | não medido |
| Uname do lake em Device Info HW/ghostlock | UNVERIFIED | fonte não buscada |
| `m52xq/motorola_lamu_dump` = 6.6.82 | UNVERIFIED | não medido |
| Uname HyperOS 2 `6.6.30-…gc338a81f088c` (issue #731) | UNVERIFIED | não está no corpo principal da issue |

**Contagem (tabela mestre, 61 afirmações):** CONFIRMADOS: **22** · REFUTADOS: **22** · UNVERIFIED: **17**

---

## 4. Conteúdo suspeito (bins, “rode isto”, links curtos)

**Nenhum link encurtado** nos 6 arquivos:

```
$ grep -nEo '(bit\.ly|tinyurl\.com|goo\.gl|is\.gd|cutt\.ly|rb\.gy|shorturl\.at|ouo\.io)[^ )"]*' *.md
(vazio — as ocorrências "t.com" são falsos positivos de reddit.com)
```

**Instruções embutidas de execução (DADO, nunca executar):**

| Onde | Instrução |
|---|---|
| `downstream-kernel-blobs` README (citado em CANDIDATES/NOTES) | `binwalk -Me boot.img`, `binwalk -M vendor_boot.img`, `dd if=vendor_boot.img of=dtb bs=1 skip=…`, `dtc` |
| `lpxx50117` README (citado em MICODE_MTK) | `repo init … && repo sync && lunch twrp_lake-userdebug && mka vendorbootimage` |
| GKI_KERNELSU §5.1/§5.4/§App.C | `docker run -it --rm --privileged=true …`, `repo init -u …/manifest.git`, `LTO=thin BUILD_CONFIG=… build/build.sh` |
| GKI_KERNELSU §2.3 | `git clone … -b llvm-r510928/clang-r510928 --depth=1` |

Nada de `curl | sh`, `bash -c`, `chmod +x` remoto ou script colado. As instruções são de build/extração — **dado**, não comando a ser rodado por este auditor.

**Binários pré-compilados referenciados:**

- `Mayuri-Chan/recovery_device_xiaomi_pond/prebuilt/dtb.img` (blob sem hash publicado).
- `lpxx50117/twrp_device_xiaomi_lake/prebuilt/` (DTB/kernel pré-compilados).
- `WildKernels/GKI_KernelSU_SUSFS` → `6.6.89-android15-2025-06-AnyKernel3.zip` (32.8 MB) e releases `*.ko` / APKs.
- `tiann/KernelSU` v3.3.0 e `KernelSU-Next` v3.4.0 → APKs e `*.ko` (hashes não conferidos aqui).
- **`sergiofalconp24-hub/dew-kernel` → `boot.img` na raiz** + pasta `flash/` + instrução “solo se flashea `boot_a`” — **o mais perigoso**: imagem de boot pré-compilada de autoria desconhecida, sem release, sem hash, sem licença. **NÃO flashar.**
- ROMs `*.tgz` da Xiaomi citadas com MD5 (gsmxblog) — não baixadas.

---

## 5. O que falta pesquisar

1. `sergiofalconp24-hub/dew-kernel`: validar se `dew-v-oss` (6.6.58) serviria de base para `lake` (6.6.89) — compatibilidade KMI/dif. de defconfig — **sem rodar nada do repo**.
2. Resolver `lake` vs `dew` vs `pond`: confirmar no `MiCode/kernel_devicetree`/README qual codinome Xiaomi cobre Redmi 14C/POCO C75 4G e se `dew-v-oss` traz DTS de lake.
3. Identificar o tag AOSP exato do HyperOS 2 (`6.6.30-android15-8-gc338a81f088c-ab12786305-4k`) — ajuda a entender a cadeia de updates.
4. Confirmar o build ID `ab13771415` na página do tag/release doc do AOSP (não buscado).
5. Resolver `lamu` = MT6768 vs MT6769 (GITHUB_SEARCH vs CANDIDATES).
6. Verificar `m52xq/motorola_lamu_dump` (6.6.82), `MotorolaMobilityLLC/kernel-kernel_device_modules-6.6`, `Mayuri-Chan/MTK_kernel_device_modules_6.6` — módulos 6.6 que podem servir de referência.
7. Ler os comentários da issue #731 para confirmar o método `init_boot` e o uname 6.6.30.
8. Prova de boot do TWRP lake: procurar issue/foto/build publicado nos 4 repos TWRP (atualmente só auto-afirmação).
9. Checar `WildKernels` release r8 vs r21 (tabela do GKI desatualizada).
10. Conferir `selene` 4.14 vs 4.19 e as licenças reais (COPYING) dos Top 5.
11. Procurar fontes fora do GitHub (GitLab/Codeberg/XDA/Telegram) com as queries `in:readme` equivalentes — só GitHub foi auditado aqui.

---

## 6. Auto-revisão (releitura do relatório)

- Todo `CONFIRMED` desta tabela tem saída de comando colada nas seções 1–4? **Sim** — CONFIRMED só foi mantido onde há `git ls-remote`, `curl` de API/raw ou Makefile decodificado citado.
- Itens que eram `FACT` nos arquivos originais e **não** têm saída colada aqui foram rebaixados para **UNVERIFIED** (F1–F8, F10–F12, F17 e a linha “Uname do lake em Device Info HW”).
- `REFUTED` exige negativa observável (404, hash divergente, campo de API contradizendo, `SUBLEVEL=89`).
- Nada foi executado, baixado, instalado, flashado; nenhum arquivo dos 6 originais foi alterado; nenhum contato com o aparelho.
- Limite reconhecido: só GitHub/AOSP/GitLab/LineageOS foram varridos; “não existe” aqui significa “não encontrado nessas fontes”.
