# CODEX3_config_safety — Q4 config stock vs gki_defconfig + Q12 segurança de CRC/ABI (r12 / 6.6.89)

> Data: 2026-10-05. Somente leitura em audit/ e official-*. Nenhum pacote instalado, nada executado de terceiros, sem adb/flash. Tabela completa (28 linhas, fonte por linha) em `research/config_safety_table.csv`.
> Legenda: `FACT` (URL lida) / `MEASURED` (saída local) / `INFERRED` / `UNVERIFIED` / `UNKNOWN`.

## 1. Q4 — config.stock vs gki_defconfig do r12: diferença exata (tabela + método)

### 1.1 Fontes — MEASURED

- `MEASURED` (curl `?format=TEXT` + base64 -d, sem login): `arch/arm64/configs/gki_defconfig` do tag `android15-6.6-2025-06_r12` = 20146 B / 787 linhas (`/tmp/opencode/r12/gki_defconfig`); `build.config.gki.aarch64` (482 B: inclui common+aarch64+gki, `DEFCONFIG=gki_defconfig` via build.config.gki de 62 B, `POST_DEFCONFIG_CMDS=check_defconfig`); `build.config.common` (682 B: `KMI_GENERATION=8`, `CLANG_VERSION` via constants `r510928`); `BUILD.bazel` (79693 B).
- `MEASURED` (locais): `audit/config.stock` 7744 linhas/~207K; `audit/ikconfig.from_image` idêntico (`diff` = 0 linhas); `.config` oficial do filegroup (`kernel_aarch64_filegroup_decl.tar.gz` → `.../kernel_aarch64_config/out_dir/.config`, 211483 B) vs `audit/config.stock` (`sort` + `diff`) = **0 linhas**.
- `MEASURED` (BUILD.bazel r12, linhas 111-159): `kernel_aarch64` usa `kmi_symbol_list android/abi_gki_aarch64` + 32 `additional_kmi_symbol_lists` (mtk, xiaomi, xiaomi2, ...) + `trim_nonlisted_kmi True` + `strict_mode True` + `protected_exports_list`; base `kernel_aarch64` **sem** `defconfig_fragments` (só variantes autofdo/microdroid têm). Ou seja, config efetiva = `gki_defconfig` + defaults do Kconfig + forças do Kleaf (TRIM/strict/protected), sem fragmento extra. `FACT` (https://android.googlesource.com/kernel/build/+/refs/heads/main-kernel-build-2024/kleaf/common_kernels.bzl, linhas 88-204: trim liga quando há kmi list; `--notrim` desliga).

### 1.2 Comparação normalizada — MEASURED (script python: `CONFIG_x=y` vs `# CONFIG_x is not set`→n)

- `MEASURED`: defconfig 787 entradas; stock 6173 entradas; **mismatches defconfig→stock: 0** (toda entrada do defconfig existe no stock com valor idêntico, incluindo `LOCALVERSION="-4k"`, `KPROBES=y`, `SHADOW_CALL_STACK=y`, `CFI_CLANG=y`, `MODVERSIONS=y`, `MODULE_SIG=y`, `MODULE_SIG_PROTECT=y`, `TRIM_UNUSED_KSYMS=y`).
- Tabela das diferenças (direção dupla):

| direção | n | conteúdo |
|---|---|---|
| defconfig=y/n mas stock diverge/ausente | **0** | nenhuma divergência normalizada |
| stock tem, defconfig não tem | **~5386** | expansão do Kconfig: defaults de arch/arm64, drivers, net, fs + detecções do toolchain (`CC_IS_CLANG`, `CLANG_VERSION=180000`, `PAHOLE_VERSION=125`, `GCC_VERSION=0` etc.); exemplo cabeçalho stock `CONFIG_CC_VERSION_TEXT="Android (... r510928) clang 18.0.0 ..."` |
| KMI-relevantes conferidas 1-a-1 | 13/13 iguais | `CFI_CLANG`, `SHADOW_CALL_STACK`, `LTO_NONE`, `MODVERSIONS`, `MODULE_SIG`, `MODULE_SIG_FORCE=n`, `MODULE_SIG_PROTECT`, `MODULE_SIG_ALL`, `TRIM_UNUSED_KSYMS`, `KPROBES`, `LOCALVERSION="-4k"`, `SYSTEM_TRUSTED_KEYS=""`, `ARM64_4K_PAGES` |

- Método e limite (`INFERRED`, honesto): sem `make` não se expande defconfig→.config de forma bit-fiel (Kconfig resolve `select`/`depends`/`default` por toolchain/host). O que o diff textual prova: (a) nenhuma opção do defconfig foi contrariada no stock; (b) o stock contém todo o defconfig; (c) as 13 configs que decidem ABI/KMI estão idênticas, inclusive contra o `.config` oficial do CI (diff 0). O que NÃO prova: que um `make gki_defconfig` local gera exatamente o mesmo `.config` (versão do Kconfig/host pode inserir defaults diferentes) — para isso, o gate é `scripts/diffconfig` após build de controle (plano v2 F3), não o diff textual.

## 2. Q12 — o que muda o CRC (genksyms, 6.6) + tabela SEGURO/ARRISCADO/PROIBIDO

### 2.1 Mecanismo — FACT (fonte)

- `FACT` (https://android.googlesource.com/kernel/common/+/refs/tags/android15-6.6-2025-06_r12/scripts/genksyms/genksyms.c + `kernel/module/version.c:80-88` + https://source.android.com/docs/core/architecture/kernel/stable-kmi + https://source.android.com/docs/core/architecture/kernel/abi-monitor): no 6.6 o versionamento usa **genksyms** (não gendwarfksyms): o pré-processador expande os tipos do protótipo de cada `EXPORT_SYMBOL*` e o CRC é o hash dessa string expandida (guardado em `vmlinux.symvers`/`Module.symvers`, seção `.__versions` de cada .ko). Muda o CRC tudo que muda a expansão: trocar tipo/parâmetro/retorno da função exportada; mudar layout de struct/union/enum alcançável do protótipo (adicionar/remover/reordenar campo, mudar largura, mudar `#ifdef` que altera a struct); mudar defines que entram na expansão. NÃO muda o CRC: comentários, nomes de variáveis locais, corpo da função sem tocar assinatura/tipos, debuginfo, prints, valores de sysfs, algoritmos internos autocontidos.
- Categorias de CONFIG que alteram layouts exportados (regra prática): `DEBUG_SPINLOCK/DEBUG_MUTEXES/LOCKDEP` (incham spinlock_t/mutex_t); `KASAN/KHWASAN/KCOV/GCOV` (redzones/instrumentação); `PREEMPT*` (modelo altera paths/structs de sched); `SMP=n`, `NUMA*` (per-cpu/nodes); `CFI_CLANG`, `SHADOW_CALL_STACK`, modo `LTO` (ABI de chamadas/prologos); `PAGE_SIZE` (struct page); `CGROUP*/BPF/PM_*` **só** se tocarem structs exportadas referenciadas pelo KMI (a maioria é interna → CRC-safe, mas risco funcional).
- Tabela completa: 28 linhas (10 SEGURO / 10 ARRISCADO / 8 PROIBIDO) em `research/config_safety_table.csv`, uma fonte por linha. Resumo: SEGURO = tunables sysfs, compressores zram, TCP cong como módulo, log buffer, printk.time, debuginfo, IKCONFIG, hash de assinatura, throttle/IO sched como módulo, netfilter matches como módulo. ARRISCADO (CRC-safe provável mas exige stgdiff+gate ou risco funcional) = HZ, PREEMPT model, SCHED_DEBUG, DAMON_PADDR/RECLAIM, ZSWAP, KernelSU+susfs (símbolos novos → estender kmi list), FTRACE com CFI, NUMA_BALANCING, THP always, --notrim (só debug). PROIBIDO (quebra CRC/boot garantida) = 16K pages, CFI off, SCS off, LTO≠NONE, KASAN, SMP=n, MODVERSIONS=n, DEBUG_SPINLOCK/MUTEXES/LOCKDEP no release.

## 3. Checagem ABI local (stgdiff/Kleaf) — procedimento sem construir tudo

- `MEASURED` (CI, todos <200 MB, baixados via viewer→artifactUrl + curl): `abi.stg` 7778263 B (sha `171759a8c50e923cba27d0d00b1ed88dfeb169ba99a33fa0d01d1fc4118e89c7`, salvo em `official-ab13771415/abi.stg`); `abi_symbollist` 820473 B (já local, 35339 linhas); `abi_symbollist.raw` 217460 B; `vmlinux.symvers` 540423 B; `System.map` 4730547 B. `stgdiff` ausente no host (`command -v stgdiff` = MISSING) — roda via toolchain do Kleaf.
- `FACT` (Kleaf docs + BUILD.bazel r12: alvos `kernel_aarch64_abi`, `kernel_aarch64_abi_dist`, `kmi_symbol_list_strict_mode True`): checagem oficial = comparar a ABI construída contra `abi.stg`/`abi_symbollist` de referência. Procedimento mínimo (só comparação, reaproveitando `abi.stg` oficial; comandos copiáveis, NÃO executados aqui):
  ```bash
  # 1) gerar ABI da árvore local (requer checkout pinado manifest_13771415.xml):
  tools/bazel build --jobs=4 --config=fast //common:kernel_aarch64_abi
  # 2) diff contra a referência oficial (stgdiff vem do prebuilt kernel-build-tools):
  prebuilts/kernel-build-tools/linux-x86/bin/stgdiff -a official-ab13771415/abi.stg -b bazel-bin/common/abi.stg | head -n 50
  # 3) alternativa textual rápida (sem stg): gate já validado do projeto:
  bash research/gate_kmi_crc.sh out/dist/vmlinux.symvers   # 0 mismatch esperado (MEASURED no oficial: 2309/0)
  ```
- `INFERRED`: dá para rodar só a comparação sem rebuild completo se já existir `bazel-bin/common/abi.stg` de build anterior; sem checkout/build, o `stgdiff` sozinho só compara dois `.stg` (oficial vs outro build), não prova nada sobre a árvore local. Viabilidade: **sim** (artefatos + alvos existem).

## 4. Timestamp/chave — reduzir diferenças vs Image oficial

- `FACT` (evidência §CODEX2 + revalidada aqui): `strings Image` = `Fri Jul 11 22:46:09 UTC 2025`; commit r12 committer `1752273969` = `2025-07-11 22:46:09 UTC` (python MEASURED); build wall-clock `23:53:16–23:59:23 UTC` (BUILD_INFO). Logo o timestamp é **SCM stamp** (`--config=stamp`), não hora do build.
- Redução (copiável, NÃO executado):
  ```bash
  export SOURCE_DATE_EPOCH=1752273969
  export KBUILD_BUILD_TIMESTAMP="Fri Jul 11 22:46:09 UTC 2025"
  # chave fixa (NÃO a efêmera): gerar uma vez e reutilizar em todos os builds de teste
  openssl req -new -nodes -x509 -sha256 -days 36500 -subj "/CN=lake-test/" -out certs/signing_key.pem -keyout certs/signing_key.pem 2>/dev/null
  tools/bazel build --jobs=4 --config=fast --config=stamp //common:kernel_aarch64_dist
  ```
  `UNVERIFIED`: nome exato da variável que o Kleaf honra (`SOURCE_DATE_EPOCH` vs `KBUILD_BUILD_TIMESTAMP` vs stamp interno) sem ler `kleaf/build.sh` na revisão `4039bcfd...`; testar comparando `strings Image | grep 'Linux version'`.
- O que **continuará diferente** mesmo com epoch+chave fixa (`INFERRED`): assinatura `MODULE_SIG` dos 79 módulos GKI embutidos (chave efêmera do Google ≠ nossa; `System.map` igual mas `.ko` diferem); `BUILD_SALT` se setado (aqui `""` nos dois — MEASURED); paths absolutos de build (`/buildbot/...` vs `~/lake-gki`) em debug/warnings; perfis PGO/BOLT/MLGO (`CC_VERSION_TEXT` oficial tem `+pgo,+bolt,+lto,+mlgo`; rebuild sem profiles gera código diferente com mesmo clang r510928); `build.number`/suffix se `ab<bid>` divergir (irrelevante p/ CRC por `same_magic`, §1).
- Comparar o resto por seção ELF/System.map (copiável):
  ```bash
  diff <(sort official-ab13771415/System.map) <(sort out/dist/System.map) | head
  diff <(sort official-ab13771415/vmlinux.symvers) <(sort out/dist/vmlinux.symvers) | head
  readelf -S out/dist/vmlinux | head -n 30
  ```

---
## Auto-revisão
- Rebaixado para `UNVERIFIED`: variável exata do stamp Kleaf; tamanho de checkout (sem clone); tempo de build local; `defconfig/Kconfig` do OWLXS além do lido; qualquer afirmação de byte-identidade futura.
- O que NÃO achei (queries tentadas): `arch/arm64/configs/gki_defconfig.fragment` no r12 (404, 2 B — não existe; só `autofdo_gki.fragment`/`microdroid*.fragment`); `kernel/Kconfig.ksu` e `drivers/kernelsu/Kconfig` no OWLXS (404 — fork usa `KernelSU/kernel/Kbuild` + `drivers/kernelsu` via `KSU_SRC` absoluto); `stgdiff` no host (MISSING — só via prebuilt); tamanho de checkout via API googlesource (sem endpoint público).
