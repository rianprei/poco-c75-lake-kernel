# CODEX5_build_signing — FMEA do plano v2 (cega) + prova SYSTEM_TRUSTED_KEYS no fonte

> Data: 2026-10-05. Parte A cega (não li AUDIT/FMEA_* — inexistentes no momento). Parte B no fonte r12 (`5a0ffb44...`) e kernel/build (`4039bcfd...`) via `?format=TEXT`+base64. Nada executado de terceiros; sem adb/flash; audit/backup/official intactos. Script novo meu: `research/verify_modsig.sh` (tabs), testado abaixo.
> Legenda: `FACT` (URL/saída) / `MEASURED` (saída colada) / `INFERRED` / `UNVERIFIED` / `UNKNOWN`. 3 abordagens independentes por ponto crítico; medições críticas refeitas por 2 métodos.

## PARTE A — FMEA cega das fases F0–F11 (severidade: brick > bootloop > dado > funcional > cosmético)

Formato por falha: `modo | sev | prob | detectar-antes | mitigação | evidência-de-passagem`.

### F0 host
| # | modo de falha | sev | prob | detectar antes | mitigação | evidência |
|---|---|---|---|---|---|---|
| F0-1 | pacote `repo` não existe com esse nome no Arch/CachyOS (lista do plano é Ubuntu-centrica) | funcional | alta | `pacman -Si repo git base-devel python libelf ncurses bc openssl 2>&1` antes de instalar | usar AUR (`git-repo`?) ou script Google; documentar nomes exatos | saída do `pacman -Si` por pacote |
| F0-2 | `libssl/openssl + pkg-config` ausentes → `certs/extract-cert` (HOSTCFLAGS libcrypto) falha no meio do build | funcional | alta | `pkg-config --libs libcrypto` | incluir `openssl pkg-config` na lista F0 | saída do pkg-config |
| F0-3 | critério `free -g ≥ 12GB` infactível (host 15 GB total, ~2.5 livres, swap 8 GB usado — MEASURED) | funcional | alta | `free -g` (já medido) | critério realista: RAM+swap e `--jobs=4`; medir OOM em build de controle | `free -h` + build log sem OOM |
| F0-4 | `<HOME>/.cache/bazel` + ccache fora da conta de disco (soma 10–30 GB invisíveis) | funcional | média | `du -sh <HOME>/.cache/bazel <workdir>` | `--disk_cache` externo + teto de ccache | `df -h` antes/depois |

### F1 backup
| F1-1 | cópia externa pendente = ponto único de falha (disco 90%) | dado | média | `df -h` + checar pendrive | rsync + `sha256sum -c` fora do disco | `sha256sum -c` OK externo |
| F1-2 | `vbmeta_vendor_a` truncado sem caminho de recuperação | dado/funcional | média | `avbtool info_image` no arquivo | re-dump com `dd` + hash vs aparelho | `info_image` OK + hash igual |
| F1-3 | ambiguidade de inventário: `audit/SHA256SUMS` vs `backup-2026-10-05/SHA256SUMS.log`, 215 vs 210+7=217 vs 557 módulos | dado | alta | reconciliar contagens (ver H-inv) | planilha única de 42 itens + módulos | 0 mismatch, 0 missing |

### F2 checkout
| F2-1 | duplo `repo init` (`-b` depois `-m pinned.xml`) pode falhar/ignorar o pin (marcado UNVERIFIED no próprio plano) | funcional | alta | testar em dry-run ou fazer init único com `-m` | fluxo em comando único documentado | `repo manifest -r` mostra revisões do XML |
| F2-2 | `git checkout <sha>` deixa `common/` detached → `repo sync` futuro reseta ou falha | funcional | média | `git -C common status` | anotar: nunca `repo sync` após checkout; ou `git checkout -b` | `rev-parse HEAD` == sha + `repo status` limpo |
| F2-3 | só 3/36 projetos verificados (faltam prebuilts/build-tools/bazel_common_rules) | funcional | média | estender verify aos 36 | script de loop sobre `manifest_13771415.xml` | 36/36 OK |

### F3 build controle
| F3-1 | critério G-REPRO `sha256 == a023b4...` é IMPOSSÍVEL (chave efêmera embutida; Q2 do próprio plano admite) — gate que nunca passa | funcional | certa | ler Q2/fato 24 | trocar por: config-diff vazio + symvers idêntico + System.map (ver B.4) | symvers `diff` vazio |
| F3-2 | exige `df ≥ 80 GB`, host tem 51 GB — fase ordenada sem resolver armazenamento | funcional | certa | `df -h` (medido) | disco externo/limpeza autorizada ANTES de F2 | `df -h ≥ 80G` |
| F3-3 | `--config=fast` vs oficial `--config=android_ci` (stamp/RBE) — deltas não documentados | funcional | média | comparar `.config` + `strings` | build de controle com `android_ci` se possível, ou documentar deltas | diff de config explicável |

### F4 gate CRC
| F4-1 | números inconsistentes: fato 20 diz 1573, fato 23/plano diz 2309 símbolos | funcional | certa | confrontar `vendor_required_crcs.txt` vs gate | unificar contagem (única fonte) | `wc -l` + gate PASS |
| F4-2 | path `research/gate_kmi_crc.sh` ambíguo (lake-kernel/research vs tabs research) | funcional | média | `ls` nos dois | path absoluto no plano | script encontrado + executado |
| F4-3 | 7 módulos 6.6.30 "outra árvore" sem procedimento | funcional | média | listar os 7 + fornecedores | árvore/segmento separado ou waiver assinado | gate dos 7 PASS |

### F5 repack
| F5-1 | DOIS métodos AVB contraditórios (`--algorithm NONE` vs preservar `SHA256_RSA2048` do stock, fato 32) | bootloop | alta | `avbtool info_image boot_b.img` (já medido: SHA256_RSA2048) | decidir UM método; baseline com stock primeiro | `info_image` novo == stock salvo hash |
| F5-2 | BASELINE exige `fastboot boot` (Q3 UNKNOWN) — dependência circular | bootloop | média | teste Q3 com stock antes | se sem `boot`, baseline = flash slot inativo direto | resultado Q3 registrado |
| F5-3 | regra de padding/alinhamento 4096 + `kernel_size@8` sem teste automatizado | bootloop | média | `unpack_bootimg` no novo.img | script de repack com asserts de tamanho | asserts OK + `unpack_bootimg` OK |

### F6 teste real
| F6-1 | verificações usam `su -c` mas boot novo SEM Magisk = sem root (onde mora o Magisk? init_boot vs boot — plano não prova) | funcional | alta | achar onde está o Magisk (`init_boot`? `boot`?) antes de flashar | manter root no teste (patch no init_boot intacto?) ou verificações sem su | `su` funciona OU plano B de verificação |
| F6-2 | `wc -l /proc/modules ≈ 429` é frágil (varia com estado) | cosmético | alta | baseline com stock (vários boots) | faixa, não número exato | faixa documentada |
| F6-3 | panic antes do userspace = bootctl nunca marca success = SEM fallback automático (fato 11 admite, F6 não condiciona) | bootloop | média | só teste com console? sem UART = aceitar | janela de observação + rollback manual imediato | `slot-successful:a` ou rollback executado |

### F7 estabilidade
| F7-1 | "temperatura estável" sem números (sem baseline termal do stock) | funcional | média | medir baseline stock primeiro | limites em °C por zona + duração | log thermal + 0 panic |
| F7-2 | `stress-ng` precisa instalar (regra: sem instalar sem avisar) | funcional | média | `command -v stress-ng` | loop shell puro como fallback | método registrado |

### F8 review
| F8-1 | revisor não designado, loop FIX→F3 sem teto (retrabalho infinito) | funcional | média | nomear revisor + nº máx de voltas | teto de 2 voltas, depois replanejar | review assinado com saída |

### F9 promoção
| F9-1 | bookkeeping de slots confuso (F6 usa A; F9 fala "flashar em boot_b? ... manter A novo e B stock") | bootloop | média | reescrever F9 com tabela de slots | A=novo-estável, B=stock até decisão explícita | `getvar all` registrado |
| F9-2 | sem critério de promoção (dias? métricas?) | funcional | média | definir: N dias + 0 panic + bateria OK | checklist datado | checklist assinado |

### F10 customização
| F10-1 | sem pin de versão/procedimento KSU (só "Golden Rule") | funcional | alta | exigir tag/commit (ex.: ReSukiSU `fa8311f6`) | F10 só começa com pin + re-gate F4 | pin registrado + F4 PASS |
| F10-2 | coexistência Magisk×KSU não resolvida (conflito de mounts/denylist) | bootloop/funcional | alta | decidir UM root antes | remover/desativar o outro; testar | um root ativo, outro ausente |

### F11 OC
| F11-1 | OPP vive em vendor (CPU_DVFS.ko) + DT em vendor_boot/dtbo — kernel GKI quase não entrega OC | funcional | certa | ler `audit/dts` + vendor antes | redefinir F11 como "undervolt via vendor?" ou remover | análise DTB registrada |
| F11-2 | mexer em vendor_boot/dtbo arrisca o recovery (vive lá?) | bootloop | média | mapear partições de recovery | nunca tocar sem backup+prova de recovery alternativo | mapa registrado |

### FUROS reais (≥15) e TOP-5
H1 pacote `repo` Arch UNVERIFIED (F0-1) · H2 libssl ausente da lista (F0-2) · H3 critério RAM infactível (F0-3) · H4 cache bazel fora da conta (F0-4) · H5 cópia externa pendente (F1-1) · H6 vbmeta_vendor truncado sem recovery (F1-2) · H7 inventário ambíguo 215/217/557 (F1-3) · H8 duplo `repo init` UNVERIFIED (F2-1) · H9 detached HEAD (F2-2) · H10 só 3/36 projetos verificados (F2-3) · **H11 G-REPRO sha impossível vs Q2 (F3-1)** · H12 80 GB exigidos vs 51 GB (F3-2) · H13 fast vs android_ci (F3-3) · H14 1573 vs 2309 (F4-1) · H15 path do gate ambíguo (F4-2) · H16 6.6.30 sem procedimento (F4-3) · **H17 AVB NONE vs SHA256_RSA2048 (F5-1)** · H18 baseline depende de Q3 UNKNOWN (F5-2) · H19 padding sem asserts (F5-3) · **H20 su sem root pós-flash (F6-1)** · H21 ≈429 frágil (F6-2) · H22 sem fallback pré-userspace (F6-3) · H23 sem baseline termal (F7-1) · H24 revisor sem teto (F8-1) · H25 slots confusos (F9-1) · H26 sem critério de promoção (F9-2) · H27 KSU sem pin (F10-1) · H28 Magisk×KSU (F10-2) · H29 OC impossível via GKI (F11-1) · H30 vendor_boot=recovery? (F11-2).
**TOP-5 que mais ameaçam "zero falha": H11 (gate impossível trava o pipeline) · H20 (verificação F6 inválida sem root) · H17 (footer errado = bootloop certo) · H12 (sem disco não há build) · H7 (gates sobre inventário errado).**

## PARTE B — prova no fonte de que o cert extra resolve (3 abordagens por ponto)

### B.1 Como SYSTEM_TRUSTED_KEYS combina com a chave autogerada (linhas citadas, r12)

- `FACT` (`certs/system_certificates.S`, r12 — MEASURED via `?format=TEXT`):
  ```
  system_certificate_list:
  __module_cert_start:
      .incbin "certs/signing_key.x509"      # chave efêmera do build (MODULE_SIG_KEY)
  __module_cert_end:
      .incbin "certs/x509_certificate_list"  # certs de CONFIG_SYSTEM_TRUSTED_KEYS
  __cert_list_end:
  ```
- `FACT` (`certs/Makefile`, r12): `$(obj)/system_certificates.o: $(obj)/x509_certificate_list` + `$(obj)/system_certificates.o: $(obj)/signing_key.x509` — o objeto final depende dos DOIS; `x509_certificate_list: $(CONFIG_SYSTEM_TRUSTED_KEYS) ... extract-cert` (linhas do Makefile lidas).
- `FACT` (`certs/system_keyring.c`, `load_system_certificate_list`, fim do arquivo lido): com `CONFIG_MODULE_SIG`, carrega `system_certificate_list` **inteira** (`p = system_certificate_list; size = system_certificate_list_size`) em `builtin_trusted_keys` (`.builtin_trusted_keys`) via `late_initcall`. Sem `MODULE_SIG`, pula o 1º cert (`+ module_cert_size`).
- `FACT` (`certs/Kconfig`, `SYSTEM_TRUSTED_KEYS help`): "filename of a PEM-formatted file containing trusted X.509 certificates to be included in the default system keyring. Any certificate used for module signing is implicitly also trusted." + (`Documentation/admin-guide/module-signing.rst`, r12, linhas 113-118/135-144/182-193): chave default auto-gerada em `certs/signing_key.pem` se inalterada; certs extras entram "in the system keyring by default"; anel visível `.builtin_trusted_keys`.
- `FACT` (`kernel/module/signing.c`, `mod_verify_sig`): verifica com `verify_pkcs7_signature(..., VERIFY_USE_SECONDARY_KEYRING, VERIFYING_MODULE_SIGNATURE, ...)`; com `CONFIG_MODULE_SIG_FORCE` ausente + `CONFIG_MODULE_SIG_PROTECT=y` (stock), `sig_enforce=false` e unsigned → `return 0` (não bloqueia); assinado-inválido → erro fatal. `include/linux/verification.h:14-18` (r12): `VERIFY_USE_SECONDARY_KEYRING` = "both builtin trusted keys and secondary trusted keys should be used".
- Abordagem 1 (fonte): lista única → builtin → verificação usa builtin (+secondary se existir; stock tem `SECONDARY=n`, MEASURED no config.stock) ⇒ **conclusão: módulo assinado pelo cert Google com esse cert em SYSTEM_TRUSTED_KEYS tem sig_ok=true. Resposta: sim.**
- Abordagem 2 (openssl, §B.4): `can.ko` oficial valida contra o cert garimpado do Image oficial (PASS colado abaixo).
- Abordagem 3 (fingerprint independente): PKCS#7 do `can.ko` declara `issuer CN=Build time autogenerated kernel key` = subject do cert do Image; serial `1CF83E80...` idêntico; DER garimpado == PEM da pesquisa (sha256 `c445fc53...` iguais).
- Limite honesto: o corpo exato do fallback secondary→builtin (`verify_pkcs7_signature`) não foi localizado nos TUs vasculhados (`crypto/asymmetric_keys/*`, `certs/*` — listagens coladas na análise); a conclusão se sustenta pelas 3 vias acima + `verification.h:14-18`. Se `SECONDARY` estivesse ligado haveria keyring extra linkado ao builtin (system_keyring.c: link `secondary→builtin`); desligado, só builtin — caso do stock.

### B.2 Kleaf: como passar o cert (kernel/build @4039bcfd, pin do manifest) + PATCH

- `FACT` (`kleaf/impl/kernel_build.bzl:117-118,396-401,594-595` @4039bcfd): `kernel_build()` aceita `module_signing_key = None, system_trusted_key = None` ("label referring to a trusted system key ... dynamic setting of CONFIG_SYSTEM_TRUSTED_KEY from Bazel").
- `FACT` (`kleaf/impl/kernel_config.bzl:142-166,354-364,530-535` @4039bcfd): `_config_keys` faz `scripts/config --set-str SYSTEM_TRUSTED_KEYS <basename>`; pós-setup `rsync -aL <label> ${OUT_DIR}/<basename>` (label = arquivo no repo ⇒ sandbox-safe). Docstring avisa: path embutido vaza via `strings`/config (com basename, vazamento mínimo).
- `FACT` (`kleaf/common_kernels.bzl` @4039bcfd, `define_common_kernels`, chamada `kernel_build(` ~linha 707 SEM `system_trusted_key`): o macro NÃO repassa o atributo — confirmado por grep (só `defconfig_fragments` é repassado). Logo: fragmento `CONFIG_SYSTEM_TRUSTED_KEYS=...` sozinho NÃO basta (o arquivo não chegaria ao OUT_DIR; o Kbuild o procuraria no objtree). Jeitos comparados: (i) fragmento com path absoluto — funciona mas vaza path, quebra hermeticidade e reprodutibilidade entre máquinas; (ii) forward no macro + label — robusto, sandbox-safe, revisável. **Escolha: (ii).**
- PATCH exato (aplicar no checkout pinado; cert em `common/google_gki_ab13771415_cert.pem`, copiado do PEM da pesquisa):
```diff
--- a/build/kernel/kleaf/common_kernels.bzl
+++ b/build/kernel/kleaf/common_kernels.bzl   # @4039bcfd, na função que monta kernel_build (~l.619-745)
@@ defconfig_fragments / blocos de _kernel_build — acrescentar forward:
+        system_trusted_key = None,   # novo kwarg do wrapper (default None = comportamento atual)
         ... repassar em kernel_build(: system_trusted_key = system_trusted_key,
--- a/common/BUILD.bazel  (chamada define_common_kernels, entrada "kernel_aarch64"):
         "kernel_aarch64": {
+            "system_trusted_key": ":google_gki_ab13771415_cert",
             ... (resto idêntico; trim/strict/protected intactos)
--- a/common/BUILD.bazel  (novo filegroup junto ao de abi):
+filegroup(name = "google_gki_ab13771415_cert", srcs = ["google_gki_ab13771415_cert.pem"])
--- a/common/google_gki_ab13771415_cert.pem (novo, 0600 no commit é impossível — documentar no README do commit)
```
Comandos:
```bash
cp <lake-kernel>/research/google_gki_ab13771415_modsign_cert.pem common/google_gki_ab13771415_cert.pem
# aplicar o diff acima; depois:
tools/bazel build --jobs=4 --config=fast //common:kernel_aarch64_dist
grep '^CONFIG_SYSTEM_TRUSTED_KEYS' bazel-bin/common/kernel_aarch64_config/out_dir/.config
# esperado: CONFIG_SYSTEM_TRUSTED_KEYS="google_gki_ab13771415_cert.pem" (+ resto idêntico ao stock)
```
`UNVERIFIED` (sem build executado): nomes exatos de kwargs/linhas no macro podem variar ±; validar com `tools/bazel build //common:kernel_aarch64_config` e inspecionar `.config` antes do build cheio.

### B.3 Efeito em KMI/CRC e nas outras configs

- `SYSTEM_TRUSTED_KEYS` **NÃO altera CRC** (`INFERRED` do mecanismo genksyms provado em CODEX3 §2): DER em `.init.rodata` não entra na expansão de tipos de nenhum protótipo exportado; `vmlinux.symvers` deve sair idêntico (gate F4 prova). TRIM/strict/protected intactos (nenhum export novo; o patch não toca `kmi_symbol_list`). Único diff de config esperado vs stock: a linha `SYSTEM_TRUSTED_KEYS` (Q8 do plano). `MODULE_SIG_KEY` permanece `certs/signing_key.pem` (efêmera nova por build — inevitável e inofensiva: módulos vendor são unsigned e passam por `return 0`; GKI stock passam pelo cert extra).

### B.4 Prova offline antes de flashar — `research/verify_modsig.sh` (testado; saídas coladas)

Método (§script): garimpa DERs do Image (A) + fingerprint do signatário no PKCS#7 (B, independente) + `openssl cms -verify -binary` com `-certfile` (signatário; PKCS#7 do sign-file NÃO embute cert — descoberto ao depurar `signer certificate not found`) e `-CAfile`.
```
=== POSITIVO: can.ko oficial vs Image oficial ===
carved_valid=1
subject=CN=Build time autogenerated kernel key / serial=1CF83E80... / sha256 FP=76:FB:DF:D1:...
issuer (PKCS#7): CN=Build time autogenerated kernel key
PASS: <workdir>/modsig/can.ko validado por cert do Image
=== NEGATIVO: can.ko adulterado (1 byte) deve FALHAR ===
FAIL: nenhum cert do Image valida can_bad.ko
OK negativo: adulterado rejeitado como esperado
SELFTEST PASS (positivo PASS + negativo FAIL)
```
`MEASURED` extra (2º método de medição): DER garimpado == PEM da pesquisa (`c445fc53...` ambos); 2º módulo `hci_uart.ko` (181777 B, CI) também PASS. Para o Image NOVO, o gate é: script deve achar **2 certs** (efêmera nova + Google) e `can.ko`/`rfkill.ko` stock devem PASS.

### B.5 Plano B se falhar: system_dlkm próprio (só slot inativo)

Muda: `system_dlkm_<slot>` regerado com os 79 GKI assinados pela NOSSA chave + `system_dlkm.modules.load` correspondente; `vbmeta_<slot>` precisa novo `Hashtree descriptor` (digest+ salt da partição) assinado — sem a chave Xiaomi, usa-se vbmeta com `AVB_FLAG` capaz? Em orange/unlocked o bootloader tolera vbmeta re-assinado com chave própria? `UNVERIFIED` (depende do estado orange vs yellow; plano fato 12 proíbe `--disable-verification`). Riscos: hashtree errado = dm-verity falha no mount = bootloop; COW/snapshot (`lpdump`: `system_dlkm_a` + `product_a-cow`) pode recusar escrita via fastbootd; rollback exige vbmeta stock + dlkm stock íntegros (backup F1). Procedimento seguro: só slot inativo; `fastboot flash system_dlkm_a`, `fastboot flash vbmeta_a` (com hashtree recalculado via `avbtool add_hashtree_footer`), `set_active a`, observar; qualquer erro → `set_active b`. Por isso a solução B.1 (só `boot`) é preferível — Plano B só se B.4 falhar no Image novo.

---
## Auto-revisão
Rebaixado: nomes exatos de kwargs no macro (validar no checkout), comportamento orange do bootloader com vbmeta re-assinado, localização do Magisk (H20), contagens 215/217/557 (H7). Localização do corpo `verify_pkcs7_signature`: não encontrada nas listagens vasculhadas (declarado UNKNOWN de arquivo; semântica coberta por `verification.h:14-18` + 3 vias).
