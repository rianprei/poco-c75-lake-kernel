# POCO C75 4G (lake) — Kernel Hunter — PLANO v2 (consolidado, 2026-10-05)

Labels: FACT (URL/fonte lida) / MEASURED (saída de comando local) / INFERRED / UNVERIFIED / UNKNOWN.
Princípio: nada é "perfeito" por declaração; só passa quem passa os GATES no aparelho. Sem blind-flash. Rollback antes de qualquer escrita.

## 1. Fatos estabelecidos
| # | Fato | Rótulo | Prova |
|---|---|---|---|
| 1 | Aparelho lake/2410FPCC5G, mt6768, Android 16 HyperOS OS3.0.306.0.WGTMIXM, slot ativo _b, orange, unlocked, Magisk | MEASURED | getprop via adb |
| 2 | Kernel stock = `6.6.89-android15-8-g5a0ffb447c1d-ab13771415-4k` | MEASURED | uname |
| 3 | Fonte do stock = tag AOSP `android15-6.6-2025-06_r12` → commit 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143, Makefile 6.6.89 | MEASURED | git ls-remote + Makefile |
| 4 | Xiaomi NÃO publicou fonte do lake; MiCode sem branch lake | FACT (Antigravity+audit freebuff; ls-remote) | research/CANDIDATES.md, AUDIT_antigravity.md |
| 5 | 215 .ko vendor_dlkm: 208 vermagic `g810fd09a116c`, 7 `6.6.30…gf597b3de5ef5` (binder_gki, millet_*) | MEASURED | modinfo (2 agentes + eu) |
| 6 | Kernel IGNORA a parte de versão do vermagic se o módulo tem CRCs → hash/sufixo -ab13771415 NÃO precisam bater. O resto (`SMP preempt mod_unload modversions aarch64`) precisa | FACT | kernel/module/version.c r12 `same_magic()` |
| 7 | Dos símbolos que os 215 módulos importam do vmlinux (1572), 100% estão nas listas `android/abi_gki_aarch64*` do r12 (32 listas, 8962 símbolos) | MEASURED (por nome) | research/kmi_*.txt |
| 8 | BUILD.bazel do r12 lista `aarch64_additional_kmi_symbol_lists` com abi_gki_aarch64_{mtk,xiaomi,xiaomi2,...} | FACT | BUILD.bazel linhas 111+ |
| 9 | KMI generation = 8 | FACT (AUDIT_codex, não reverificado por mim) | AUDIT_codex.md |
| 10 | `fastboot boot` no lake: UNKNOWN (outros Xiaomi MTK: bugado/unknown command) → NÃO contar com ele | UNVERIFIED | OPENCODE2_boot_safety.md §1 |
| 11 | Fallback A/B automático existe (retry-count/successful); kernel que quebra bootctl marca slot unbootable e anula o fallback | FACT | OPENCODE2 §2 (AOSP ab_implement + KernelSU #42) |
| 12 | vbmeta: nada a mudar em orange; `--disable-verification` = gambiarra proibida | FACT/INFERRED | OPENCODE2 §3 |
| 13 | BROM/mtkclient NÃO recupera (DL forbidden 0xc0020004, mtkclient #219) → brick de preloader = sem volta | FACT | OPENCODE2 §5 |
| 14 | Build: Kleaf `tools/bazel` (build/build.sh legado 404 em kernel/build main); manifest `common-android15-6.6-2025-06` existe (d7afe67b), pin do tag r12 por checkout manual | FACT/MEASURED | ls-remote; AUDIT_codex |
| 15 | ROM custom real p/ lake: não achada. `wiki.lineageos.org/devices/lake` = Moto G7 Plus (NÃO usar) | FACT | OPENCODE2 §7 |
| 16 | `mtk_em.ko` não está carregado no aparelho (2 símbolos sem dono são dele) | MEASURED | lsmod/kallsyms |

| 17 | Artefatos OFICIAIS do build 13771415 são públicos e baixam sem login (via artifactUrl assinado no HTML do viewer): Image, vmlinux.symvers, kernel_aarch64_Module.symvers, System.map, abi_symbollist, manifest_13771415.xml, repo.prop, build.config.constants, build.log, boot.img etc. (codex/OPENCODE2 haviam dito "LOCKED": ERRADO) | MEASURED | research/ + official-ab13771415/ (portal `pesquisa`, curl) |
| 18 | `Image` do boot_b descompactado == Image oficial ab13771415 BYTE A BYTE (sha256 a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca, 36461056 B, `cmp` idêntico). O kernel do aparelho É o GKI oficial do Google, sem patch da Xiaomi | MEASURED | cmp + sha256 |
| 19 | Manifest oficial fixa tudo: kernel/common=5a0ffb44…, kernel/build=4039bcfd1d55f2e9f3d3f34c1815c63b755127b8, prebuilts/clang/host/linux-x86=7061673283909f372f4938e45149d23bd10cbd40, kernel/prebuilts/build-tools=b46264b7…, bazel_common_rules=9530bee1…; CLANG_VERSION=r510928; tools/bazel = kleaf/bazel.sh | FACT | official-ab13771415/manifest_13771415.xml, build.config.constants |
| 20 | Gate de CRC: número CORRIGIDO em 2026-10-06 — "1573" era o subconjunto dos **215 módulos de vendor_dlkm**; sobre os **557 `.ko` (370 módulos únicos)** o kernel tem de fornecer **2309** símbolos, e é esse o conjunto comparado pelo gate (`symbols.reference_provides=2309 compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0` → PASS). Reprodução: `tools/gate_kmi_crc.sh <symvers>`; sabotagens automáticas: `tools/selftest_gates.sh` (1 positivo PASS + 3 negativos FAIL: CRC de `mutex_lock` corrompido cita o símbolo, export removido, symvers vazio) | MEASURED | tools/gate_kmi_crc.sh + tools/selftest_gates.sh |

| 21 | Backup 42/42 itens (9 GB, inclui super completo) com hash do aparelho == hash recalculado no host (eu recomputei: ok=42 mismatch=0 missing=0). Cópia FORA do disco principal ainda pendente | MEASURED | audit/SHA256SUMS + sha256sum |
| 22 | 557 arquivos .ko = **370 módulos únicos** (número CORRIGIDO em 2026-10-06, contagem do dump em audit/modules): 342 arquivos no ramdisk do vendor_boot (170 do slot A + 172 do slot B; vermagic `…gbdb5aebb8ade…`, early-boot) + 215 arquivos em vendor_dlkm (`…g810fd09a116c…`; 7 deles `6.6.30-…-gf597b3de5ef5`); 17 nomes aparecem nas duas árvores → 172+215−17=370. Nenhum assinado (signer=none). 4138 símbolos distintos exigidos | MEASURED | tools/data/modules_inventory.tsv + tools/dump_modcrcs.py |
| 23 | Gate de CRC ESTENDIDO a todos os 557 módulos: 2309 símbolos exigidos que o vmlinux oficial fornece, 0 divergências, 0 símbolos com 2 CRCs diferentes (`conflicting_crcs=0`). 1829 são fornecidos por módulos (inter-vendor/MTK); 10 sem fornecedor no conjunto: rfkill_*, arc4_* (módulos GKI do system_dlkm: rfkill.ko, libarc4.ko) e calc_eff_hook (mtk_em, não carregado) | MEASURED | tools/gate_kmi_crc.sh (sobre tools/data/modules_required_crcs.tsv) |
| 24 | Config: MODULE_SIG=y, MODULE_SIG_PROTECT=y, MODULE_SIG_FORCE NÃO setado, SYSTEM_TRUSTED_KEYS="", MODULE_SIG_KEY=certs/signing_key.pem → chave efêmera de build embutida no Image; módulos GKI do system_dlkm (79 no load list) são assinados pela chave do Google | MEASURED | audit/config.stock |
| 25 | Timestamp do Image oficial (Jul 11 22:46:09 UTC) = committer time 1752273969 do commit (SOURCE_DATE_EPOCH) | MEASURED | date -u -d @1752273969 |
| 26 | Comando bazel oficial do CI: tools/bazel build/run --config=android_ci //common:kernel_aarch64_abi_dist (com --repo_manifest=manifest_13771415.xml). Reprodução idêntica: UNKNOWN | FACT (CODEX2, build.log linha 3) | research/CODEX2_kleaf_repro.md |
| 27 | Disco: / e /home no mesmo volume, 51 GB livres (90%). Build precisa 40–75 GB (UNVERIFIED) → BLOQUEIO provável | MEASURED/UNVERIFIED | df -h |
| 28 | Fastboot ROM oficial OS3.0.306.0.WGTMIXM: NÃO achada (só recovery ROM; fastboot global mais nova OS3.0.20.0). O .tgz local lake_OS2.0.1.0 está truncado (inútil). Rollback = nossos backups por hash (boot/init_boot/vendor_boot/dtbo/vbmeta + super 8 GB) | FACT | OPENCODE2b_recovery_firmware.md |

| 29 | `.config` OFICIAL do build 13771415 (kernel_aarch64_filegroup_decl.tar.gz → kernel_aarch64_config/out_dir/.config, 211483 B) == audit/config.stock do aparelho, BYTE A BYTE (sha256 9b544345144b5e7d…). A config exata do kernel é conhecida: gki_defconfig (787 entradas, 0 contrariadas) + defaults Kconfig + forças do Kleaf | MEASURED (eu refiz o diff) | official-ab13771415/kernel_aarch64_filegroup_decl.tar.gz |
| 30 | BUILD.bazel r12: kernel_aarch64 usa kmi_symbol_list android/abi_gki_aarch64 + 32 additional lists, trim_nonlisted_kmi=True, strict_mode=True, protected_exports_list; base sem defconfig_fragments. KSU+susfs que exportar símbolo novo precisa estender a kmi list (senão TRIM poda / strict_mode falha) | FACT/INFERRED | CODEX3_config_safety.md |
| 31 | Tabela de configs seguras/arriscadas/proibidas (28 linhas, fonte por linha) e abi.stg oficial (7.78 MB) p/ stgdiff | FACT | research/config_safety_table.csv, official-ab13771415/abi.stg |

| 32 | O kernel gzip DENTRO do boot_a e boot_b (14555421 B, sha256 7a5228749f9da76408fd6eef4c0ae5b231c164c1239e314fba855acbb7826bb2) == kernel do boot-gz.img OFICIAL do Google build 13771415, byte a byte. Só o rodapé AVB difere (oficial: Algorithm NONE; aparelho: SHA256_RSA2048, key sha1 b2a02f1e…, rollback 0, flags 0, hash descriptor 'boot') | MEASURED | python sha256 sobre bytes do kernel; avbtool info_image |
| 33 | Header do boot_b: v4 PADRÃO (kernel_size@8=14555421, ramdisk_size=0, header_size=1584, cmdline vazia, sig_size=0). Kernel dentro do boot é gzip (gzip header 1f8b0800 00000000 0203: MTIME 0, XFL 2, OS 3). Compressão do host (gzip -9n etc.) NÃO reproduz o gzip do Google byte a byte — irrelevante (kernel descompacta qualquer gzip válido; regenerar footer) | MEASURED | header.txt, xxd, gzip testes |
| 34 | MiCode/Xiaomi_Kernel_OpenSource tem branch `dew-v-oss` (e91fa149…, 2025-09-19): kernel do REDMI 15C / POCO C85 (dew, MT6769 mesma família) 'baseado na tag MTK lc-master-v-t-alps-release-v0.mp1.rc-V4, config dew_defconfig'. Diverge do GKI r12: 183 commits à frente, 12041 atrás (base GKI mais antiga + patches MTK ALPS/Xiaomi). Sem drivers/misc/mediatek nem DTS do dew na árvore. NÃO é o lake; é irmão. Os hashes de vermagic dos módulos (810fd09a116c, bdb5aebb8ade, f597b3de5ef5) NÃO existem no histórico dele | MEASURED | git ls-remote, GitHub API compare/commits |
| 35 | sergiofalconp24-hub/dew-kernel: 2 commits, 0 stars/releases, sem licença, boot.img binário e dew_tmp.c na raiz; device dew_n_global (NÃO lake); alega header v4 'não padrão' (no seu aparelho é padrão); fluxo: build em GH Actions, repack preservando header e footer, flash só boot_a, nunca vbmeta/vendor_boot/init_boot/lk. Serve só como referência de processo; NADA dele é flashado ou executado | MEASURED/UNVERIFIED | portal pesquisa |

| 36 | Mecanismo (fonte r12 main.c 1165-1171, 1366; signing.c 135-139; gki_module.c): módulo com sig_ok=false (não assinado OU assinado por chave que o kernel não conhece) é tratado como 'vendor': só pode usar símbolos de outros módulos vendor ou 'unprotected'; e se EXPORTAR símbolo da lista protected_exports (506 símbolos) leva -EACCES | FACT | main.c/signing.c lidos |
| 37 | Dos nossos 557 módulos, 9 símbolos protegidos são importados (arc4_*, rfkill_*) por cfg80211.ko (7) e mac80211.ko (2). Kernel recompilado com chave nova => rfkill.ko/libarc4.ko/bluetooth.ko (GKI, system_dlkm) viram sig_ok=false e NÃO carregam => Wi-Fi/BT quebram (OPENCODE2c confirmado por mim) | MEASURED | /tmp/kmi interseção; abi_gki_protected_exports_aarch64 |
| 38 | O cert X.509 público embutido no Image oficial (CN=Build time autogenerated kernel key, 2025-07-11→2125, sha256 FP 76:FB:DF:D1:3F:6B:A6:12:75:6E:AE:36:E9:9F:88:50:8F:A3:20:2A:A3:51:17:70:4C:26:D5:5A:99:CC:72:A1) VALIDA a assinatura de um módulo GKI oficial do mesmo build (can.ko: openssl cms -verify = 'CMS Verification successful'; signer = esse issuer, serial 0x1CF83E80…). Salvo em research/google_gki_ab13771415_modsign_cert.pem | MEASURED | openssl cms |
| 39 | system_dlkm é coberto por Hashtree descriptor no vbmeta_a (root, chave Xiaomi); trocar a partição exigiria mexer no vbmeta — por isso a solução do fato 38 é preferível. system_dlkm_a tem COW de snapshot (Virtual A/B): fastbootd pode recusar escrita de partição lógica | MEASURED/UNVERIFIED | audit/avb/vbmeta_a.txt; lpdump_super.txt |
| 40 | MiCode `dew-v-oss`: 183 commits à frente do GKI r12 classificados 183/183 (MTK ALPS + Xiaomi); dew_defconfig e DTS do dew NÃO existem lá; nenhum branch MiCode é do lake; nenhum outro da família com Android 15/6.6. Util só como espelho de processo | FACT | CODEX4_dew_tree.md |

| 41 | Recuperação: BROM/mtkclient NÃO funciona no lake (issue #219: DL forbidden 0xc0020004, SLA/DAA/SBC on, 'V5 patched against carbonara', V6 BROM patched vs kamakiri2); único caminho garantido sem fastboot = serviço autorizado Xiaomi (EDL+auth, pago). Caminhos oficiais SEM BROM que funcionam desde que LK/preloader fiquem intactos: fastbootd (`fastboot reboot fastboot` + flash boot/vendor_boot/dtbo), recovery stock (Power+Vol+), `adb sideload` de OTA full, Mi Flash (fastboot ROM). Test point/EDL: sem diagrama público | FACT (fontes no relatório; não reverificado por mim) | ANTIGRAVITY3_recovery_sweep.md §1–2 |

| 42 | OBSERVABILIDADE (CORRIGIDO): pstore/ramoops ESTÁ ATIVO. cmdline tem ramoops.mem_address=0x4d010000, mem_size=0xe0000, console_size=0x40000, pmsg_size=0x80000; o DT em execução tem reserved-memory/mblock-15-pstore (o LK injeta; por isso não aparece nos DTS das partições — minha refutação anterior estava ERRADA). Além disso a MediaTek grava dump via mrdump/aee_aed → expdb → /data/aee_exp. mrdump (importado por 18 módulos) e aee_aed (por 37) são DEPENDÊNCIAS DURAS. Após crash, voltar ao slot stock e ler /sys/fs/pstore (console-ramoops) | MEASURED | audit/proc/cmdline.txt; audit/devicetree.tar; lsmod.txt |
| 43 | Teclas: Vol− + Power → fastboot; Vol+ + Power → recovery (guias MTK/Xiaomi; sem log do lake). Fallback A/B automático: UNKNOWN (não provado no lake); kernel que não rode bootctl não marca slot-successful | UNVERIFIED/INFERRED | OPENCODE2d_bringup_runbook.md |

| 44 | Solução do cert (CODEX5, verificado por mim): Kleaf @kernel/build 4039bcfd tem atributo `system_trusted_key` (kleaf/impl/kernel_config.bzl:161-164 → define CONFIG_SYSTEM_TRUSTED_KEYS=<basename>; kernel_build.bzl usa), MAS common_kernels.bzl (define_common_kernels) NÃO o repassa (0 ocorrências) → patch necessário: repassar o atributo + label do cert + filegroup. Não altera CRC (segundo CODEX5, não reverificado) | FACT/MEASURED | /tmp/kmi/kernel_config.bzl, common_kernels.bzl |
| 45 | tools/verify_modsig.sh (publicado; na época em research/) — eu reexecutei --selftest: positivo PASS (can.ko oficial valida contra cert garimpado do Image), negativo FAIL (módulo adulterado rejeitado), 'SELFTEST PASS' | MEASURED | execução própria |

| 46 | repack_boot.py (OpenCode #2) — testes REFEITOS por mim em /tmp (backup intocado): baseline com kernel gz idêntico → imagem 64 MiB, header+kernel [0:14561280] byte-igual ao boot_b; diferenças só no bloco AVB/rodapé (4594 B, após o kernel); footer novo Algorithm NONE, rollback 0, flags 0, Image Size 14561280; kernel novo (Image oficial gzip -9n) → desempacota com unpack_bootimg e descomprime para sha a023b4fd…; imagem >64 MiB e kernel não-gzip REJEITADOS sem gerar saída | MEASURED | /tmp/myrepack |
| 47 | O boot_b stock tem, após o kernel, um bloco de 16384 B com magic AVB0 (3487 B não nulos) = 'boot signature' de certificação GKI (assinatura Google do kernel); header signature_size=0. O repack o descarta (correto: cobre o kernel antigo e não é reassinável) | MEASURED/INFERRED | análise de bytes do boot_b |
| 48 | TOLERÂNCIA AVB em orange (medido, com controles): dtbo_a/b, vendor_boot_a/b e init_boot_a batem com os hash descriptors do vbmeta do respectivo slot; init_boot_b (Magisk) NÃO bate (size 3137536) e o aparelho boota normalmente no slot _b em orange/unlocked → o LK tolera hash divergente. Para o `boot` (partição encadeada por chave) é análogo mas UNVERIFIED | MEASURED / UNVERIFIED | backup-2026-10-05 + avbtool |
| 49 | (OBSOLETO após fato 62: slot A não é slot de teste) init_boot_a é STOCK sem Magisk; no RAM-boot em slot B o init_boot_b (Magisk) continua valendo, então root existe, mas os testes são desenhados SEM root: verificações por `adb shell` (sem su): getprop, logcat, `adb bugreport` (inclui kernel log), dumpsys, ip/iw via cmd; root só depois de validar | MEASURED (Magisk strings: a=0, b=4) | backup init_boot_* |
| 50 | kCFI: 101 dos 215 módulos de vendor_dlkm têm __kcfi_typeid_* (os demais não têm símbolo de indireção: não prova nada) → módulos do lake são compilados com kCFI → CONFIG_CFI_CLANG=y OBRIGATÓRIO. A correção do OWLXS (desligar CFI) é para outro aparelho (módulos sem CFI): NUNCA copiar. Não mudar CFI/LTO/HZ na v1 | MEASURED/INFERRED | llvm-nm + OPENCODE3_mtk_gki_failures.md |
| 51 | Fonte MTK LK público (gemini-lk/app/mt_boot/fastboot.c:515 cmd_boot) contém `fastboot boot`, mas o runtime no lake é UNKNOWN; retry inicial do A/B no lake UNKNOWN | FACT (citação do relatório; não reverificada) | OPENCODE2e_lk_repack_review.md |
| 52 | Disco: lixeira esvaziada (58 GB + 11 GB); livre ≈ 85 GiB em /home (btrfs, compress=zstd:1). Cabe o sync parcial (20–27 GB, estimativa) | MEASURED | df -h |

| 53 | VISIBILIDADE SEM ROOT (uid 2000 shell, medido no aparelho): /proc/modules legível (429 linhas, nomes visíveis, endereços zerados), lsmod 430 linhas; dmesg_restrict=0 → `dmesg` lê normalmente; kptr_restrict=2; /sys/fs/pstore LISTA e é legível pelo grupo log: console-ramoops-0 (262132 B) e pmsg-ramoops-0 (524276 B); logcat -b kernel = 0 linhas. OPENCODE2f errou ao dizer que dmesg e pstore exigem root | MEASURED | adb shell (somente leitura) |
| 54 | `adb bugreport` SEM root (zip 36 MB, 5090 entradas) CONTÉM seção '------ KERNEL LOG (dmesg)' (~2 MB), console-ramoops e last_kmsg em texto | MEASURED | bugreport próprio (artefato removido do aparelho) |
| 55 | CRITÉRIO DE MÓDULOS CORRETO: baseline = 429 módulos carregados (audit/proc/modules.txt; lsmod 430 linhas). Aceite = conjunto de nomes de `cat /proc/modules` do boot novo ⊇ baseline (diferenças justificadas). O critério '≈683+ / ≥530' do OPENCODE2f está ERRADO (contou arquivos .ko, não módulos carregados) | MEASURED | modules.txt vs relatório |
| 56 | FMEA do Antigravity (18 furos) classificada por mim: REAIS: RAM 15 GB (usar --jobs baixo), cópia externa do backup, pinned.xml não testado, checar clang-r510928 no prebuilt (clang --version == banner do Image), LTO/config default do Kleaf (coberto por G-CONFIG), footer AVB, revisor por fase, KSU↔Magisk, OC com módulos fechados, fastboot boot e fallback A/B. DESATUALIZADOS: disco (85 GiB livres), backup incompleto (42/42 feito). REFUTADOS: BUILD_NUMBER/vermagic e timestamp causarem 'Invalid module format' (same_magic ignora a versão, fato 6), '7 módulos 6.6.30 sem como checar CRC' (já checados: 0 divergências), '1829 símbolos fora do vmlinux = plano errado' (são de outros módulos, fato 23), 'gzip diferente quebra o hash do footer' (footer é regenerado). Links: GitHub existem (200); o do XDA deu 403 (não verificável, id redondo suspeito) | MEASURED/INFERRED | AUDIT própria |

| 57 | tools/repack_boot_v2.py (CODEX6, revisor; na época em research/) substitui a v1: 12 bugs reais corrigidos (ramdisk descartado em silêncio, gzip só por magic, sobrescrita silenciosa, tracebacks, temporários, footer por magic, etc.; 32/32 testes do codex). EU refiz 9 testes na v2: baseline c/ --drop-signature = header+kernel idênticos, footer NONE/rollback 0/flags 0; sem --drop-signature RECUSA (bloco GKI AVB0 detectado); Image oficial → sha a023b4fd… após repack; oversize, gzip corrompido, nogz, truncado, saída existente e entrada==saída → RECUSADOS sem criar saída. Ferramenta oficial do F5 = v2 (--drop-signature explícito) | MEASURED | /tmp/myrepack2; research/repack_boot_v2.py |
| 58 | F2 EXECUTADO (parcial): repo (git-repo 2.65, clonado de gerrit; --no-repo-verify) + manifest pinado. FALHA descoberta e tratada: o branch android15-6.6-2025-06 NÃO existe mais em kernel/common (restam 2025-09 em diante) → `common` buscado pela TAG refs/tags/android15-6.6-2025-06_r12 (editado em .repo/manifests/pinned.xml: revision=tag, sem upstream/dest-branch). Gate obrigatório depois do sync: git -C common rev-parse HEAD == 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143 | MEASURED | ~/lake-build/sync*.log |

| 59 | F2 PASSOU: 36/36 projetos do manifest nas revisões pinadas (common=5a0ffb44…, build/kernel=4039bcfd…, clang prebuilt=70616732…); clang-r510928 do checkout = mesmo compilador do banner do Image stock (11368308 +pgo+bolt+lto+mlgo, LLVM 477610d4d0d9…) | MEASURED | ~/lake-build/src |
| 60 | F3 BUILD DE CONTROLE (sem modificação) PASSOU: `tools/bazel run --config=stamp //common:kernel_aarch64_dist` (760 ações, ~25 min a 3 CPUs): vmlinux.symvers IDÊNTICO byte a byte ao oficial; gate_kmi_crc.sh sobre os 557 módulos = PASS (`compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0`; a versão de 2026-10-05 imprimia "1573" porque usava só os 215 módulos de vendor_dlkm); .config da build == config.stock (0 diff); System.map: mesmos (tipo,nome) de símbolo (0 diff); Image mesmo tamanho (36461056 B) mas 8,1 M bytes diferentes (layout: chave efêmera + banner `6.6.89-android15-8-4k` sem -g…-ab…) — como previsto | MEASURED | ~/lake-build/out/dist_control |
| 61 | O banner da build local é `6.6.89-android15-8-4k` (o oficial: `…-g5a0ffb447c1d-ab13771415-4k`): irrelevante para módulos (same_magic ignora), mas manter `android15-8` (KMI gen 8) | MEASURED | strings Image |

| 62 | **SEGURANÇA CRÍTICA — O SLOT A NÃO É SLOT DE TESTE**: vbmeta_a descreve system_dlkm/vendor_dlkm de **OS3.0.20.0** (firmware antigo) e vbmeta_b de **OS3.0.306.0** (o que roda, Android 16); boot/vendor_boot/init_boot/dtbo/vbmeta* diferem entre a e b. Trocar para o slot A bootaria um Android antigo sobre os dados atuais (risco de 'data corrupted', anti-rollback, perda de acesso). A estratégia 'testar em boot_a' dos fatos/planos anteriores está REVOGADA | MEASURED | avbtool info_image vbmeta_a/b |
| 63 | NOVO PROTOCOLO F6 (máxima segurança): (T0) `fastboot boot T0_boot_stock_equiv.img` — carrega SÓ na RAM, NÃO grava nada (o LK MTK tem cmd_boot no fonte; no lake UNKNOWN); se 'unknown command' ou falhar, nada mudou. Se funcionar: (T2) `fastboot boot` da imagem com o kernel novo, validar tudo sem persistir; qualquer travamento → segurar Power para reiniciar = volta ao boot_b stock intacto. Só depois de T2 100% verde: gravar `boot_b` (persistente), com rollback = `fastboot flash boot_b backup/boot_b.img` (hash conferido) e Vol−+Power para fastboot. NUNCA set_active a. Se `fastboot boot` não existir: gravar boot_b só após T0 (stock-equivalente) passar com sucesso persistente | DECISÃO | este plano |
| 64 | Risco do fallback automático A/B do LK ao falhar boot_b: pode tentar o slot A (OS antigo). Mitigação: preferir RAM-boot; se gravar boot_b, ter o cabo USB e Vol−+Power prontos; NÃO escolher 'factory reset' em nenhuma tela | INFERRED | fato 62 |

| 65 | F3b BUILD COM CERT DO GOOGLE (OpenCode4 patch corrigido aplicado: kleaf/common_kernels.bzl +system_trusted_key; common/BUILD.bazel + cert PEM) — gates TODOS PASS: config diff vs stock = 1 linha (CONFIG_SYSTEM_TRUSTED_KEYS="google_gki_ab13771415_modsign_cert.pem"); vmlinux.symvers IDÊNTICO ao oficial; gate_kmi_crc.sh = PASS (`compared=2309 mismatches=0 missing_exports=0 conflicting_crcs=0`); Image com 2 certs embutidos (próprio 06:99:F5… e Google 76:FB:DF:D1…) | MEASURED | ~/lake-build/out/dist_cert |
| 66 | PROVA FUNCIONAL OFFLINE do cert (verify_modsig.sh): módulo oficial assinado pelo Google (can.ko) VALIDA contra o Image NOVO (cert @0x208a04d), FALHA contra o Image da build de controle (sem o cert) e módulo assinado pela chave própria valida contra o novo — experimento controlado: o cert é o que faz os módulos GKI do system_dlkm continuarem sig_ok=true | MEASURED | verify_modsig.sh x3 |
| 67 | Imagens de teste prontas em ~/lake-build/out/images (SHA256SUMS): T0_boot_stock_equiv.img (kernel stock bit a bit, footer NONE, sem bloco GKI; header+kernel idênticos ao boot_b), T2_boot_cert.img (kernel novo com cert; decompressed == dist_cert/Image; header só difere em kernel_size), stock_boot_b.img (cópia do backup). Ambas 64 MiB, footer NONE/rollback 0/flags 0, unpack_bootimg OK | MEASURED | avbtool/unpack_bootimg |

Refutado: "-ab13771415 exige BUILD_NUMBER idêntico" (codex) e "vermagic mismatch bloqueia" (OPENCODE2 risco 3) — ambos falsos por #6.

## 2. Perguntas ainda ABERTAS (bloqueiam FOUND-PERFECT)
Q1 CRC por símbolo: nomes batem (#7), CRCs só se provam depois da build → GATE-KMI-CRC.
Q2 RESOLVIDA: Image oficial ab13771415 == stock (fato 18). CORREÇÃO (fato 24): o Image recompilado NÃO será byte-idêntico (chave de assinatura efêmera embutida). G-REPRO passa a ser: mesma config (diff vazio), mesmo conjunto de símbolos e CRCs (vmlinux.symvers idêntico), System.map com os mesmos símbolos e tamanhos de seção próximos; diferença aceita só no blob de certificado.
Q8 RESOLVIDA NO PAPEL (fatos 36–38), FALTA PROVA NO APARELHO: embutir o cert público do Google (fato 38) no kernel novo via CONFIG_SYSTEM_TRUSTED_KEYS="<cert.pem>" além da chave efêmera própria. Assim rfkill/libarc4/bluetooth stock (assinados pelo Google) verificam (sig_ok=true) sem trocar system_dlkm nem vbmeta. Única diferença de config esperada vs stock: SYSTEM_TRUSTED_KEYS (G-CONFIG deve mostrar SÓ essa linha). Provas exigidas: (1) build com o cert: `strings`/openssl no Image acha DOIS certs; (2) no aparelho, dmesg sem 'exports protected symbol' nem 'Unknown symbol'; wlan0 sobe; bluetooth liga. Plano B se falhar: system_dlkm próprio (toca vbmeta; só slot inativo).
Q3 `fastboot boot` no lake: UNKNOWN → testar uma vez com a imagem STOCK (sem risco) antes de depender.
Q4 RESOLVIDA (fato 29): config oficial == stock. G-CONFIG = `diff <(sort .config do build novo) <(sort audit/config.stock)` deve ser vazio na build de controle (F3).
Q5 Auditoria do aparelho do OpenCode (8993 arquivos) ainda sem relatório final; módulos do ramdisk/vendor.
Q6 DTBO/DT: não muda no kernel GKI (vive em vendor_boot/dtbo); só relevante para OC.
Q7 Compatibilidade de ROM com kernel novo: depende do vendor_dlkm da ROM; UNVERIFIED.

## 3. Fases com GATE (cada uma: comando + critério objetivo; falhou → STOP → ROLLBACK)

F0 Pré-requisitos host (pedir ok antes de instalar)
- Instalar `repo`, git, python3, libelf, ncurses, bc (Arch: pacman). Bazel vem do checkout (tools/bazel).
- Verify: `repo --version`; `df -h /home` ≥ 50 GB livres; `free -g` ≥ 12 GB.

F1 BACKUP completo (já 14/ ~40 itens; terminar) — G-ROLLBACK
- Faltam: vbmeta_vendor_a (truncado), vbmeta_vendor_b, lk_a/b, preloader_raw_a/b, seccfg, proinfo, nvram, nvdata, nvcfg, persist, scp/sspm/spmfw/tee/gz/md1img/logo.
- Verify: host sha256 == `adb shell su -c sha256sum /dev/block/by-name/X` para cada. Critério: 0 MISMATCH.
- Cópia fora do disco principal (pendrive/outro disco): `rsync -a backup-2026-10-05/ /mnt/...` + sha256sum -c.

F2 Checkout do fonte — G-SOURCE
- Usar o MANIFEST OFICIAL PINADO (fato 19): `repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6-2025-06`, depois `cp ~/Documentos/mods/lake-kernel/official-ab13771415/manifest_13771415.xml .repo/manifests/pinned.xml && repo init -m pinned.xml && repo sync -c --no-tags -j4` (UNVERIFIED que o sync aceita; se falhar, checkout manual de cada projeto na revisão do XML).
- `cd common && git fetch origin refs/tags/android15-6.6-2025-06_r12 && git checkout 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143`
- Verify: `git -C common rev-parse HEAD` == 5a0ffb447c1dbd82e8e3af7a98c4a629f4b6d143; `git -C build/kernel rev-parse HEAD` == 4039bcfd1d55f2e9f3d3f34c1815c63b755127b8; `git -C prebuilts/clang/host/linux-x86 rev-parse HEAD` == 7061673283909f372f4938e45149d23bd10cbd40; `grep -E "^(VERSION|PATCHLEVEL|SUBLEVEL)" common/Makefile` = 6/6/89.

F3 BUILD de CONTROLE (config oficial, sem KernelSU, sem mudar nada) — G-BUILD / G-REPRO
- `tools/bazel run --config=fast //common:kernel_aarch64_dist -- --dist_dir=$PWD/out/dist` (conferir flags na doc source.android.com; não inventar).
- Disco: conferir `df -h` ≥ 80 GB livres antes do sync (hoje 51 GB: usar disco externo/limpar com autorização).
- Verify: `ls out/dist/Image*`; `strings out/dist/Image | grep "Linux version"` → 6.6.89-android15-8-…; `file Image` = "ARM64 boot executable Image, 4K pages"? (confirmar 4k).
- REPRODUTIBILIDADE (G-REPRO): `sha256sum out/dist/Image` == a023b4fdd9d4dd55a5bb06f2fcb46af3d06a9e773c109c5cc6e3e368d83bbaca. Igual = pipeline provado (kernel stock reconstruído do fonte). Diferente = comparar com `official-ab13771415/{System.map,vmlinux.symvers}` para achar a causa (timestamp/localversion/config) antes de seguir.
- Comparar com stock (`audit/bootimg/` Image do boot_b): `diff <(strings stock) <(strings novo)`; diff de config: `scripts/diffconfig audit/config.stock out/.../.config` → deve ser vazio ou explicável (kleaf/local). Critério: diff de config = só o explicável; flags CFI_CLANG/SHADOW_CALL_STACK/LTO_NONE/MODVERSIONS/TRIM idênticos.
- Atenção: stock tem LTO_NONE=y: NÃO usar --lto=thin sem checar divergência.

F4 GATE-KMI-CRC (a verificação decisiva, estática)
- Rodar: `tools/gate_kmi_crc.sh <out/dist/vmlinux.symvers do build NOVO>` (validado: PASS no oficial/controle/cert; sabotagens em `tools/selftest_gates.sh`). Critério PASS = `mismatches=0 missing_exports=0 conflicting_crcs=0` sobre `compared=2309`.
- Extrair do build: `vmlinux.symvers` (ou `Module.symvers`).
- Para cada símbolo em tools/data/modules_required_crcs.tsv (20187 linhas, formato `símbolo\t0xCRC\tmódulo`, gerado por `tools/dump_modcrcs.py` a partir dos 557 `.ko`): CRC exigido == CRC no Module.symvers novo.
- Critério: 0 mismatch entre os 2309 símbolos de kernel exigidos pelos 557 módulos (incluindo ramdisk) → PASS. Rodar também `dump_modcrcs.py` + comparação sobre TODOS os módulos (vendor_dlkm e ramdisk). Qualquer mismatch → REJEITAR build (shot 19), voltar F3 (config/toolchain divergente).
- Verificar vermagic final: `strings Image | grep "SMP preempt mod_unload modversions aarch64"`.
- Para os 7 módulos 6.6.30 (binder_gki, millet_*): checar CRC deles separadamente (outra árvore).

F5 REPACK sem tocar em vbmeta — G-BOOTIMG
- Método refinado (fatos 32–33): header v4 PADRÃO; kernel = gzip do Image novo; escrever em offset 4096; atualizar kernel_size@8; zerar padding até 4096-alinhado; regerar footer AVB (`avbtool add_hash_footer --partition_size 67108864 --partition_name boot --algorithm NONE --rollback_index 0`; footer assinado não é possível: sem a chave; em orange não é verificado, mas o rollback_index/flags devem ficar 0). BASELINE: repack do kernel STOCK (sem mudar nada) deve boot-ar igual, isola variável de repack vs kernel.
- Método (OPENCODE2 §4): desempacotar `backup/boot_b.img` (header v4), trocar SÓ o kernel (Image na compressão/format do stock), preservar header/os_version/cmdline e o rodapé AVB (`avbtool add_hash_footer --partition_size 67108864 --partition_name boot` com os mesmos parâmetros do original).
- Verify: `avbtool info_image novo.img` (algoritmo/rollback_index/partition size) idêntico ao original salvo o hash; tamanho ≤ 64 MiB; `unpack_bootimg --boot_img novo.img` mostra kernel novo e cmdline igual.
- Critério: todas as checagens OK; imagem registrada com sha256.

F6 TESTE NO APARELHO — PROTOCOLO REVISADO (substitui o texto antigo; ver fatos 62–64) — G-BOOTREAL / G-ROLLBACK
- **NUNCA usar o slot inativo (A) como slot de teste**: no aparelho auditado ele guarda firmware antigo (OS3.0.20.0) e o slot B (em uso) é OS3.0.306.0. Antes de qualquer troca de slot, comparar o firmware dos dois (`avbtool info_image` nos dois vbmeta).
- Pré: F1 completo (backup com hash conferido, cópia em outro disco), identidade do aparelho conferida (ro.product.device, cpuid, slot), cabo USB de dados, bateria ≥ 60 %.
- T0: `fastboot boot` da imagem stock-equivalente (kernel idêntico ao stock) — só RAM, não grava nada. Se `unknown command`: PARAR (nada mudou).
- T2: `fastboot boot` da imagem com o kernel novo — só RAM. Critérios de aceite em docs/DEVICE-TEST-PROTOCOL.md (módulos ⊇ baseline de 429, dmesg sem Unknown symbol/exports protected/CFI, wlan0, Bluetooth, SIM, etc.), tudo SEM root.
- T3 (somente com T2 100 % verde e autorização do dono): gravar `boot_b`; rollback imediato = `fastboot flash boot_b <backup>` (hash conferido) e Vol−+Power para fastboot. Nunca `set_active a`.
- Qualquer travamento em RAM-boot: segurar Power (flash intacto). Depois ler pstore/bugreport do boot normal.

F7 ESTABILIDADE — G-STABILITY
- 30 min stress CPU (`stress-ng` via termux ou loop) + leitura de thermal_zone a cada 10 s; `adb logcat -b kernel`/`dmesg -T | grep -iE 'panic|oops|BUG|thermal|Unknown symbol'`.
- Critério: 0 panic/reboot, temperatura estável, throttle sustentado medido (não pico).

F8 REVIEW adversarial (outro agente que não o autor) do diff de config, script de repack e logs; FIX → volta à F3 e refaz F4–F7.

F9 PROMOÇÃO — só com F6–F8 verdes: flashar em boot_b? Decisão separada (pedir "sim"). Manter slot A com kernel novo e slot B stock enquanto testa por dias.

F10 CUSTOMIZAÇÃO (um propósito por build; Golden Rule). REGRAS DE REPRODUTIBILIDADE (CODEX4): fixar KernelSU/SUSFS por COMMIT HASH (nunca @main/HEAD flutuante); todo patch deve FALHAR ALTO (nada de 'silent-skip': `git apply --check` + `set -e`); registrar hashes dos patches no log da build; desconfiar de afirmações sem prova (ex.: 'header não-padrão magic 0x4d5a40fa' do dew-kernel é falso para o lake: header v4 padrão, fato 33). KernelSU(-Next)/SUSFS sobre o kernel limpo já aprovado. Após integrar: refazer F4 (CRC), F5, F6, F7. Conferir conflito com Magisk atual.

F11 OC — só após F9 estável. Exige frequência + OPP + voltagem + clock + PMIC + thermal + stress. OPP vive em módulos vendor (CPU_DVFS.ko, Upower.ko) + DT (vendor_boot/dtbo): não é o kernel GKI. Estado inicial: UNKNOWN. Fonte para ler: audit/dts, audit/runtime. Pode exigir patch de DTB; risco alto; revert obrigatório se falhar.

## 4. Matriz de risco residual (honesta)
| Risco | Mitigação | Residual |
|---|---|---|
| CRC mismatch → módulos não carregam | F4 antes de flashar | build não aprovado nem sai do PC |
| Bootloop | RAM-boot primeiro (nada gravado); se gravar boot_b: rollback por fastboot com backup verificado (NUNCA set_active a: slot A = firmware antigo) | se bootctl não marcar success o fallback automático pode falhar; rollback manual por fastboot |
| Brick preloader | NÃO tocar preloader/lk/seccfg/nv* | BROM bloqueado → sem volta; por isso proibido |
| `fastboot boot` indisponível | NÃO gravar nada sem nova decisão do dono; slot A é descartado (fato 62) | decisão pendente |
| ROM custom incompatível | só depois do kernel estável; ROM do lake não existe verificada | UNVERIFIED |
| Dados (IMEI/persist) | backup hash + cópia externa | baixo |
| Agente erra/alucina | gate = comando + saída, review cruzada | baixo |

## 5. Quem faz o quê (maestro só roteia)
- Autor da build: codex (revisão cruzada: OpenCode #2, Antigravity). Auditoria do aparelho: OpenCode. Revisão de scripts de repack: Antigravity. freebuff#2 sem créditos.
- Aprovação: cada gate precisa de saída de comando no log, não de "OK" de agente.

## 6. FOUND-PERFECT
Só quando F6–F8 passarem no lake. Antes disso: NOT-READY.
