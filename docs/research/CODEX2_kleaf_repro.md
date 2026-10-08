# CODEX2_kleaf_repro — build oficial 13771415 (r12 / 6.6.89) → reprodução local + KSU/Kleaf

> Data: 2026-10-05. Host: 6 cores / 15 GB RAM / 51 GB livres. Somente leitura em audit/ e backup-*. Downloads: só DADOS <200 MB de ci.android.com (viewer→artifactUrl, sem login/post). Nada executado de terceiros. Nenhum pacote instalado. Nenhum flash/adb.
> Legenda: `FACT` (URL/fonte lida) / `MEASURED` (saída local) / `INFERRED` / `UNVERIFIED` / `UNKNOWN`. Auto-revisão no fim rebaixa FACT sem fonte.

## 1. Build oficial 13771415 — comando, sufixo e config (artefatos em <lake-kernel>/official-ab13771415/)

### 1(a). Comando bazel EXATO + flags — MEASURED (build.log linha 3)

- `MEASURED` (`official-ab13771415/build.log`, sha256 `4103bc23f29904d311737bf6d4aebca54dc4d7a24c6929e9d7fafe8e6228add2`, 3350 B):
  ```
  tools/bazel build --jobs=64 --keep_going --make_jobs=64 --make_keep_going --repo_manifest=$PWD:/buildbot/dist_dirs/aosp_kernel-common-android15-6.6-2025-06-linux-kernel_aarch64/13771415/manifest_13771415.xml --config=android_ci --profile=/buildbot/dist_dirs/.../logs/command.profile.json --experimental_profile_include_target_label //common:kernel_aarch64_abi_dist //common:kernel_aarch64_tests && tools/bazel run --jobs=64 ... --repo_manifest=$PWD:.../manifest_13771415.xml --config=android_ci //common:kernel_aarch64_abi_dist -- --dist_dir=/buildbot/dist_dirs/.../13771415 --flat && ( tools/bazel test --jobs=64 ... --repo_manifest=$PWD:.../manifest_13771415.xml --config=android_ci --build_metadata="ab_build_id=13771415" --build_metadata="ab_target=kernel_aarch64" --build_metadata="test_definition_name=kernel/kleaf/kernel_aarch64_tests" //common:kernel_aarch64_tests  || [[ "$?" == "3" ]] )
  ```
  Fonte: `https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest/logs/build.log` (viewer→artifactUrl, `curl`, MEASURED acima). Template com `%cpu%/%bid%` em `official-ab13771415/execute_build_config.textproto` (sha `b7dd553c...`, 1717 B) e `BUILD_INFO:target.rules` — `FACT` (mesmo comando, mesma URL base).
- Flags relevantes (`FACT` por leitura direta):
  - `--jobs=64 --make_jobs=64` (CI, 235 GB RAM); `--keep_going --make_keep_going`; `--repo_manifest=$PWD:.../manifest_13771415.xml` (pin total, ver manifest §3); `--config=android_ci` (NÃO `--config=fast`; fast é só atalho local); `--profile=.../command.profile.json`; `--experimental_profile_include_target_label`; alvos `//common:kernel_aarch64_abi_dist //common:kernel_aarch64_tests`; dist via `bazel run ... -- --dist_dir=... --flat`; metadados `ab_build_id=13771415 ab_target=kernel_aarch64`.
  - `--lto / --kasan / --user_kmi_symbol_lists`: **ausentes** no comando oficial → `FACT`: build usa `lto=default` (build.log linha 7: `Building kernel (lto=default;trim)`), sem kasan, sem `user_kmi_symbol_lists` extra (KMI vem das listas base do r12). `INFERRED`: `lto=default` + `gki_defconfig` com `LTO_NONE=y` = sem LTO (ver §1c).
  - `localversion / BUILD_NUMBER / stamp`: **não** aparecem como flag bazel. Sufixo vem do stamp SCM + `build.config` (§1b). `--config=stamp` também ausente no comando (stamp é default no CI via `android_ci`); evidência Kleaf `--config=stamp: Handling SCM version` (`FACT`, https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/docs/api_reference/common_kernels.md + kleaf.md).
- Arquivos baixados nesta sessão (viewer→artifactUrl, `grep -o '"artifactUrl":"[^"]*"'`, `curl`, todos <200 MB — `MEASURED`):
  ```
  build.log (3350 B, sha 4103bc23...), execute_build_config.textproto (1717 B, b7dd553c...),
  init_build_config.textproto (1899 B, 71dd7fca...), command.profile.json (1848162 B, a457c482...),
  kernel_aarch64_filegroup_decl.tar.gz (21452372 B, sha 6dc0daae..., 21 MB),
  kernel_sbom.spdx.json (81289 B, 44185e4e...), memory_usage.json (21828 B, 0253ba44...),
  disk_usage.json (13982 B, 135127dd...)
  ```
  Comando de extração (copiável, só GET): `curl -sL "https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest/<art>" | grep -o '"artifactUrl":"[^"]*"'`.

### 1(b). Como `-ab13771415-4k` foi gerado — FACT + MEASURED

- `MEASURED` (`official-ab13771415/gki-info.txt`): `kernel_release=6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k`; `official-ab13771415/bazel-out/.../kernel_aarch64/include/config/kernel.release` (via filegroup): idem.
- `MEASURED` (`filegroup/.../kernel_aarch64_config/out_dir/localversion`): `-android15-8-g5a0ffb447c1d-ab13771415` (sem `-4k`; `-4k` vem de `CONFIG_LOCALVERSION="-4k"` no `.config`).
- `FACT` (https://source.android.com/docs/core/architecture/kernel/android-common + GKI versioning): formato `6.6.89-android15-<KMI_GEN>-g<sha>-ab<bid>-4k` = upstream `6.6.89` + `android15` + geração KMI `8` + sha curto `g5a0ffb447c1d` (commit `5a0ffb447c1d...`, `manifest_13771415.xml` linha 22 + `repo.prop` linha 2) + `ab<BID>` (`BUILD_INFO:bid=13771415`, `execute_build_config:build_id=13771415`) + `LOCALVERSION -4k` (`build.config` + `.config`).
- `FACT` (refuta "BUILD_NUMBER idêntico obrigatório"): `kernel/module/version.c` do r12 (`MEASURED` via `https://raw.githubusercontent.com/aosp-mirror/kernel_common/android15-6.6-2025-06_r12/kernel/module/version.c`, linhas 80-88):
  ```c
  int same_magic(const char *amagic, const char *bmagic, bool has_crcs){
    if (has_crcs){ amagic += strcspn(amagic," "); bmagic += strcspn(bmagic," "); }
    return strcmp(amagic,bmagic)==0;
  }
  ```
  Com CRCs (`MODVERSIONS=y`, MEASURED no stock), o kernel **ignora o primeiro token** (`6.6.89-android15-8-g...-ab...-4k`) e compara só `SMP preempt mod_unload modversions aarch64`. Logo `-ab13771415` e hash `g...` **NÃO precisam bater** nos vendor_dlkm (consistente com plano v2 fato 6 + fato 5: 208 módulos `g810fd09a116c`, 7 `gf597b3de5ef5`, todos carregam). `INFERRED`: `ab<bid>` é carimbo informativo do CI (`--build_metadata ab_build_id`), não chave de compatibilidade quando há CRCs.

### 1(c). Config final — diff vazio — MEASURED

- `MEASURED` (filegroup `.config` 211483 B vs `<lake-kernel>/audit/config.stock` 207K):
  ```
  diff <(sort filegroup/.../out_dir/.config) <(sort audit/config.stock) | wc -l  →  0
  ```
  Trecho comum (ambos): `CONFIG_LOCALVERSION="-4k"`, `LOCALVERSION_AUTO=y`, `KPROBES=y`, `SHADOW_CALL_STACK=y`, `LTO_NONE=y`, `CFI_CLANG=y`, `MODVERSIONS=y`, `MODULE_SIG=y`, `MODULE_SIG_PROTECT=y`, `MODULE_SIG_ALL=y`, `MODULE_SIG_SHA1=y`, `TRIM_UNUSED_KSYMS=y`, `MODULE_SIG_KEY="certs/signing_key.pem"`.
- `MEASURED` (`kernel.release` no filegroup): `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k`. `abi_symbollist.raw`: 8962 linhas.
- `INFERRED`: stock do aparelho = `.config` oficial do CI sem delta (pelo menos no sort-diff; ordem/comentários podem diferir, conteúdo não).

## 2. Comando LOCAL (sem BUILD_NUMBER do CI) + timestamp + G-REPRO

### Comando local — INFERRED (derivado de §1a, sem RBE/CI)

```bash
# checkout pinado (manifest oficial já em official-ab13771415/manifest_13771415.xml):
mkdir -p <workdir>/lake-gki && cd <workdir>/lake-gki
repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2025-06
cp <lake-kernel>/official-ab13771415/manifest_13771415.xml .repo/manifests/pinned.xml
repo init -m pinned.xml && repo sync -c --no-tags -j4
# build controle (sem KSU, sem mudar nada; tools/bazel vem do checkout via kleaf/bazel.sh):
tools/bazel build --jobs=4 --keep_going --make_jobs=4 --make_keep_going --config=fast //common:kernel_aarch64_dist
# alternativa dist direta:
tools/bazel run --jobs=4 --config=fast //common:kernel_aarch64_dist -- --dist_dir=$PWD/out/dist --flat
```

O que muda sem `BUILD_NUMBER=13771415` / sem `--build_metadata ab_build_id`: **só o carimbo `ab<bid>` no `uts_release`** (ex.: `-abXXXX-4k` local vs `-ab13771415-4k` oficial). Por §1b (`same_magic`), vendor com CRCs **ignora** essa diferença. `UNVERIFIED` (sem build local executado): se o host gerar `ab<bid>` diferente ou `g<sha>-dirty`, o `strings Image` difere mas o boot e os módulos seguem OK se CRCs baterem.

### Origem do timestamp `Fri Jul 11 22:46:09 UTC 2025` — FACT com evidência

- `MEASURED` (strings do `official-ab13771415/Image` e do stock): `... #1 SMP PREEMPT Fri Jul 11 22:46:09 UTC 2025`.
- `FACT` (commit r12, `https://android.googlesource.com/kernel/common/+/5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143`, base64 decodificado localmente):
  ```
  author Rui Chen <chenrui9@honor.com> 1751363846 +0800
  committer Jhih-Chen Huang (xWF) <jhihchen@google.com> 1752273969 -0700
  ```
  `MEASURED` (`python3`: `datetime.fromtimestamp(1752273969, UTC)` → `2025-07-11 22:46:09+00:00`): **idêntico ao segundo** ao timestamp do Image. Build wall-clock foi depois: `BUILD_INFO target_start 1752277996 = 2025-07-11 23:53:16 UTC`, `finish 1752278363 = 23:59:23 UTC` (366 s), `command.profile.json date 2025-07-11T23:53:25Z`, `sbom created 2025-07-11T23:58:19Z`.
- `INFERRED` (comportamento Kleaf `--config=stamp`, `FACT` https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/docs/api_reference/common_kernels.md): o `uts version` usa a data do **commit (SCM stamp)**, não a hora do build. Por isso rebuild local do mesmo commit tende a reproduzir o mesmo timestamp **se** o stamp SCM estiver ativo; sem stamp (`--config=fast` sem stamp?) o timestamp vira hora local → diff explicável. Variável exata (`KBUILD_BUILD_TIMESTAMP` vs `SOURCE_DATE_EPOCH` vs `KLEAF_STAMP`) = `UNVERIFIED` sem inspecionar `build/kernel/kleaf` na revisão `4039bcfd...`; NÃO alegar qual variável sem ler o script.
- Evidência auxiliar de reprodutibilidade: `filegroup/.../.config` tem mtime `1969-12-31 21:00:00 -0300` (= epoch 0, hermético); `build.log`: `Elapsed 342.155s, Critical Path 320.78s, 1207 processos (859 internal, 348 linux-sandbox)` — build com RBE (`execute_build_config`: `RBE_instance us-east1`, `use_goma=false`).

### G-REPRO: o que NÃO dá para reproduzir + como comparar mesmo assim

- NÃO reproduzível bit a bit sem esforço extra (`INFERRED`): assinatura `MODULE_SIG` (chave efêmera `certs/signing_key.pem` gerada por build), `BUILD_SALT` (vazio aqui, mas assinaturas mudam), `ab<bid>` sem `BUILD_NUMBER`, timestamp sem stamp SCM, paths absolutos (`/buildbot/...` vs `<workdir>/lake-gki`), PGO/BOLT/MLGO profiles (Image oficial: `+pgo,+bolt,+lto,+mlgo` no `CC_VERSION_TEXT`; rebuild local sem profiles gera código diferente mesmo com mesmo clang).
- Comparar mesmo assim (copiável):
  ```bash
  sha256sum official-ab13771415/Image out/dist/Image
  diff <(sort official-ab13771415/vmlinux.symvers) <(sort out/dist/vmlinux.symvers) | head
  diff <(sort official-ab13771415/kernel_aarch64_Module.symvers) <(sort out/dist/Module.symvers) | head
  diff official-ab13771415/System.map out/dist/System.map | head
  strings out/dist/Image | grep -a -m1 "Linux version"
  ```
  Critério G-REPRO do plano v2: `sha256 out/dist/Image == a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca` (MEASURED oficial+stock, 36461056 B). Se diferir, o diff de `System.map/vmlinux.symvers` diz se é só carimbo (endereços iguais, versão diferente) ou divergência real (símbolos/CRCs).

## 3. Viabilidade do host Arch/CachyOS (6c / 15 GB / 51 GB livres)

- `MEASURED` (host agora): `nproc=6`, `Mem 15Gi (2.5Gi disp, 8.3Gi swap usado)`, `df /home 51G livres (90% usado)` (antes 58G; caindo — risco).
- `MEASURED` (`manifest_13771415.xml`): 36 `<project>`, `superproject common-android15-6.6-2025-06`, `common=5a0ffb44...`, `kernel/build=4039bcfd...`, `prebuilts/clang=70616732...` (clone-depth=1 nos prebuilts). Tamanho do checkout por `git ls-remote`/API: `UNKNOWN` (googlesource não expõe tamanho; sem clone não há medida). Estimativa `UNVERIFIED` (com fonte indireta: docs Kleaf + filegroup + CI): checkout enxuto (`repo sync -c --no-tags`, depth parcial) ≈ 15–30 GB; `out/` local sem RBE ≈ 25–45 GB; total ≈ 40–75 GB → **não cabe com folga em 51 GB sem limpeza** (ver redução abaixo). `disk_usage.json` do CI (com RBE, `MEASURED`): disco 1313 GB total, `used 14→23 GB` (+9 GB no `out/` do CI, que usa RBE e não materializa tudo local); **não** extrapolar para host sem RBE.
- `MEASURED` (CI, `memory_usage.json`/`disk_usage.json`/`command.profile.json`/`build.log`): máquina 235 GB RAM, `max_used 12 GB` (média 7 GB) com `--jobs=64` + RBE; `bazel_version release 7.1.1`; duração 366 s (342 s build). Host com 15 GB **precisa** `--jobs=4`, `--make_jobs=4`, `--config=fast`, sem RBE → pico maior e tempo 1–3 h (`UNVERIFIED`, sem build local).
- `FACT` (manifest + Kleaf docs https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/docs/kleaf.md): `tools/bazel` é `kleaf/bazel.sh` (wrapper; baixa/usa bazel pinado, não o bazel do sistema); JDK vem de `prebuilts/jdk/jdk11` (manifest linha 60); precisa `python3` (+ `libelf`, `ncurses`, `bc`, `cpio`, `rsync`, `curl`, `git`, `repo` no host — nomes pacman variam, `UNVERIFIED` para lista exata CachyOS).
- Redução (copiável):
  ```bash
  repo sync -c --no-tags -j4
  tools/bazel build --jobs=4 --make_jobs=4 --config=fast --disk_cache=<HOME>/.bazel_cache //common:kernel_aarch64_dist
  # legado: LTO=thin BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh -j4
  ```
  `INFERRED`: com `LTO_NONE=y` no stock, NÃO passar `--lto=thin` no build de controle (muda ABI/CFI); `LTO=thin` só para iteração KSU depois, com re-gate KMI.

## 4. Integração KernelSU em Kleaf (OWLXS/android_kernel_common, branch lamu-6.6.142 — só leitura)

- `FACT` (https://github.com/OWLXS/android_kernel_common/tree/lamu-6.6.142, 13 commits, descrição: `kernel/common (android15-6.6.142) fork for the lamu build — hosts local patches (CFI fix, KernelSU/susfs)`): base `android15-6.6.142_r00` + fixes locais (NÃO é o r12/6.6.89; portar com cuidado).
- `MEASURED` (API GitHub, sem clone): commits (novos→velhos): `9db3a171 gki_defconfig: DAMON_PADDR/RECLAIM`, `e2787086 TEST ThinLTO instead of kCFI, HZ_1000`, `a32920 susfs: reapply 50_add_susfs_in_gki-android15-6.6.patch cleanly on pristine sources`, `5c874921 KernelSU/susfs: update to ReSukiSU main (fa8311f6, v4.2.0-rc3) + susfs4ksu gki-android15-6.6-dev HEAD`, `b0e988a4c2 KernelSU: point KSU_SRC at new build server path`, `2aefb957 restore hardcoded KSU_SRC absolute path for Bazel sandbox compat`, `9a3a37df hardcode version strings instead of git fallback`, `c75eb8164 update ReSukiSU vendored copy to upstream HEAD (6ec8d9a, 2026-09-17)`, ...
- `MEASURED` (`KernelSU/kernel/Kbuild` raw, trecho final):
  ```
  KSU_SRC := /serverhive/ephitaphx/KERNEL-LAMU/kernel-6.6/KernelSU/kernel
  # (antes: /serverhive/themoonx/Axion-Lamu/out-kernel/motorola_lamu/kernel-6.6/KernelSU/kernel)
  LOCAL_GIT_EXISTS := $(shell test -e $(KSU_SRC)/../.vendored && echo 1 || echo 0)
  ```
  + `kernelsu-objs := core/init.o policy/... feature/... hook/... selinux/...` e `obj-$(CONFIG_KSU) += kernelsu.o`; `ccflags-y += -I$(srctree)/$(src)/include` etc. Padrão: **KernelSU vendored em `KernelSU/`** (com `.vendored`, NÃO `.git`), `drivers/kernelsu` ausente como dir separado (API `drivers` sem entrada ksu; o build usa `KSU_SRC` absoluto porque o sandbox Bazel não resolve path relativo — commits `2aefb957`/`b0e988a4c2`).
- `MEASURED` (commit `5c874921`, corpo): ReSukiSU `v4.2.0-rc3 (fa8311f6)` + `susfs4ksu gki-android15-6.6-dev HEAD`; reaplicados 4 patches locais (KSU_SRC absoluto, `.vendored` check, `KSU_SUSFS` hook default, version strings hardcoded); `fs/susfs.c + include/linux/susfs.h/susfs_def.h` trocados por atacado (fix `is_statically int→bool`); `50_add_susfs_in_gki-android15-6.6.patch` reaplicado com `--fuzz=0` sobre 25 arquivos pristine (`fs/exec.c,namei.c,namespace.c,notify/fdinfo.c,proc/fd.c,proc_namespace.c,stat.c,statfs.c,proc/task_mmu.c...`).
- O que aplicar sobre o r12 (6.6.89) (`INFERRED`, a validar em build de controle antes): (1) copiar `KernelSU/` vendored na versão pinada (`fa8311f6` ou tag estável, NÃO HEAD flutuante) + `.vendored`; (2) portar `50_add_susfs...patch` para 6.6.89 (o patch do OWLXS mira 6.6.142; hunks em `fs/stat.c,fdinfo.c,fd.c,task_mmu.c` tendem a conflitar); (3) ajustar `KSU_SRC` para path absoluto do checkout local (sandbox Kleaf exige absoluto bind-mounted); (4) `gki_defconfig` + `Kconfig` (`CONFIG_KSU`, `KSU_SUSFS`; upstream `tiann/KernelSU` exige `KPROBES`+`EXT4_FS` — `KPROBES=y` MEASURED no stock); (5) `BUILD.bazel`: **não** precisa editar `kernel_build` se KSU entra via `Kbuild`/`Kconfig` in-tree (OWLXS não mostra `ksu` em `BUILD.bazel` — `MEASURED` grep vazio); se virar módulo externo, declarar `kernel_module` + `kmi_symbol_list` adicional. `UNVERIFIED`: detalhe `defconfig/Kconfig` exato do OWLXS (só lido `gki_defconfig` head + `Kbuild`; `kernel/Kconfig.ksu` e `drivers/kernelsu/Kconfig` deram 404 = paths diferentes no fork).

## 5. Riscos (3 para o bloco final + auto-revisão)

- Disco acabou (51G, 90%): checkout+out estoura sem ` -c --no-tags`, `--disk_cache` externo e limpeza; CI usou RBE (9 GB no `out/` remoto), host materializa tudo.
- Port susfs 6.6.142→6.6.89 quebra (`fs/stat.c/fdinfo.c/fd.c/task_mmu.c` com `SUS_KSTAT` refactor; commit `a32920` prova fragilidade mesmo com `--fuzz=0`).
- `KSU_SRC` absoluto + versão hardcoded: path do servidor (`/serverhive/...`) não existe no host; sem ajuste o sandbox Bazel não acha fontes e o fallback git mente a versão (commit `9a3a37df` esiste por isso).

---
### Auto-revisão
Rebaixado para `UNVERIFIED`/`UNKNOWN`: tamanho exato do checkout (sem clone), lista pacman exata CachyOS, variável exata do stamp (`KBUILD_BUILD_TIMESTAMP` vs `SOURCE_DATE_EPOCH`), detalhe `defconfig/Kconfig` do OWLXS além do lido, tempo de build local. Nenhum `FACT` acima sem URL/saída.

### Comandos copiáveis (reunidos)
```bash
# viewer→artifactUrl (sem login):
for art in "logs/build.log" "logs/execute_build_config.textproto" "logs/init_build_config.textproto" "logs/command.profile.json" "kernel_aarch64_filegroup_decl.tar.gz" "kernel_sbom.spdx.json" "logs/resource_utilization/memory_usage.json" "logs/resource_utilization/disk_usage.json"; do curl -sL --max-time 30 "https://ci.android.com/builds/submitted/13771415/kernel_aarch64/latest/$art" | grep -o '"artifactUrl":"[^"]*"'; done
# config oficial vs stock (diff vazio esperado):
diff <(sort <workdir>/filegroup/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config) <(sort <lake-kernel>/audit/config.stock) | wc -l
# G-REPRO:
sha256sum <lake-kernel>/official-ab13771415/Image out/dist/Image
```
