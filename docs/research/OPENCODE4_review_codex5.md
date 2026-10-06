# OPENCODE4_review_codex5 — Revisão adversarial do CODEX5_build_signing.md e do patch de certificado

**Data:** 2026-10-05 · **Revisor:** OPENCODE4 (VANTA) · **Alvo:** `research/CODEX5_build_signing.md` (codex) + patch proposto para `kleaf/common_kernels.bzl` @ `kernel/build 4039bcfd`
**Método:** clone raso somente-leitura de kernel/build na revisão pinada (`--filter=blob:none --no-checkout` + `checkout 4039bcfd`), fontes r12 via `?format=TEXT`+base64, openssl, python. Nada executado de terceiros; sem adb/flash; `audit/`/`backup-*`/`official-*` intocados; trabalho em `/tmp/opencode4-work`.
**Rótulos:** FACT/MEASURED/INFERRED/UNVERIFIED/UNKNOWN, com saída colada ou URL/linha. 3 abordagens por ponto crítico; medições críticas refeitas por 2 métodos.

---

## §1. O patch do codex aplica limpo? NÃO — o literal é inaplicável; o corrigido aplica limpo

### 1.1 Teste do patch DO CODEX (literal, como está no CODEX5 §B.2)

O bloco ```diff do CODEX5 não é um diff unificado válido: hunk headers descritivos (`@@ defconfig_fragments / blocos de _kernel_build — acrescentar forward:`), reticências de prosa, dois repositórios num só arquivo, e um quarto "hunk" que é um nome de arquivo sem conteúdo. Saída colada:

```
$ git -C /tmp/opencode4-work/build apply --check codex_patch.diff
error: No valid patches in input (allow with "--allow-empty")
exit: 128
```
**ERRO #1 (MEASURED):** o patch como escrito não aplica — era um esboço, e o próprio CODEX5 o rotulou "UNVERIFIED (nomes exatos de kwargs/linhas no macro podem variar ±)". Confirmado: não é aplicável, nem com fuzz.

### 1.2 Verificação das premissas do codex no fonte pinado (tudo MEASURED no clone @4039bcfd)

| Claim do CODEX5 | Veredito | Evidência (linha no clone) |
|---|---|---|
| `kernel_build()` aceita `system_trusted_key` | **CONFIRMADO** | `kleaf/impl/kernel_build.bzl:118` (`system_trusted_key = None,`), doc `:399`, repasse à rule `:595` (`kernel_config(... system_trusted_key = system_trusted_key ...)`) |
| `kernel_config` define `CONFIG_SYSTEM_TRUSTED_KEYS=<basename>` | **CONFIRMADO** | `kleaf/impl/kernel_config.bzl:161-164` (`_config_keys`: `--set-str SYSTEM_TRUSTED_KEYS ctx.file.system_trusted_key.basename`) + rsync `:354-364` (`rsync -aL <file> ${OUT_DIR}/<basename>`, dentro do `extra_restore_outputs_cmd` do setup) + attr `:534-538` (`attr.label(allow_single_file=True)`) |
| `common_kernels.bzl` NÃO repassa | **CONFIRMADO (0 ocorrências)** | `grep -n system_trusted_key kleaf/common_kernels.bzl` → vazio no original |
| Docstring upstream do attr | **CONFIRMADO** | `kleaf/docs/api_reference/kernel.md:1207` ("dynamic setting of `CONFIG_SYSTEM_TRUSTED_KEY` from Bazel", default `None`) |

### 1.3 O modo de falha de uma chave órfã é pior do que o codex descreveu (ERRO #2)

O caminho real da chave do dict (MEASURED):
```
common/BUILD.bazel: target_configs["kernel_aarch64"]["system_trusted_key"]
  → common_kernels.bzl:547-556  _get_target_config: target_config = dict(target_configs[...])  # copia VERBATIM
  → common_kernels.bzl:559-566  _define_common_kernel(name=..., **target_config)
  → common_kernels.bzl:612-639  assinatura EXPLÍCITA, SEM **kwargs
```
Logo: adicionar `"system_trusted_key"` ao dict do BUILD.bazel **sem** patchar o macro não é um "no-op silencioso" (o texto do CODEX5 sugere que a chave "não chegaria"); é **`TypeError: _define_common_kernel() got an unexpected keyword argument 'system_trusted_key'`** — a análise do Bazel quebra alto e imediatamente. Melhor para debug, pior para o texto do codex. MEASURED pela leitura da assinatura (sem `**kwargs`) e de `_get_target_config` (cópia literal).

### 1.4 Patch CORRIGIDO — `research/system_trusted_key.patch` (46 linhas, duas seções)

Escrevi o patch real contra o pinado e o entreguei como **`research/system_trusted_key.patch`**. Estrutura:
- **Parte 1 — kernel/build @4039bcfd** (`a/kleaf/common_kernels.bzl`), 4 pontos: doc da whitelist `:304`, assinatura de `_define_common_kernel` `:641` (`system_trusted_key = None):`), `json_target_config` `:668` (visível no `print_configs` de debug), e o repasse no `kernel_build(` `:746`.
- **Parte 2 — kernel/common @r12** (`a/BUILD.bazel`): `"system_trusted_key": "google_gki_ab13771415_modsign_cert.pem",` no dict do `kernel_aarch64` (após `module_implicit_outs`, `:158`) — **label direto de arquivo fonte**, no mesmo padrão upstream do `"android/abi_gki_aarch64"` (adversarial: o filegroup extra do codex `:google_gki_ab13771415_cert` é desnecessário; label direto é menos superfície). O `.pem` entra no repo via `cp ~/Documentos/mods/lake-kernel/research/google_gki_ab13771415_modsign_cert.pem common/` (comando documentado no header do patch).

Saídas coladas (os DOIS repositórios):
```
$ git -C /tmp/opencode4-work/build apply --check stk_part1.diff
exit: 0
$ git -C /tmp/opencode4-work/build apply stk_part1.diff
exit: 0
$ grep -n system_trusted_key kleaf/common_kernels.bzl
304:    - `system_trusted_key`
641:        system_trusted_key = None):
668:        system_trusted_key = system_trusted_key,
746:        system_trusted_key = system_trusted_key,

$ (scratch repo com common/BUILD.bazel@r12) git apply --check stk_part2.diff
exit: 0
$ git apply stk_part2.diff
exit: 0
$ grep -n -A1 system_trusted_key BUILD.bazel
158:        "system_trusted_key": "google_gki_ab13771415_modsign_cert.pem",
```
`git diff --stat` no clone: `kleaf/common_kernels.bzl | 6 +++++-  (5 insertions, 1 deletion)`.

### 1.4.1 Como aplicar o arquivo COMBINADO (cada seção no SEU checkout)

O arquivo único tem as duas seções com raízes de repo diferentes (`kleaf/common_kernels.bzl` = checkout de kernel/build; `BUILD.bazel` = checkout de kernel/common). `git apply` direto num repo que só tem metade dos alvos falha ("patch does not apply" — testado). Uso correto, com saída colada (re-teste do zero):

```
$ git -C <checkout de kernel/build @4039bcfd> apply --include='kleaf/common_kernels.bzl' system_trusted_key.patch
check exit: 0 / apply exit: 0  → 4 ocorrencias no arquivo
$ git -C <checkout de kernel/common @r12>          apply --include='BUILD.bazel'            system_trusted_key.patch
check exit: 0 / apply exit: 0  → 1 ocorrencia no arquivo
```
Alternativa equivalente: partir o arquivo em dois (`awk` no header `--- a/`) — desnecessário dado o `--include`.

### 1.5 Starlark é válido? Validação manual + LIMITE declarado

**Limite (MEASURED):** `bazel` e `buildifier` AUSENTES no host (`command -v` → nada) — não houve parse mecânico do Starlark. Validação manual feita:
1. **Attr aceito por `kernel_build`?** SIM — kwarg `:118`, consumido `:595` (repassado a `kernel_config`, attr `:534-538` `allow_single_file=True`; string-label de arquivo resolve no pacote `common`, mesmo padrão dos labels existentes). 3 abordagens: (a) assinatura `kernel_build.bzl:118`; (b) doc `api_reference/kernel.md:1207`; (c) `kernel_config.bzl:161/354/534` — três arquivos independentes descrevem o mesmo pipeline.
2. **A label chega como?** `target_configs` (string) → cópia verbatim → kwargs → `kernel_config` attr `attr.label` → `ctx.file.system_trusted_key` → `--set-str SYSTEM_TRUSTED_KEYS <basename>` + `rsync -aL` para `${OUT_DIR}/<basename>` → `certs/Makefile:31` resolve o prerequisite relativo no objtree (o rsync do kleaf existe exatamente para isso).
3. **Sintaxe:** paridade de `{}` intacta; os parênteses do arquivo são 248/247 **no ORIGINAL** (conteúdo de string — verificado comparando original vs editado: idêntico 248/247, ou seja, o desbalanço é pré-existente e cosmético ao meu contador ingênuo, não erro do patch).
**UNVERIFIED restante:** parse Bazel real (`bazel build //common:kernel_aarch64_print_configs` no checkout do common pós-cp do pem) — a fazer no dia do build; o `print_configs` mostraria a chave no JSON de debug (inseri a linha no `json_target_config` para isso).

---

## §2. Semântica do certificado no r12 — citações coladas

**`certs/Kconfig:56-63`** (MEASURED, r12):
```
config SYSTEM_TRUSTED_KEYS
	string "Additional X.509 keys for default system keyring"
	help
	  If set, this option should be the filename of a PEM-formatted file
	  containing trusted X.509 certificates to be included in the default
	  system keyring. Any certificate used for module signing is implicitly
	  also trusted.
```
E `:65-67`: DER `.x509` solto no build dir **não é mais suportado** — PEM é o formato.

**`certs/Makefile:29-32`** — resolução por basename (é por isso que o rsync do kleaf cópia para `${OUT_DIR}/`):
```
$(obj)/system_certificates.o: $(obj)/x509_certificate_list
$(obj)/x509_certificate_list: $(CONFIG_SYSTEM_TRUSTED_KEYS) $(obj)/extract-cert FORCE
	$(call if_changed,extract_certs)
```
`FORCE` ⇒ re-extraído toda build (sem staleness). `:85-88`: `extract-cert` é hostprog com `libcrypto` (liga direto com o furo F0-2 do codex: sem `openssl pkg-config` no host, o build morre AQUI).

**`certs/system_certificates.S:9-15`** — ORDEM e conteúdo final (MEASURED):
```
system_certificate_list:
__cert_list_start:
__module_cert_start:
	.incbin "certs/signing_key.x509"      ← chave efêmera do build (PRIMEIRO)
__module_cert_end:
	.incbin "certs/x509_certificate_list" ← SYSTEM_TRUSTED_KEYS (SEGUNDO)
__cert_list_end:
```
**Resposta §2:** com o patch, o Image final contém **DOIS certs** — efêmera nova primeiro, cert do Google (ab13771415) depois — na ordem acima, ambos carregados em `.builtin_trusted_keys`:

**`certs/system_keyring.c:279-296`** (MEASURED):
```
static __init int load_system_certificate_list(void)
...
#ifdef CONFIG_MODULE_SIG
	p = system_certificate_list;
	size = system_certificate_list_size;   ← lista INTEIRA (inclui o cert de módulo)
#else
	p = system_certificate_list + module_cert_size;  ← sem MODULE_SIG pula o 1º
#endif
	return x509_load_certificate_list(p, size, builtin_trusted_keys);
}
late_initcall(load_system_certificate_list);
```
Config stock tem `MODULE_SIG=y` ⇒ lista inteira (os dois certs) vai para `builtin_trusted_keys`.

**`kernel/module/signing.c:50-75`** — o caminho de verificação (MEASURED):
```
mod_verify_sig(...) → return verify_pkcs7_signature(mod, modlen, mod+modlen, sig_len,
                    VERIFY_USE_SECONDARY_KEYRING, VERIFYING_MODULE_SIGNATURE, NULL, NULL);
```
**`certs/system_keyring.c:396-419`** — o corpo do `verify_pkcs7_signature` que o CODEX5 declarou "não localizado" (ERRO #4: é localizável, está AQUI; `EXPORT_SYMBOL_GPL`): parseia o PKCS#7 e chama `verify_pkcs7_message_sig(data, len, pkcs7, trusted_keys, usage, ...)`. A resolução do keyring `(void*)1UL` ("all trusted keys") fica em `verify_pkcs7_message_sig`/`pkcs7_verify.c:311+`; com `SECONDARY_TRUSTED_KEYRING=n` no config stock (MEASURED no audit), só há builtin — que agora contém o cert do Google. **⇒ sig_ok=true para os módulos GKI do Google: SIM** (3 vias: fonte, openssl §2.3, consistência empírica do stock).

**`certs/extract-cert.c:152-172`** (MEASURED) — PEM, quantos certs: o caminho de arquivo faz `while(1){ PEM_read_bio_X509(...) ; write_cert(...) }` — **aceita PEM com um OU mais certs**; arquivo sem PEM válido → erro (DER puro não passa nesse caminho). O PEM da research tem exatamente **1** cert (`grep -c BEGIN CERTIFICATE` = 1, colado §2.3).

### 2.3 O PEM do Google é válido para isso? SIM — openssl colado (MEASURED)

```
$ openssl x509 -in research/google_gki_ab13771415_modsign_cert.pem -noout -text
Certificate:
    Data: Version 3 (0x2)
    Serial Number: 1c:f8:3e:80:1a:04:dd:7f:e6:04:a5:15:bc:3d:fd:fa:6d:0b:17:21
    Signature Algorithm: sha1WithRSAEncryption
    Issuer: CN=Build time autogenerated kernel key
    Validity
        Not Before: Jul 11 23:54:39 2025 GMT
        Not After : Jun 17 23:54:39 2125 GMT        ← -days 36500 do certs/Makefile:48
    Subject: CN=Build time autogenerated kernel key
    Public Key Algorithm: rsaEncryption (4096 bit)
    X509v3 extensions:
        X509v3 Basic Constraints: critical
            CA:FALSE
        X509v3 Key Usage:
            Digital Signature          ← atende a regra "digitalSignature" citada na tarefa
        X509v3 Subject Key Identifier: BD:F7:0E:22:...
$ grep -c "BEGIN CERTIFICATE" <pem>
1
```
**2º método independente (MEASURED, python):** PEM→DER = 1357 bytes, `sha256=76fbdfd13f6ba612756eae36e99f88508fa3202aa35117704c26d55a99cc72a1` — **idêntico ao fingerprint do fato 38 do plano** — e o DER ocorre byte a byte no `official-ab13771415/Image` em `offset 0x2089b00`. Ou seja: o PEM da research É o cert embutido no Image oficial. (Nota honesta: meu carve heurístico por `30 82` errou o offset/length — descartado; a busca exata por `img.find(der)` é a prova.)

---

## §3. O que pode dar errado — análise adversarial (com fontes)

### 3.1 ERRO #2 do CODEX5 (o mais grave na argumentação): sem o cert, módulo assinado NÃO morre em "verificação fatal" — morre no Protected Exports

`kernel/module/signing.c` (r12, MEASURED): o switch do `module_sig_check` trata **-ENODATA (unsigned), -ENOPKG, -ENOKEY (chave ausente) como NÃO-FATAIS** quando `!FORCE` — e com `CONFIG_MODULE_SIG_PROTECT=y` o final é `return 0` (o bloco `#ifndef CONFIG_MODULE_SIG_PROTECT / lockdown / #else / return 0 / #endif` está colado na saída acima, linhas 117-132 do arquivo). Ou seja: **kernel novo sem o cert do Google ⇒ os 79 módulos GKI do system_dlkm CARREGAM mesmo assim** (ENOKEY → return 0, `sig_ok=false`, e sem taint — `main.c:2085-2091` suppress a mensagem de taint sob PROTECT).

O que os mata de verdade é a classificação `is_vendor_module = !mod->sig_ok` (`kernel/module/main.c:1165`, MEASURED) somada ao check de exportação:
```
kernel/module/main.c:1364-1371 (MEASURED)
	if (!mod->sig_ok && gki_is_module_protected_export(kernel_symbol_name(s))) {
		pr_err("%s: exports protected symbol %s\n", ...);
		return -EACCES;
	}
```
E os exports que os módulos do lake precisam ESTÃO na lista `android/abi_gki_protected_exports_aarch64` (r12, MEASURED): `arc4_crypt`/`arc4_setkey` (:24-25) e `rfkill_alloc`, `rfkill_blocked`, `rfkill_destroy`, `rfkill_find_type`, `rfkill_get_led_trigger_name`, `rfkill_init_sw_state` (:363-368). Logo, sem o cert: `libarc4.ko`/`rfkill.ko` (e todo GKI module com export protegido) **falham com "exports protected symbol"** ⇒ vendor wlan/bt perdem `rfkill_*`/`arc4_*` ⇒ rádios mortos/degradação no boot. **Conclusão do codex (cert necessário): CORRETA; mecanismo citado ("assinado-inválido → erro fatal"): ERRADO** — e com consequência prática: o dmesg de diagnóstico esperado é `exports protected symbol`, não `module verification failed`. (O lado da importação — `main.c:1165-1173`, colado — até PERMITE vendor importar de módulo !sig_ok, "symbols exported by other vendor modules"; o kill é só pelo lado da exportação.)

### 3.2 SHA1 — SEM problema (3 fontes)

1. **`crypto/asymmetric_keys/public_key.c:83-99`** (MEASURED): o branch RSA/pkcs1 constrói `pkcs1pad(rsa,<hash>)` para **qualquer** hash — a allowlist rígida sha1/224/256/384/512 (`:116-124`) é do branch **ECDSA**. Assinatura de módulo sha1 verifica.
2. **pkcs7_verify.c** (MEASURED): `crypto_alloc_shash(sinfo->sig->hash_algo)` (:43) — sem blocklist de sha1 no caminho de módulo.
3. **Empírico:** o kernel STOCK contém exatamente este cert sha1-signed (§2.3) e o aparelho boota com os módulos GKI verificando contra ele (fatos 18/24/38 do plano).
E o cert em si: trust vem da **inclusão** (incbin + `x509_load_certificate_list`) — a auto-assinatura sha1 do cert nunca é verificada nesse caminho (não há chamada a verify no loader; `x509_public_key.c` sem nenhum uso de validade/tempo no caminho — grep por `not_before|not_after|validity|expire` = 0 hits, MEASURED).

### 3.3 Validade/tempo — checagem existe, mas NÃO contra o relógio

**`crypto/asymmetric_keys/pkcs7_verify.c:336-351`** (MEASURED, colado):
```
	/* Check that the PKCS#7 signing time is valid according to the X.509
	 * certificate.  We can't, however, check against the system clock
	 * since that may not have been set yet and may be wrong.
	 */
	if (test_bit(sinfo_has_signing_time, &sinfo->aa_set)) {
		if (sinfo->signing_time < sinfo->signer->valid_from ||
		    sinfo->signing_time > sinfo->signer->valid_to) {
			pr_warn("Message signed outside of X.509 validity window\n");
			return -EKEYREJECTED;
		}
	}
```
Módulos: o par (cert Google + módulos assinados no build ab13771415 em 2025-07-11 ~23:54+) é internamente consistente — o stock funciona com esse par (MEASURED), portanto signingTime ∈ janela. Relógio do aparelho: irrelevante para módulos (a checagem é contra o atributo autenticado do PKCS#7). notBefore 2025-07-11 < hoje < notAfter 2125: dentro da janela de qualquer forma. **SEM problema.** Nuance documentada: se algum dia re-assinarmos módulos com um cert novo, o `sign-file` grava signingTime do relógio de build — manter cert com notBefore ≤ momento da assinatura (o Makefile já garante: cert nasce no mesmo build em que assina).

### 3.4 KeyUsage / basicConstraints — atende e não é checado no caminho de módulo

Cert tem `Key Usage: Digital Signature` + `CA:FALSE` (§2.3 colado) — atende a regra citada. No caminho `pkcs7_find_key` → `public_key_verify_signature` (pkcs7_verify.c:332/348, MEASURED) **não há gate de keyUsage**; a menção a "usage restriction" em pkcs7_verify.c:379 é sobre keyring restrictions (ex.: `restrict_link_by_digsig_builtin`, system_keyring.c:55-70) — aplicam-se a ADIÇÕES futuras ao keyring, não à verificação de módulo contra builtin.

### 3.5 MODULE_SIG_KEY autogerada × SYSTEM_TRUSTED_KEYS — coexistem por design

`certs/Makefile:43-53` gera a efêmera SÓ quando `CONFIG_MODULE_SIG_KEY == "certs/signing_key.pem"` (default stock); `system_certificates.S:12-14` embute as DUAS; `load_system_certificate_list` com `MODULE_SIG=y` carrega tudo em builtin. **`make mrproper`/clean NÃO toca o .pem**: ele vive na árvore-fonte (`common/`) e é re-copiado a cada build pelo setup do kleaf (`kernel_config.bzl:354-364`, dentro de `extra_restore_outputs_cmd`) — o .config aponta só o basename e o kbuild resolve no objtree (Makefile:31). A chave efêmera muda a cada build (inevitável, fato 24/Q2 do plano — aceito como único delta do G-REPRO).

### 3.6 Riscos residuais que EU acrescento (o codex não cobriu)

- **UNVERIFIED (parse Bazel real):** o patch passa no `git apply` e na leitura manual, mas só `bazel build //common:kernel_aarch64_print_configs` (pós-cp do pem) prova o grafo. Fazer isso ANTES do build completo.
- **Efeito colateral inofensivo:** o `.pem` na raiz de `common/` entra no glob `common_kernel_sources` (o glob só exclui `BUILD.bazel`, `*.bzl`, `android/*`) — arquivo duplicado na árvore de build; sem efeito funcional (o caminho oficial é o rsync do kleaf), mas registrar no commit.
- **`gki_protected_modules` (r12):** fetch do arquivo falhou (não existe em `android/gki_protected_modules` neste tag) — a lista de módulos protegidos é o filegroup `:gki_aarch64_protected_modules` do BUILD.bazel; UNVERIFIED seu conteúdo. Não altera a conclusão §3.1 (o kill depende da lista de EXPORTS, que obtive por completo — 506 linhas).
- **0600 do .pem no repo (mencionado pelo codex):** irrelevante — a chave PÚBLICA não é secreta; permissões normais de repo bastam.

---

## §4. Os 30 furos do CODEX5 — os 10 que MAIS ameaçam + a ação resolve?

| # | Furo | Ameaça | Ação proposta resolve? |
|---|---|---|---|
| H11 | G-REPRO `sha256==` impossível (chave efêmera embutida) | trava o pipeline inteiro | **SIM** — trocar por config-diff vazio + `vmlinux.symvers` idêntico + System.map comparável (já redefinido no plano v2, Q2) |
| H20 | F6 usa `su` mas kernel novo pode não ter root (Magisk mora no init_boot — KSU-Next#731 + fato 48: `init_boot_b` NÃO bate com o descriptor e boota ⇒ Magisk está lá) | verificação pós-flash inválida | **SIM, se** re-patchear o init_boot do slot de teste OU definir verificação sem root; exigência: localizar o Magisk ANTES de F6 |
| H17 | AVB `--algorithm NONE` vs stock `SHA256_RSA2048` (fato 32) | bootloop | **PARCIAL/RESOLVIDO empiricamente** — fato 48 mediu orange tolerando hash divergente (init_boot_b Magisk); manter NONE + rollback 0 + flags 0 e nunca `--disable-verification` |
| H12 | 80 GB exigidos vs 51 GB livres | sem build não há projeto | **SIM** — cache externo/limpeza/partial-clone (o Claude Code já validou "cabe em 51 GB" na sessão de hoje — ver maestri) |
| H5 | cópia externa do backup pendente (disco 90%) | perda total por falha de disco | **SIM** — rsync + `sha256sum -c` externo; AÇÃO URGENTE antes de qualquer flash |
| H7 | inventário 215/217/557 ambíguo | gates sobre contagem errada | **SIM** — planilha única (meu audit: 370 únicos/557 arquivos .ko — `audit/modules/modules.csv`) |
| H2 | libssl/openssl ausente da lista F0 | build morre em `certs/` (agora PROVADO: `certs/Makefile:85-88` linka `extract-cert` contra libcrypto) | **SIM** — e agora com a citação exata de onde quebra |
| H22 | pânico pré-userspace = sem fallback automático (fato 11) | brick suave sem via de volta | **PARCIAL** — aceitar o risco com flash SEMPRE no slot inativo + rollback manual imediato + pstore como testemunha |
| H3 | RAM 15 GB (critério 12 GB infactível) | OOM no meio do LTO | **SIM** — `--jobs=4` + swap; medir em build de controle |
| H10 | só 3/36 projetos pinados conferidos | reprodutibilidade furada | **SIM** — loop de verify sobre o manifest inteiro (35 min) |

Os demais (H1 repo-Arch, H4 cache invisível, H6 vbmeta_vendor truncado **[JÁ RESOLVIDO: meu audit refez, 8 MB, hash OK]**, H8/H9 repo init/detached, H13 fast×ci, H14 1573×2309 **[JÁ RESOLVIDO: 2309 é o número do gate estendido, fato 23]**, H15/H16, H18/H19, H21, H23/H24, H25/H26, H27/H28, H29/H30) ou já foram resolvidos por medições posteriores, ou têm ação adequada, ou são de severidade menor.

---

## §5. Erros achados no CODEX5 (consolidado) + veredito

1. **Patch literal inaplicável** ("No valid patches in input", exit 128) — substituído por `research/system_trusted_key.patch` que aplica limpo nos dois repos (saídas coladas §1.4). [MEASURED]
2. **Mecanismo de falha sem cert errado**: "assinado-inválido → erro fatal" — na real, `-ENOKEY` é não-fatal sob `MODULE_SIG_PROTECT` (signing.c:117-132); o kill real é `-EACCES` de **protected export** (main.c:1364) com `rfkill_*`/`arc4_*` confirmados na lista (§3.1). Conclusão (cert obrigatório) correta; justificativa corrigida. [MEASURED]
3. **Modo de falha da chave órfã no macro**: seria `TypeError` alto na análise, não no-op silencioso (§1.3). [MEASURED]
4. **"verify_pkcs7_signature não localizado"**: está em `certs/system_keyring.c:396-419` — agora citado (§2). [MEASURED]
5. **Filegroup desnecessário** no BUILD.bazel — label direto segue o padrão upstream (`"android/abi_gki_aarch64"`). [MEASURED]
6. **B.1 não analisou o `MODULE_SIG_PROTECT`** — o Kconfig (kernel/module/Kconfig:232-243) + main.c:1165-1173/1364-1371/2084-2092 mudam todo o raciocínio de "por que o cert é necessário" (§3.1). [MEASURED]
7. **Menor:** o CODEX5 B.2 diz "basename copiado para out_dir" sem citar o mecanismo (`extra_restore_outputs_cmd`/`post_setup_deps`, kernel_config.bzl:353-364) — detalhe agora documentado. [MEASURED]

**Veredito:** a DIREÇÃO do CODEX5 está correta (attr existe, macro não repassa, cert é necessário, KMI intocada) — a mecânica estava 70% certa e 30% imprecisa; o patch entregue aqui é o que existe de aplicável.

---

## §6. Auto-revisão (rótulos e limites)
- Todos os FACT têm linha citada ou saída colada; medições críticas refeitas por 2 métodos (DER: openssl + python-find no Image; patch: `--check` + `apply` em dois repos; attr: 3 arquivos independentes do kleaf).
- Ficam UNVERIFIED: parse Bazel real (`print_configs`), conteúdo de `:gki_aarch64_protected_modules`, execução do `verify_modsig.sh` do codex (não o executei — escrevi verificação própria; a evidência do fato 38/45 do plano já cobre o positivo/negativo com re-execução do próprio dj).
- Nada flasheado; nenhum pacote instalado; `audit/`, `backup-*`, `official-*` intactos; trabalho todo em `/tmp/opencode4-work`; arquivos criados: `research/OPENCODE4_review_codex5.md` + `research/system_trusted_key.patch`.
