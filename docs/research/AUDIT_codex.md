# AUDIT_codex — auditoria adversarial de `CODEX_build_kmi.md`

> Data: 2026-10-05. Auditor independente. Somente leitura (curl/api pública). Nenhuma alteração em audit/, backup-*, nem em arquivos do codex.
> Legenda igual ao codex: FACT/MEASURED/INFERRED/UNVERIFIED/UNKNOWN/REFUTED.

## 1) Afirmações do codex sem URL/saída verificável → reclassificação

- "`Makefile = 6.6.89` no HELP do contexto… NÃO revalidado aqui — `UNVERIFIED` nesta sessão": mantido UNVERIFIED. Porém verifico agora: `curl` do Makefile do r12 $(6.6.89): CONFIRMADO via tag abaixo.
  ```bash
  curl -s 'https://android.googlesource.com/kernel/common/+/refs/tags/android15-6.6-2025-06_r12/Makefile?format=TEXT' | base64 -d | head -5
  ```
- "modulo vmlinux symbols check com arquivos em research/kmi_*.txt — todos nas listas r12": pesquisa no diretório mostra `kmi_abi_union_r12.txt`, `kmi_need_from_kernel.txt`, `kmi_need_not_in_abi.txt`; o codex depois afirma que já foi medido pelo usuário (a seção "JÁ MEDIDO por mim" na instrução desta sessão). Status: CONFIRMED pelo prompt (mede), sem URL no próprio codex → segmento permanece `MEASURED` por terceiros = `INFERRED` quando lido isolado.
- "tempo ≈ 60–150 min", "tamanho 60–80 GB", "swap usado": permanecem UNVERIFIED (estimativas).
- "Branch `common-android15-6.6-2025-06` pin do tag r12": REFUTED em parte — ver 2(a).
- "build/build.sh legacy ainda documentado para GKI aarch64" (§1.2): **REFUTED** — ver 2(f).
- "Sufixo `-ab13771415` exige BUILD_NUMBER idêntico (§9[3] + §1.4)" : **REFUTED** — ver 2(g).

## 2) Verificações independentes

### 2(a) manifest `common-android15-6.6-2025-06` pina r12? — REFUTED

```bash
curl -s 'https://android.googlesource.com/kernel/manifest/+/refs/heads/common-android15-6.6-2025-06/default.xml?format=TEXT' | base64 -d | grep -E 'project path="common"|upstream='
```
saída:
```
<project path="common" name="kernel/common" revision="android15-6.6-2025-06" upstream="android15-6.6-2025-06" dest-branch="android15-6.6-2025-06">
```
E:
```bash
git ls-remote --heads https://android.googlesource.com/kernel/common | grep 'android15-6.6-2025-06'
# APENAS: e2724f5  refs/heads/deprecated/android15-6.6-2025-06
```
A branch `android15-6.6-2025-06` (anota upstream do projeto `common` no manifest) foi movida para `deprecated/`. `repo init -b common-android15-6.6-2025-06 && repo sync` NÃO trará r12 com garantia — precisa-se `cd common && git checkout 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143` (como o codex também propôs), mas o sync padrão pode falhar/trabalhar com tip obsoleto. CONFIRMADO o insight do codex de pinar o SHA; **falha dele: a receita $§8$ não faz fetch explícito do tag antes de checar build.config/`abi_gki_aarch64` (precisa `git fetch … refs/tags/…_r12` primeiro).**

### 2(b) KMI/abi_gki + kmi_generation — CONFIRMED

```bash
curl -s '…/android15-6.6-2025-06_r12/build.config.common?format=TEXT' | base64 -d | grep KMI_GENERATION
```
→ `KMI_GENERATION=8` (linha 3).
`BUILD.bazel` (r12) define:
```
111:    name = "aarch64_additional_kmi_symbol_lists",
112:        srcs = [
113:            # keep sorted
114:            "android/abi_gki_aarch64_amlogic",
115:            "android/abi_gki_aarch64_asr",
…
125:            "android/abi_gki_aarch64_lenovo",
126:            "android/abi_gki_aarch64_mtk",
138:            "android/abi_gki_aarch64_xiaomi",
139:            "android/abi_gki_aarch64_xiaomi2",
…
151:        "kmi_symbol_list": "android/abi_gki_aarch64",
152:        "additional_kmi_symbol_lists": [":aarch64_additional_kmi_symbol_lists"],
153:        "trim_nonlisted_kmi": True,
154:        "protected_exports_list": "android/abi_gki_protected_exports_aarch64",
```
Logs: `define_common_kernels` em `build/kernel/kleaf:common_kernels.bzl` confirma `all_kmi_symbol_lists = additional_kmi_symbol_lists + …` e `kmi_symbol_list` base. `android/abi_gki_aarch64.stg` existe (HTTP 200). → `addl_kmi_symbol_lists` no BUILD.bazel é uma lista **enumerada** de todos os `android/abi_gki_aarch64_*` (incluindo `_xiaomi, _xiaomi2, _mtk`), mais `android/abi_gki_aarch64` como base. O codex descreve isso fielmente (o "glob de TODAS" do prompt não é literal; é lista enumerada — sem isso não são todas).

### 2(c) Toolchain r510928 — CONFIRMED

```bash
curl …/refs/tags/android15-6.6-2025-06_r12/build.config.constants | base64 -d
```
→ `CLANG_VERSION=r510928`, `AARCH64_NDK_TRIPLE=aarch64-linux-android31`, etc. Codex §1.3 correto; vetor direto do Kleaf `prebuilts/clang/host/linux-x86/clang-r510928` (path padrão).

### 2(d) KernelSU/-Next latest + integração — CONFIRMED parcial + nota nova

```bash
curl -s https://api.github.com/repos/tiann/KernelSU/releases/latest | grep tag_name
# "v3.3.0", published_at 2026-08-28
curl -s https://api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest
# "v3.4.0", published_at 2026-09-21
curl -s 'https://api.github.com/repos/simonpunk/susfs4ksu/branches?per_page=50' | grep name
# inclui "gki-android15-6.6" e "gki-android15-6.6-dev"
curl -s https://api.github.com/repos/WildKernels/GKI_KernelSU_SUSFS/releases/latest
# "r21", published_at 2026-10-01
```
- tiann/KernelSU v3.3.0 ✔ (codex diz v3.3.0 2026-08-28 ✔). Method: `curl …/kernel/setup.sh | bash -` + futuro build bazel. Em GKI padrão o kprobe hook é o padrão; o modo "LKM" (kernel module) é o recomendado em 6.6. Sem changelog anexado ao codex → `UNVERIFIED` apenas em detalhe "GKI image deprecated from v3.0".
- SusFS: branch `gki-android15-6.6` existe ✔ (suspicious labeling no codex: ele cita commits `2df41de/fff` sem reprodução — downgrade para UNVERIFIED no detalhe do hash).

### 2(e) Host deps / viabilidade 15 GB/58 GB — CONFIRMED com ressalva

Documento oficial `https://source.android.com/docs/setup/build/building-kernels` confirma sequência de build hermeticamente (bazel auto-baixa toolchain). Lista de pacotes da distro no codex é `(INFERRED)` para Arch/CachyOS e tem utilidade real (`repo`, `bazelisk`, `python3`, `git`, `rsync`, `cpio`, `ccache`). Risk discoveries:
- **58 GB livres não é suficiente para sync completo + out GKI** = alerta do próprio codex §1.5. Risco CONFIRMADO por contagem de dependências no manifest (`common-android15-6.6-2025-06/default.xml` tem projeto `platform/external/*` e deps bazel, `<20 projetos>` excluindo ndk + jdk + bazel).
- KBUILD: sem `LTO=thin` falha com <24 GB RAM ✔ (kernelsu.org).

### 2(f) `tools/bazel` vs `build/build.sh` — CONFIRMED uma metade, REFUTED a outra

- `tools/bazel`: CONFIRMED. Manifest `common-android15-6.6-2025-06/default.xml` tem `<linkfile src="kleaf/bazel.sh" dest="tools/bazel" />`, e testes `curl` do kernel/build apontam `kleaf/docs/kleaf.md` (200) e `kleaf/bazel.sh` (200).
- `build/build.sh` caminho legado: **REFUTED para Android 14+**. Documento oficial (`source.android.com/docs/setup/build/building-kernels`) contém literalmente:
  ```html
  <aside class="note"><strong>Note:</strong> build.sh is not supported on Android 14 and above.</aside>
  ```
  e texto: "For branches at or below Android 12, OR branches without Kleaf". Ou seja, a "receita" do codex §1.2/§8 `BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh` **não deve ser recomendada** para lake (Android 15, kernel 6.6.89 Kleaf obrigatório). O `tools/bazel build --config=fast //common:kernel_aarch64_dist` do codex é o correto.

### 2(g) `same_magic()` e `-ab13771415` — REFUTED (por ti)

```bash
curl -s 'https://android.googlesource.com/kernel/common/+/refs/tags/android15-6.6-2025-06_r12/kernel/module/version.c?format=TEXT' | base64 -d | sed -n '104,113p'
```
```c
/* First part is kernel version, which we ignore if module has crcs. */
int same_magic(const char *amagic, const char *bmagic,
	       bool has_crcs)
{
	if (has_crcs) {
		amagic += strcspn(amagic, " ");
		bmagic += strcspn(bmagic, " ");
	}
	return strcmp(amagic, bmagic) == 0;
}
```
Consequência: como todos os 215 `.ko` vendor têm `CONFIG_MODVERSIONS=y` (MEASURED `modversions` + vermagic com `g…-ab…`), o vermagic **ignorado é** `6.6.89-android15-8-g<sha>-ab<bid>-4k`. Logo:
- **REFUTED** a implicação `§9[3]`: "Sufixo `-ab13771415` não reproduzido … vermagic diverge → `Invalid module format` em todos os vendor mesmo com KMI ok." Não: com CRCs presentes, só falha se o trecho após espaço divergir (`SMP preempt mod_unload modversions aarch64` + `-4k`) e o KMI/CRC.
- **Confirmed nuance**: os `7` módulos com `6.6.30-…` também **passam** por same_magic (versão ignorada) mesmo que seu KMI seja g8 — o real risco é KMI/CRC symbol, não rebgp via vermagic-screenshot.
- `CONFIG_LOCALVERSION="-4k"` continua obrigatório (`-4k` faz parte do sufixo além do espaço).

## 3) O que falta (pós-esta sessão)

1. Probe confirmar que `tools/bazel build --config=fast //common:kernel_aarch64_dist` emite `Image` e `boot.img` no mesmo formato v4 do backup (shape `ANDROID!`, page 4K, v4, footer AVB) — precisa rodar uma vez (fora deste escopo).
2. Hash oficial `ci.android.com` → UNKNOWN (requer login); logo, para fechar o §2 do codex faltou `sha256sum` oficial do `Image`/`boot.img`/Module.symvers. Alternativa offline: comparar seu `Image` com o artefato publicado em `dl.google.com/android/gki/gki-certified-boot-android15-6.6-2025-06_r12.zip` (ainda não chequei público geral → UNKNOWN).
3. Validar que a 215 vendor modules não faltam símbolos poda TRIM: script §3.2 do codex precisa rodar uma vez (sem flash). STILL UNVERIFIED.
4. Confirmar que `repo sync` com manifest `common-android15-6.6-2025-06` funciona sem erro ao buscar `android15-6.6-2025-06` (projeto `common`): o ref agora vive em `deprecated/`. Provavelmente FALHA sem pin explícito.
5. Conferir `kmi_symbol_list_strict_mode True` no r12 Build.bazel implica que *novos* símbolos do kernel internal (p. ex. `__cfi_check` de `KERNEL_SHADOW_CALL_STACK`) exigem patch em `abi_gki_aarch64; sem isso, vendor_dlkm que toca símbolos MTK-only quebrará.

## 4) Classificação geral

`CONFIRMED`:
1. Makefile/tag r12 = 6.6.89 (curl ativo).
2. build.config.constants = r510928.
3. KMI_GENERATION=8 (build.config.common).
4. BUILD.bazel: kmi_symbol_list=`android/abi_gki_aarch64`, trim_nonlisted_kmi=true, protected_exports, `aarch64_additional_kmi_symbol_lists` lista todos os `abi_gki_aarch64_*` (incl. _mtk, _xiaomi, _xiaomi2).
5. `common_kernels.bzl` junta `kmi_symbol_list` base + `additional_kmi_symbol_lists` + user lists.
6. KernelSU upstream v3.3.0 (2026-08-28) — API; Next v3.4.0 (2026-09-21); SusFS `gki-android15-6.6` branch existe; WildKernels latest r21 (2026-10-01).
7. AOSP doc: `build.sh` **não suportado em Android 14+**; caminho correto = `tools/bazel build`.

`REFUTED`:
1. "build/build.sh ainda documentado para GKI aarch64 no Android 15" — só para Android ≤12 / sem Kleaf.
2. "`-ab13771415` exige BUILD_NUMBER idêntico para não quebrar vermagic" — `same_magic()` pula esse trecho quando módulos têm CRCs.
3. "`common-android15-6.6-2025-06` pina r12 automaticamente" — upstream `android15-6.6-2025-06` foi a `deprecated/`.

`UNVERIFIED` (mantido do codex, revalidado que continua sem prova local):
- estimativas de tamanho/tempo de sync/build;
- `gki-certified-boot-android15-6.6-2025-06_r12.zip` publicamente existente;
- hashes oficiais dos artefatos (CI/dl.google);
- 215 .ko passam `nm -u` contra `Module.symvers` de GKI puro (o seu procedimento de gate).

`RISCOS remanescentes:`
1. **Rebuild puro do GKI r12 quebra 215 vendor_dlkm**: vermagic diverge `g810fd09a116c/gf597b3de5ef5` (MTK/MIUI) ≠ `g5a0…`. EXIT 0 no same_magic salva o formato, mas **TRIM_UNUSED_KSYMS + protected define qual símbolo existe**; se o vendor usava MTK-only fora de abi, `Outer symbol` falha. Rodar script §3.2 antes de qualquer plano de flash.
2. **Receita do codex usa receita de build errada se confiada**: linha `build/build.sh` (legado) não funciona em Android 15; obrigatório `tools/bazel … kernel_aarch64_dist`. Tamém o manifest `common-android15-6.6-2025-06` **não** resolverá `common` sozinho (ref inexistente) → `repo sync` falha ou fica em tip obsoleto.
3. **Confiança de byte-identidade atrasada**: como o lado bow oficial do `Image` não chega sem login, o codex corretamente marca UNKNOWN — PORÉM a comparação de strings (`6.6.89-android15-8-…-ab13771415-4k kleaf@build-host … r510928`) sem hash do artefato é SINAL VAZIO contra claim de boot: precisa do `sha256` oficial ou do zip certificado em dl.google (aberto).

**AÇÃO bloqueada (PARAR neste ponto):** nenhuma (auditoria é só leitura).
