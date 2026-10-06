# REVIEW3 — FMEA da sequência DEVICE_COMMANDS_T0_T2.md (bring-up sem gravação)

> Autor: revisor FMEA (adversarial, não-autor) | Data: 2026-10-06 | Alvo auditado: `<lake-kernel>/research/DEVICE_COMMANDS_T0_T2.md`
> Método: re-medição independente por 2 métodos onde crítico; 3 abordagens por ponto crítico (documento-fonte, medição local, fonte externa AOSP).
> Rótulos: FACT (citação verificável) / MEASURED (saída de comando colada abaixo) / INFERRED (inferência declarada) / UNVERIFIED / UNKNOWN.
> Regras respeitadas: nenhum comando em aparelho, nenhum flash, nenhuma escrita em `audit/`, `backup-*`, `official-*`, `~/lake-build`; trabalho em `<workdir>`.

## 0. Re-medições próprias (base de toda a FMEA)

**M1 — Hashes das imagens (método 1: sha256sum; método 2: comparação byte a byte via python):**
```
$ cd <workdir>/img && sha256sum -c ~/lake-build/out/images/SHA256SUMS
T0_boot_stock_equiv.img: SUCESSO
T2_boot_cert.img: SUCESSO
(stock_boot_b.img ausente em /tmp — cópia parcial minha; as 2 imagens de teste OK)
```
```
$ python3: T0[4096:4096+14555421] == backup boot_b.img kernel: True
$ python3: T2 decompressed == dist_cert/Image: True len: 36461056 == 36461056
```
MEASURED: T0 contém o kernel stock bit a bit; T2 contém exatamente o `Image` da build cert (36.461.056 B = tamanho citado no fato 60 do plano).

**M2 — Header + footer (método 1: avbtool; método 2: parse python do header v4):**
```
avbtool T0 e T2: Algorithm NONE, Rollback Index 0, Flags 0, Image size 67108864 (64 MiB)
python: T0 magic=ANDROID! kernel_size=14555421 ramdisk_size=0 header_size=1584 header_version=4
        T2 magic=ANDROID! kernel_size=14556612 ramdisk_size=0 header_size=1584 header_version=4
```
MEASURED: ambas v4 padrão, ramdisk_size=0, footer NONE/rollback 0/flags 0. T0 kernel_size=14555421 = valor stock (plano fato 33). Rollback 0 = igual ao boot_b stock (medido: `avbtool info_image boot_b.img → Rollback Index: 0, Algorithm SHA256_RSA2048`).

**M3 — Config da build cert vs stock (método independente do fato 65: extraí `.config` do `kernel_aarch64_filegroup_decl.tar.gz` da dist_cert em /tmp e comparei):**
```
$ diff <(sort cert.config|grep -v '^#') <(sort audit/config.stock|grep -v '^#')
2368c2368
< CONFIG_SYSTEM_TRUSTED_KEYS="google_gki_ab13771415_modsign_cert.pem"
> CONFIG_SYSTEM_TRUSTED_KEYS=""
```
MEASURED: diff de **1 linha**, confirma o fato 65 por caminho independente. E o ponto central para /data:
```
cert build: CONFIG_F2FS_FS=y, CONFIG_DM_DEFAULT_KEY=y, CONFIG_FS_ENCRYPTION=y,
  CONFIG_BLK_INLINE_ENCRYPTION=y, CONFIG_SCSI_UFSHCD=y, CONFIG_DM_VERITY=y,
  CONFIG_CRYPTO_XTS=y, CONFIG_CRYPTO_AES=y
stock:      as mesmas 7 opções com os mesmos valores (grep idêntico em audit/config.stock)
```
MEASURED: **toda a pilha de storage/crypto necessária para montar /data é idêntica entre stock e T2** (todas `=y`, built-in, nenhuma depende de módulo).

**M4 — Dependência de storage em módulos vendor (correção parcial ao otimismo do plano):**
```
audit/config.stock: CONFIG_SCSI_UFSHCD_PLATFORM=y, mas CONFIG_SCSI_UFS_MEDIATEK AUSENTE (=m via vendor)
audit/proc/lsmod.txt: ufs_mediatek_mod (usado por rpmb, blocktag, irq_dbg...), ufs_mediatek_dbg, rpmb-mtk
audit/modules/modules.csv: ufs-mediatek-mod.ko, ufs-mediatek-dbg.ko, rpmb-mtk.ko → ramdisk:vb_a_r00 + vb_b_r00
```
MEASURED: o driver UFS MTK **é módulo early-boot no ramdisk do vendor_boot (flash, intocado pelo RAM-boot)**. O gate CRC estendido (fato 23: 0 divergências nos 557 módulos, incluindo os 153 do ramdisk) cobre exatamente esses módulos. Risco residual de mismatch de módulo de storage em T2 ≈ o risco residual do gate (baixo, mas não zero — ver FMEA-19).

**M5 — Backup NÃO contém userdata (permanência de perda):**
```
$ grep -ciE "userdata|user_data|data\.img" backup-2026-10-05/SHA256SUMS.log → 0
$ ls backup-2026-10-05/ → boot/dtbo/gz/init_boot/lk/logo/md1img/nv*/persist/preloader*/proinfo/scp/spmfw/sspm/super/tee/vbmeta*/vendor_boot (+gpt/super headers). Sem userdata.
```
MEASURED: **wipe de /data = perda permanente de dados do usuário** (fotos, apps, etc.). Não há imagem de userdata para restaurar. Este fato eleva a severidade de qualquer cenário de wipe para MÁXIMA.

**M6 — vbmeta_b (cópia em /tmp, backup só lido): chain `boot` → Rollback Index Location 3; vbmeta_b Algorithm SHA256_RSA2048, Rollback Index 0.** MEASURED. T0/T2 têm rollback 0 = mesmo valor do stock → mesmo que o LK leia o footer, nenhum bump de rollback é representável.

---

## 1. FMEA passo a passo (28 cenários; mínimo exigido: 25)

Legenda de desfecho: (a)=bootloop (volta ao normal com power-cycle) / (b)=soft brick (sem boot, recupera via fastboot+backup) / (c)=hard brick (sem fastboot/preloader) / (d)=perda de /data.
Probabilidade honesta para **1 execução** por operador cuidadoso seguindo o documento. Severidade em escala: S0=nada muda, S1=susto recuperável sem tocar flash, S2=exige reflash de boot_b via fastboot, S3=exige serviço Xiaomi / perda permanente.

### Fase P — pré-voo (host, sem aparelho)

**FMEA-01 [P1] SHA256SUMS falha (imagem corrompida/errada) e o dono ignora e prossegue.**
Modo: `sha256sum -c` retorna FALHA (ex.: cópia truncada, confusão T0↔T2). Causa: erro humano ou disco. P=baixa (gate explícito no doc) / S=S1-se-parar; **S2 se prosseguir** (testaria imagem desconhecida). Dono veria: nada ainda (tudo no host). Recuperação: `sha256sum` deve dar 3×OK antes de conectar o cabo; refazer download/cópia; NUNCA `fastboot boot` sem OK. Desfecho se ignorado: (a)/(b). [INFERRED a partir do procedimento; o gate existe no doc — ponto positivo]

**FMEA-02 [P2] `avbtool info_image` mostra footer ≠ NONE / rollback ≠ 0 / header ≠ v4.**
Modo: repack regenerado errado (ex.: usado script v1 sem `--drop-signature`, ou imagem de outro aparelho). P=baixa (medi M2: ambas NONE/0/v4) / S=S1-se-parar; S2+ se prosseguir. Recuperação: comparar byte a byte com os valores da §0 (T0 kernel_size=14555421, T2=14556612, rollback 0); regenerar via `repack_boot_v2.py --drop-signature`; abortar o dia. Desfecho: (a)/(b). [MEASURED M2]

**FMEA-03 [P3] `fastboot --version` ausente/antigo; `lsusb` não lista o POCO (cabo só-carga, porta USB2 com driver ruim, udev sem regra).**
P=média (causa nº 1 de frustração em bring-up; cabo de carga vs dados) / S=S0 (nada executado). Dono veria: `fastboot devices` vazio. Recuperação: só leitura — trocar cabo/porta, `lsusb | grep -i xiaomi`, checar `adb devices`; nunca trocar cabo com comando pendente no fastboot. Desfecho: nenhum. [INFERRED, experiência geral; UNKNOWN específico do host do dono]

**FMEA-04 [P-geral] Falsa identidade do host: imagens T0/T2 de OUTRO build (stale `~/lake-build/out/images/`).**
P=baixa (SHA256SUMS pinado no doc) / S=S2. Recuperação: P1+P2 são o antídoto; checar `ls -la --time-style=full` + hashes contra o plano fato 67. [INFERRED]

### Fase A — aparelho ligado (somente leitura adb)

**FMEA-05 [A1] `adb devices` = unauthorized/offline (autorização RSA revogada, outro host).**
P=baixa/média / S=S0. Recuperação: confirmar prompt RSA na tela do aparelho; `adb kill-server; adb devices`. Sem bypass (não usar `adb tcpip`/reset de keys sem dono). [INFERRED]

**FMEA-06 [A2] Identidade ≠ esperada: `ro.product.device ≠ lake`, ou `slot_suffix=_a`, ou `incremental ≠ OS3.0.306.0.WGTMIXM`, ou `flash.locked=1`, ou `verifiedbootstate ≠ orange`.**
P=baixa (aparelho auditado: lake/_b/OS3.0.306.0/orange/unlocked — MEASURED via `audit/getprop.txt`: `[ro.product.device]: [lake]`, `[ro.boot.slot_suffix]: [_b]`, `[ro.boot.verifiedbootstate]: [orange]`, `[ro.boot.flash.locked]: [0]`) / S=**S2/S3 se prosseguir mesmo assim** (testar kernel em aparelho/estado errado). Dono veria: valores divergentes no A2. Recuperação: **STOP total**; qualquer divergência invalida todas as premissas (fatos 1–2, 62). Em especial: se slot=_a, o aparelho já está no firmware antigo (fato 62) — não testar. Desfecho se ignorado: (a)/(b)/(d). [MEASURED getprop + INFERRED]
ACHADO ADVERSARIAL: o doc manda conferir os valores mas **não diz explicitamente para ABORTAR se `current-slot=a`** — recomendo tornar o aborto explícito (ver §6).

**FMEA-07 [A3] Bateria < 60% (ou `dumpsys battery` indisponível).**
P=baixa / S=S1 (desligamento no meio do RAM-boot = volta ao flash stock, sem dano; masXin desalinhamento de diagnóstico). Recuperação: carregar ≥60% com aparelho ligado antes de R1; se cair durante T0/T2, segurar Power 15 s e recomeçar do zero no dia seguinte. Desfecho: (a). [INFERRED]

**FMEA-08 [A4] Baseline ≠ 429 módulos (ex.: 428/431 — Magisk atualizou, OTA parcial, módulo falhou hoje).**
P=média (ambiente vivo; Magisk em init_boot_b pode mudar sozinho após update de app) / S=S0 (só leitura) mas **invalida o critério de aceite T2.2** se não re-baselineado. Recuperação: regravar `baseline_modules.txt` + `baseline_dmesg.txt` no dia (são leituras); investigar diff antes de prosseguir (módulo faltando HOJE no stock = pista de instabilidade pré-existente). Desfecho se ignorado: falso-positivo/falso-negativo no T2. [MEASURED baseline 429 no fato 55; INFERRED a deriva]

**FMEA-09 [A5] pstore ausente/ilegível (`/sys/fs/pstore` vazio).**
P=baixa (medido fato 53: console-ramoops-0 262132 B + pmsg-ramoops-0 524276 B legíveis por shell) / S=S0, mas remove a rede de observabilidade pós-crash. Recuperação: se vazio, abortar T2 (sem pstore, um panic vira caixa-preta); checar `cat /proc/cmdline | grep ramoops` primeiro. [MEASURED fato 53 + audit/proc/cmdline.txt com `ramoops.mem_address=0x4d010000 ... mem_size=0xe0000`]

**FMEA-10 [A-geral] `adb shell` com Magisk ativo mascara o teste (módulos/root presentes via init_boot_b mesmo no RAM-boot).**
P=alta de confusão (init_boot_b com Magisk continua valendo no RAM-boot — fato 49) / S=S0 para segurança, mas S1 para validade: teste "sem root" contaminado. Recuperação: o doc já desenha verificações sem `su` (fato 49) — reforço: rodar `which su; su -c id` para DOCUMENTAR presença, e exigir que todos os gates passem via uid 2000. Desfecho: nenhum dano; risco é metodológico. [MEASURED fato 49]

### Fase R — entrada no bootloader

**FMEA-11 [R1] `adb reboot bootloader` cai no sistema de novo / tela preta (reboot incompleto).**
P=baixa / S=S0–S1. Dono veria: aparelho reinicia no Android normal ou tela apagada. Recuperação: Vol−+Power físico até fastboot; nunca segurar combinações às cegas >30 s; se vibrar e voltar ao sistema, repetir R1 uma vez; se persistir, abortar (bootloader instável = mau dia para testes). Desfecho: nenhum/(a). [INFERRED; teclas do fato 43]

**FMEA-12 [R2] `fastboot devices` vazio no bootloader (driver fastboot ≠ driver adb).**
P=média (comum em Linux: falta regra udev para o VID/PID em fastboot) / S=S0. Recuperação: `lsusb` antes/depois (P3), cabo/porta, `sudo udevadm` apenas leitura de diagnóstico; **não reinstalar drivers às pressas com aparelho em fastboot** — sem pressa, o flash está intacto. [INFERRED]

**FMEA-13 [R3] `getvar` revela surpresa: `current-slot: a`, ou `(bootloader) unlocked: no`, ou `is-userspace: yes` (caiu em fastbootd, não LK).**
P=baixa para slot (está em _b — MEASURED) / média para fastbootd (comando errado leva a fastbootd) / S=S1-se-parar; **S3 se confundir fastbootd com fastboot e executar `flash` lá** (fastbootd ESCREVE partições lógicas; fato 39: system_dlkm tem COW e fastbootd pode escrever). Dono veria: valores inesperados. Recuperação: `fastboot reboot-bootloader` para voltar ao LK se estiver em fastbootd; conferir `is-userspace: no` antes de qualquer `boot`; **STOP se `unlocked: no`** (realidade mudou). Desfecho se ignorado: (b)/(d). [MEASURED slot atual; INFERRED o resto]
ACHADO: o doc não manda checar `is-userspace` explicitamente antes do T0.1 — recomendo adicionar (ver §6).

**FMEA-14 [R-ambiente] Queda de energia / cabo solto / PC suspende DURANTE fastboot.**
P=baixa / S=S0 para T0/T2 (nada gravado; aparelho em fastboot aguarda) — **esta é a vantagem estrutural do protocolo**. Recuperação: religar cabo, `fastboot devices`, `fastboot reboot`. (Se fosse flash, seria S2/S3 — por isso WRITE é proibido.) [INFERRED]

### Fase T0 — RAM-boot stock-equivalente

**FMEA-15 [T0.1-ramo (a)] `FAILED (remote: unknown command)` — `fastboot boot` inexistente no LK do lake.**
P=**média-alta — ESTE É O UNKNOWN CENTRAL** (fato 10: "outros Xiaomi MTK: bugado/unknown command"; fato 51/OPENCODE2e: gemini-lk tem `cmd_boot` no fonte mas runtime no lake UNKNOWN; o mirror é antigo e pode não corresponder ao LK Xiaomi atual). S=**S0** (nada foi transferido; flash intacto; o próprio doc manda PARAR). Dono veria: mensagem de erro imediata no host; aparelho continua em fastboot. Recuperação: T0.2 `fastboot reboot` → volta ao slot b stock; fim do experimento; decisão nova do dono (fatos 63–64 já preveem). Desfecho: nenhum. [FACT fato 10 + OPENCODE2e_lk_repack_review.md:12-14 — rotulo o runtime como UNKNOWN]
NOTA ADVERSARIAL: este é o desfecho mais provável e é benigno — o plano está correto em testá-lo primeiro com kernel idêntico.

**FMEA-16 [T0.1-ramo (b1)] LK rejeita a imagem (verificação de assinatura do `boot` encadeado mesmo em orange, ou `mboot_android_check_img_info` falha no footer NONE).**
P=média (tolerância AVB em orange MEDIDA para init_boot com hash divergente — fato 48 — mas **para `boot` encadeado é UNVERIFIED**; footer NONE nunca foi tentado no aparelho; `mboot_android_check_img_info(PART_KERNEL)` existe no path do cmd_boot — OPENCODE2e:17-23). S=S0 (rejeição = nada boota; aparelho segue em fastboot). Dono veria: `FAILED (remote: ...)` com outro texto (ex.: verify fail, invalid image). Recuperação: `fastboot reboot`; registrar a mensagem exata (ela decide se T3-flash seria viável um dia). Desfecho: nenhum. [MEASURED fato 48 parcial + UNVERIFIED para boot + OPENCODE2e citação]
ACHADO: o doc só prevê o texto `unknown command`; recomendo tratar **qualquer FAILED como STOP** (ver §6).

**FMEA-17 [T0.1-ramo (b2)] Download interrompido (timeout USB em 64 MiB, `data too large`, `max-download-size` menor).**
P=baixa/média (`max-download-size` será lido em R3; 64 MiB costuma caber) / S=S0 (transferência incompleta não boota). Recuperação: checar `max-download-size` em R3 ANTES (se < 67108864, abortar); trocar porta USB2→USB3/cabo; `fastboot reboot`. [INFERRED]

**FMEA-18 [T0.3] T0 boota mas COMPORTAMENTO ≠ stock (o caso que o T0 existe para capturar): bootloop, tela preta, ou diff em /proc/modules — com kernel byte-idêntico.**
P=baixa (kernel idêntico + header+kernel idênticos ao boot_b — M1; mesma ramdisk vendor_boot do flash; footer NONE é o único delta) / S=S1 (RAM: power-cycle resolve). Causas possíveis se acontecer: (i) footer NONE altera path do LK (ex.: LK pula AVB setup e passa bootconfig/cmdline diferente); (ii) perda do bloco de assinatura GKI AVB0 de 16384 B (fato 47) que o LK talvez valide/leia; (iii) `cmd_boot` do LK antigo ignora ramdisk do vendor_boot (alegação OPENCODE2e:17-24 — **contesto abaixo**). Dono veria: loop no logo, ou boot ok mas módulos faltando. Recuperação: segurar Power 10–15 s → boot_b stock; ler pstore/bugreport; **T2 CANCELADO** (se o stock-equivalente não reproduz o stock, o método `fastboot boot` é inválido no lake). Desfecho: (a). [MEASURED M1 + INFERRED]
CONTESTAÇÃO ADVERSARIAL à OPENCODE2e: a alegação "cmd_boot carrega ramdisk vazio → bootloop/no modules" deriva do gemini-lk **antigo** (era pré-vendor_boot; header v0–v2). Num aparelho com vendor_boot + header v4, o LK de produção precisa montar o boot via vendor_boot de qualquer forma (é assim que o boot normal funciona); `fastboot boot` no LK moderno carrega a imagem enviada e segue o mesmo path de boot (vendor_boot do flash continua lá). Não há evidência local de que o ramdisk seria ignorado — marco o mecanismo como **UNKNOWN**, mas a consequência (bootloop-em-RAM) é idêntica e segura. O T0 foi desenhado exatamente para dirimir isso — correto.

**FMEA-19 [T0/T2-geral] Regressão fantasma: T0 verde mas T2 falha por causa do ÚNICO delta real do kernel novo (cert extra + banner `android15-8-4k` sem `-g…-ab…`).**
P=baixa (gates: symvers idêntico, CRC 1573/0/0, config +1 linha, verify_modsig triplo — fatos 60/65/66) / S=S1. Causa residual honesta: diferença de layout (8,1 MB diferentes no Image — fato 60) afetando timing/endereço de alguma dependência dura early-boot (mrdump/aee dependências de 18/37 módulos — fato 42), ou rejeição de módulo por `disagrees about version` não coberta pelos gates nominais. Recuperação: power-cycle; diff de dmesg/pstore contra baseline; voltar à F3. Desfecho: (a). [MEASURED fatos 60/65/66 + INFERRED residual]

**FMEA-20 [T0.2/T2-abort] `fastboot reboot` não responde após falha (LK travado no protocolo).**
P=baixa / S=S1. Recuperação: segurar Power 10–15 s (documentado no doc §Abortar); se não vibrar/reiniciar em 30 s, aguardar descarga NÃO é opção — manter Power + Vol−; em último caso desconectar cabo e segurar Power (bateria interna não remove; o PMIC faz force-reset por long-press). Desfecho: (a). [INFERRED; UNKNOWN o comportamento exato do long-press neste PMIC — sem fonte local]

### Fase T2 — RAM-boot do kernel novo

**FMEA-21 [T2.1] Kernel panic antes do userspace (pânico early: console preta, reinício espontâneo, ou parado no logo).**
P=baixa (pilha storage built-in idêntica — M3; CRC gates) / S=S1. Dono veria: vibra, logo POCO/Android congela, ou reinicia sozinho para o sistema stock (ver FMEA-27: reboot pós-panic sai do RAM e volta ao flash). Recuperação: deixar reiniciar sozinho OU power-cycle; **não tocar em nada**; após boot normal, `adb shell cat /sys/fs/pstore/console-ramoops-0` + `adb bugreport` (fato 42/53: legível sem root); comparar com baseline; STOP. Desfecho: (a). Nenhuma escrita em misc/flash decorre de panic (mecanismo §3). [MEASURED M3 + INFERRED]

**FMEA-22 [T2.2] Módulos faltando vs baseline 429 (`Unknown symbol`, `disagrees about version`, `exports protected symbol`, `Invalid module format`, `kCFI failure`).**
P=baixa (gates passam; verify_modsig prova o cert — fatos 20/23/65/66) / S=S1 (sintoma parcial, §4). Cenário honesto residual: ordem de `modules.load` do vendor_boot vs nomes, ou-Dependência dura quebrada (mrdump/aee). Recuperação: T2.3 já manda grepar o dmesg; capturar `dmesg` completo + `/proc/modules` diff; power-cycle; STOP. Se `exports protected symbol` aparecer, a hipótese do cert (fato 36–38) está refutada no aparelho → Plano B (system_dlkm próprio, toca vbmeta — decisão nova, fora deste doc). Desfecho: (a) + degradação funcional (§4). [MEASURED fatos + INFERRED]

**FMEA-23 [T2.4] Wi-Fi/BT mortos; modem morto (sem SIM); display preto com adb vivo; `corrupted data`; loop no logo Android — kernel parcialmente subido.**
P=baixa/média para Wi-Fi/BT **se o cert falhar** (é o modo de falha nº 1 conhecido: fato 37 — rfkill/libarc4/bluetooth viram sig_ok=false sem o cert; COM o cert, prova offline OK); baixa para os demais. S=S1 funcional. Ver §4 para sintoma→causa→diagnóstico→ação de cada um. Recuperação geral: nenhuma tentativa de "consertar por dentro" (sem `insmod`, sem `setprop`, sem flash); documentar, power-cycle, STOP. Desfecho: (a). [MEASURED fato 37/66 + INFERRED]

**FMEA-24 [T2.4-corrupt] Tela "Can't load Android system. Your data may be corrupt" (recovery prompt: Try again / Factory data reset).**
P=baixa (exigiria falha de montagem grave com kernel de pilha idêntica — improvável; gatilho realista seria queda no slot A antigo, vedada) / S=**S3-(d) SE o dono tocar em "Factory data reset"**; S1 se escolher Try again. Dono veria: menu em inglês com 2 opções. Recuperação: **"Try again" SEMPRE; NUNCA "Factory data reset"** (o doc proíbe factory reset no §Abortar/fato 64 — correto e deve ser lido em voz alta antes). Mecanismo: recovery só apaga com `--wipe_data` no BCB ou escolha explícita do usuário (citações AOSP §2). Desfecho: (a) ou **(d) permanente** (M5: sem backup de userdata). [AOSP recovery.cpp + INFERRED]
Este é o vetor de perda de dados nº 1 do protocolo: **humano, não técnico**.

**FMEA-25 [T2.5] `adb bugreport` trava / enche /data (zip 36 MB medido no fato 54; com kernel defeituoso pode crescer).**
P=baixa / S=S0–S1 (escrita legítima em /data, não destrutiva; risco é espaço). Recuperação: se travar, Ctrl-C + `adb reboot`; apagar o zip do aparelho depois (`adb shell rm`) para não lotar /data. Desfecho: nenhum/(a). [MEASURED fato 54]

**FMEA-26 [T2-pós] Slot _b marcado unbootable pelo bootctl userspace durante T2 parcial → próximo boot normal cai no SLOT A (firmware OS3.0.20.0 antigo sobre /data nova).**
P=baixa (exige T2 parcial que suba até userspace + health-check falhando + retry esgotado; retry-count no lake UNKNOWN — OPENCODE2e:26-38) / S=**S2/S3-(d)**: boot de firmware antigo sobre dados novos = tela de corrupção/upgrade forçado, risco de prompts de wipe e de anti-rollback. Dono veria: após T2.6, aparelho boota estranho (versão antiga, apps quebrando). Recuperação: **interromper antes do boot normal**: ainda em fastboot após T2, rodar `fastboot getvar all` e (se exposto) `slot-successful / slot-retry-count / slot-unbootable` dos dois slots; se _b marcado ruim, `fastboot set_active b` NÃO — set_active é WRITE proibido... **aqui o doc tem lacuna**: recomendo exceção documentada de recuperação (`fastboot set_active _b` só se _b foi marcado unbootable pelo teste, com autorização do dono) OU `fastboot reboot` + checagem de `ro.build.version.incremental` no primeiro boot (se ≠ OS3.0.306.0, desligar e voltar ao fastboot). Ver §6. Desfecho se ignorado: (a)/(b)/(d). [INFERRED a partir de fato 62/64 + AOSP ab_implement (slot-retry-count/successful) + OPENCODE2e UNKNOWN]
ACHADO ADVERSARIAL PRINCIPAL do protocolo: **falta verificação de estado dos slots entre T2.6 e o boot normal**.

**FMEA-27 [Pós-panic] Reboot espontâneo após panic volta para ONDE?**
Análise: panic → reboot → LK → boot default do flash (slot _b stock), porque a imagem RAM evaporou (cmd_boot faz memmove para SCRATCH_ADDR em RAM — OPENCODE2e:17-23 — sem escrita em flash). P=alta de ser benigno / S=S1. Dono veria: aparelho "se cura sozinho" e volta ao sistema normal. Recuperação: confirmar `uname -r` stock + ler pstore (o ramoops SOBREVIVE ao reboot — é reserved-memory — fato 42). Desfecho: (a). [FACT OPENCODE2e + MEASURED fato 42]
Exceção honesta: se o reboot cair em fastboot (tecla presa, cabo), usar `fastboot reboot`. Se cair em recovery com prompt, ver FMEA-24.

**FMEA-28 [Transversal] Dono executa comando da lista PROIBIDA por engano (`flash`, `erase`, `set_active a`, `oem`, `reboot-recovery`, `dd`).**
P=baixa com operador atento / S=**S2–S3-(d)**: `set_active a` = firmware antigo (fato 62); `flash boot_b` sem hash = sem rollback garantido; `erase` = brick de dados; `flashing lock` = **tijolo funcional + wipe** (relock apaga /data por desenho). Recuperação: depende do comando (cada um tem rollback próprio; `flash boot_b <backup>` com hash é o único WRITE pré-aprovado como T3 futuro). Mitigação proposta: alias/shell-guard no host (`fastboot() { case "$*" in *flash*|*erase*|*lock*|*set_active*) echo BLOQUEADO;; *) command fastboot "$@";; esac; }`) + colar comandos do doc, nunca digitar. Desfecho: (b)/(c)/(d). [INFERRED; lista proibida no próprio doc — ponto positivo]

**Contagem: 28 cenários (P:4, A:6, R:4, T0:6, T2:8). Nenhum cenário plausível de (c) hard-brick encontrado na sequência T0/T2 como escrita** — o único (c) herdado é pré-existente (preloader/BROM, fora do doc) e citado para contexto no §5.

---

## 2. RISCO DE PERDA DE DADOS — análise do fstab real (prioridade máxima)

### 2.1 O que o fstab do aparelho diz (citações exatas)

Fonte: `<lake-kernel>/audit/system/fstab.txt` (= `/vendor/etc/fstab.mt6768` do aparelho).

Linha 73 — **/data**:
```
/dev/block/by-name/userdata /data f2fs ... wait,check,formattable,quota,latemount,resize,...,checkpoint=fs,fileencryption=aes-256-xts:aes-256-cts:v2,keydirectory=/metadata/vold/metadata_encryption
```
Flags presentes em /data: `wait, check, formattable, quota, latemount, resize, checkpoint=fs, fileencryption=...v2, keydirectory=/metadata/...`.
Flags **AUSENTES** em /data: `wipe`, `nofail`, `first_stage_mount`, `avb`, `logical`, `formattable` está presente mas **não há flag `wipe`** em nenhuma linha do arquivo (verificado: `grep -rn wipe audit/system/` → vazio — MEASURED).

Linha 68 — **/metadata** (guarda a chave de metadata_encryption + chaves vold):
```
/dev/block/by-name/md_udc /metadata ext4 ... wait,check,formattable,first_stage_mount
```
Linha 77 — **/cache (rescue)**: `wait,check,formattable`. Linhas 79–86 (protect_f/s, nvdata, nvcfg, rescue, persist): todas `wait,check,formattable` — **formattable é o padrão do vendor MTK, não um pedido de auto-formatação**.

Respostas diretas às perguntas do enunciado:
- `formattable` em /data? **SIM** (fstab.txt:73). Significado correto (AOSP): "pode ser formatada pelo recovery / ignora falha em first-stage" — **não** "formata sozinha ao falhar" (prova abaixo).
- `wipe`? **NÃO existe em nenhuma entrada** (grep vazio). Não há `latemount`+`wipe` nem `wipe_data` no fstab.
- `latemount` em /data? **SIM** (fstab.txt:73) → /data é montada **tarde, pelo vold no late-fs**, não no first-stage. Falha aqui ≠ morte do init first-stage.
- `checkpoint=fs` em /data? **SIM** (fstab.txt:73). É o checkpoint de UserData durante OTA Virtual A/B (snapuserd); fora de OTA, inerte. Nenhuma OTA estará em curso no teste (verificação A2 garante build estável; INFERRED).
- `fileencryption=...v2,keydirectory=/metadata/...` + `inlinecrypt` (fstab.txt:73; `inlinecrypt` também em `mounts.txt:77` — `dm-61 /data f2fs ... inlinecrypt ...`) → FBE v2 com wrapped keys; chaves em /metadata + TEE. Stack kernel: F2FS=y, FS_ENCRYPTION=y, BLK_INLINE_ENCRYPTION=y, DM_DEFAULT_KEY=y, UFS=y — **todos built-in e idênticos stock↔T2 (M3)**.

### 2.2 O que acontece se /data NÃO montar (módulo/feature faltando)? — com código AOSP

Três camadas, nenhuma formata sozinha:

**(i) First-stage (não se aplica a /data, mas a /metadata):** `system/core/init/first_stage_mount.cpp` (AOSP main, via espelho aospapp/aosp + googlesource):
```cpp
} else if (current->fs_mgr_flags.formattable) {
    LOG(INFO) << "Failed to mount " << current->mount_point
              << ", ignoring mount for formattable partition";
} else {
    PLOG(ERROR) << "Failed to mount " << current->mount_point;
    return false;   // → first_stage_init.cpp: LOG(FATAL) "Failed to mount required partitions early"
}
```
FACT (fonte externa lida via busca): falha em partição `formattable` no first-stage é **ignorada com log**, não formatada; falha em partição requerida é FATAL (morte do init → panic → reboot — sem escrita). URL: `https://android.googlesource.com/platform/system/core/+/refs/heads/main/init/first_stage_mount.cpp`.

**(ii) Legacy `fs_mgr_mount_all` (second-stage / late):** `system/core/fs_mgr/fs_mgr.cpp` — o formato só ocorre sob conjunção estrita:
```cpp
wiped = partition_wiped(current_entry.blk_device...);
if (mount_errno != EBUSY && mount_errno != EACCES &&
    current_entry.fs_mgr_flags.formattable && wiped) {
    ... fs_mgr_do_format(...) ...
} else { ... "Suggest recovery..." ... }
```
FACT (fonte externa lida): `fs_mgr_do_format` só roda se `partition_wiped()==true`, i.e., **partição já esvaziada** (fresh/zerada) — formata partição vazia, **não apaga partição populosa que falhou ao montar**; se há dados ilegíveis, o caminho é `FS_MGR_MNTALL_DEV_NEEDS_RECOVERY` ("Suggest recovery"). URL: `https://chromium.googlesource.com/aosp/platform/system/core/+/master/fs_mgr/fs_mgr.cpp` e `https://android.googlesource.com/platform/system/core/+/main/fs_mgr/fs_mgr.cpp`.

**(iii) /data latemount é montada pelo vold (FBE):** falha de vold (chave, crypto, f2fs) → init não completa `sys.boot_completed` → aparelho cai em recovery com o prompt documentado abaixo. O vold **não tem path de `mkfs`** sobre /data populosa. (INFERRED de arquitetura FBE; sem fonte local — marco como INFERRED, não FACT.)

**(iv) Quem REALMENTE apaga:** `bootable/recovery/recovery.cpp` — wipe somente por (a) `--wipe_data` escrito no BCB (misc) pelo sistema ou (b) escolha explícita do usuário no menu:
```
* FACTORY RESET: 1. user selects "factory reset" → 2. main system writes "--wipe_data" ...
* 4. get_args() writes BCB with "boot-recovery" and "--wipe_data" → 5. erase_volume() reformats /data
prompt_and_wipe_data(): menu {"Try again", "Factory data reset"}; chosen_item != 1 → "Just reboot, no wipe"
```
FACT (fonte externa lida): wipe exige comando no BCB ou dedo humano; "Try again" reinicia sem apagar. URLs: `https://android.googlesource.com/platform/bootable/recovery/+/HEAD/recovery.cpp`, `.../recovery_main.cpp`.

**(v) RescueParty (escalada automática?):** `RescueParty.java` + doc `source.android.com/docs/core/tests/debug/rescue-party`: dispara com **system_server reiniciando >5× em 5 min OU app persistente crashando >5× em 30 s**; nível final = reboot ao recovery com `--prompt_and_wipe_data` (**prompt**, exige confirmação do usuário; "devices must provide a way for users to confirm any destruction"). E o detalhe decisivo para este protocolo: **"Rescue Party suppresses all rescue events when the device has an active USB data connection"** — T0/T2 ocorrem com cabo USB de dados conectado (adb). FACT (fonte externa lida). Consequência: panics de kernel (nunca chegam ao system_server) **jamais** alimentam RescueParty; e mesmo boots parciais com USB conectado são suprimidos.

### 2.3 Probabilidade de wipe por passo + como o plano evita

| Passo | P(wipe) honesta | Mecanismo único plausível | Como o plano evita |
|---|---|---|---|
| P (host) | **0** | nenhum (sem aparelho) | — |
| A (adb leitura) | **0** | nenhum comando escreve | classes READ; sem `adb shell` com redirecionamento para /dev/block |
| R (reboot bootloader) | **0** | reboot não escreve misc/data | sem BCB envolvido; `reboot bootloader` é reboot frio ao LK |
| T0 (RAM stock) | **≈0** (só via FMEA-24 humano) | kernel idêntico → montagens idênticas; panic não escreve misc; RescueParty suprimido por USB | T0 testa o método com risco zero de divergência de montagem |
| T2 (RAM cert) | **baixa, dominada por fator humano** (FMEA-24, FMEA-26) | pilha /data idêntica (M3) → falha de montagem exigiria quebra fora do kernel (praticamente só via slot A, vedado); wipe exigiria dedo em "Factory data reset" ou BCB com --wipe_data, que RAM-boot não escreve | proibição de factory reset (fato 64 + §Abortar); cabo USB (suprime RescueParty); STOP em qualquer prompt + foto da tela antes de tocar |

Conclusão §2: **nenhum passo T0/T2 contém mecanismo automático de formatação de /data populosa** (fstab sem `wipe`; fs_mgr só formata partição já vazia; vold não tem path de mkfs; wipe exige BCB/usuário; RescueParty exige userspace + USB suprime). A probabilidade técnica de wipe automático é ≈0; o risco residual é **humano** (FMEA-24) e **topológico** (FMEA-26, slot A) — ambos mitigáveis pelas adições do §6. Severidade, porém, é MÁXIMA (M5: sem backup de userdata).

---

## 3. `fastboot boot` altera estado persistente? (misc/boot_para, boot_reason, AVB/rollback, verity, dtbo/vbmeta)

Método: 3 abordagens — (1) fonte LK citada em OPENCODE2e, (2) estado medido no aparelho/backup, (3) fontes AOSP externas. Onde nenhuma alcança: UNKNOWN explícito.

**3.1 Contadores A/B (misc/boot_para, slot-retry-count, slot-successful/unbootable).**
- FACT (OPENCODE2e_lk_repack_review.md:26-38): o mirror gemini-lk **não implementa variáveis A/B** (`grep retry-count|boot_para|ab_boot|set_active|slot.*successful` → vazio); formato MTK/Xiaomi dos contadores é proprietário; retry inicial no lake UNKNOWN; `misc/boot_para` per AOSP `ab_implement` mas formato MTK proprietário.
- INFERRED: `cmd_boot` (OPENCODE2e:17-23) faz `memmove(...SCRATCH_ADDR...)` + `boot_linux()` — path sem escrita em flash no trecho citado. Um RAM-boot **bem-sucedido até userspace** roda o bootctl HAL do sistema, que opera sobre o slot corrente (_b) e **pode** decrementar/incrementar retry e marcar successful/unbootable — esse é o vetor do FMEA-26. Um RAM-boot que **falha antes do userspace** não executa bootctl → nenhum contador muda por essa via.
- **UNKNOWN**: (a) se o LK do lake decrementa slot-retry-count ao tentar `fastboot boot`; (b) valor inicial do retry; (c) se `fastboot boot` altera `boot_para`. Mitigação proposta no §6 (ler getvar dos dois slots após T2).

**3.2 `boot_reason`.**
- MEASURED: `audit/proc/cmdline.txt` contém `aee_aed.pureason=reboot` (reason passada via cmdline/tags pelo LK a cada boot).
- INFERRED: boot_reason é derivado por boot (propriedade `ro.boot.bootreason`/`sys.boot.reason`), não um contador persistente que um RAM-boot corrompa; panic gera `kernel_panic`/`reboot` no próximo boot — diagnóstico, não dano. **UNKNOWN** parcial: se o LK persiste último bootreason em `para`/`misc` (formato proprietário MTK) — sem efeito conhecido sobre dados.

**3.3 Flags AVB/rollback (stored_rollback_index em RPMB/persist).**
- MEASURED: vbmeta_b rollback 0 (M6); boot_b footer rollback 0 (M2); T0/T2 footers rollback 0 (M2). RPMB é acessado via `rpmb-mtk.ko` + `rpmb` (lsmod MEASURED).
- INFERRED (forte): stored_rollback só avança quando um boot **verificado com sucesso** apresenta rollback_index maior; 0→0 não representa avanço sob nenhuma implementação; e em orange/unlocked o LK tolera divergências (fato 48). Um RAM-boot com falha não completa verificação → não escreve RPMB. Escrita em RPMB exige autenticação com chave — path inexistente no `cmd_boot` citado.
- **UNKNOWN** residual: comportamento exato do LK Xiaomi ao ver footer NONE (aceita? ignora? registra?). Sem evidência local — mas o pior caso observável (FMEA-16) é rejeição sem escrita.

**3.4 `verity` state / marcadores `dm-verity corrupted`.**
- INFERRED: estado dm-verity é **em memória** (tabelas construídas do vbmeta do flash + super do flash, ambos intocados); corrupção leva a EIO/reboot, não a marcador persistente gravado pelo kernel. `vbmeta`/`dtbo`/`vendor_boot` do flash não são tocados pelo protocolo (nenhum WRITE). **UNKNOWN**: se o LK mantém "verity corrupted" sticky em `misc`/`para` proprietário — sem fonte; sem mecanismo conhecido no AOSP (verity não grava sticky bits; o que existe é o prompt de corrupção com escolha do usuário — cf. FMEA-24).

**3.5 dtbo/vbmeta.**
- FACT: o protocolo não referencia dtbo/vbmeta em nenhum passo; LK usa dtbo_b/vendor_boot do flash normalmente. RAM-boot não os altera (sem WRITE). MEASURED que ambos os slots têm seus descritores íntegros (fato 48: dtbo/vendor_boot/init_boot_a conferem com vbmeta_a).

**Resumo §3: RAM-BOOT ALTERA ESTADO PERSISTENTE: NÃO por nenhum mecanismo evidenciado** (flash intacto por construção do protocolo; rollback 0=stock; verity em RAM; BCB/misc sem escritor no path de falha), **com UNKNOWN explícitos**: decremento de retry pelo LK (3.1a), formato/efeito de boot_para (3.1c), sticky proprietário de verity (3.4). Nenhum UNKNOWN mapeia para wipe automático (§2).

---

## 4. Kernel novo sobe parcialmente — sintoma→causa→diagnóstico→ação

Regra geral: **só comandos de leitura; nenhuma tentativa de conserto "por dentro"** (sem insmod/rmmod/setprop/mount manual — mascaram o gate e arriscam estado); documentar, power-cycle, STOP, ler pstore/bugreport do boot normal.

| # | Sintoma | Causa mais provável (honesta) | Diagnóstico só-leitura | Ação segura |
|---|---|---|---|---|
| S1 | Wi-Fi/BT mortos (`wlan0` ausente, BT não liga), resto ok | `rfkill.ko/libarc4.ko/bluetooth.ko` (GKI system_dlkm) com sig_ok=false → `exports protected symbol` (fato 37); hipótese do cert refutada no aparelho | `dmesg \| grep -iE "exports protected symbol\|Unknown symbol\|Invalid module"` ; `ls /sys/class/net` ; `cmd wifi status` | Nenhum fix no aparelho; power-cycle; STOP; Plano B = system_dlkm próprio (fora deste doc) |
| S2 | Modem morto (`gsm.sim.state` ≠ READY, sem IMEI/baseband) | módulo MTK de modem (ccci_*) não carregou; ou dependência dura quebrada | `getprop gsm.sim.state; getprop gsm.version.baseband` ; `dmesg \| grep -iE "ccci\|modem\|md1"` ; `lsmod \| grep ccci` | Idem; checar no pstore se houve panic no subsys modem |
| S3 | Display preto MAS adb vivo (`adb devices` lista, shell responde) | DRM/MDP/GPU vendor (mediatek_drm, mali) ou LCM ok mas SurfaceFlinger/composer falhou; kernel subiu | `adb shell dumpsys SurfaceFlinger \| grep -i GLES` (já no T2.4) ; `dmesg \| grep -iE "drm\|panel\|lcm\|backlight"` ; `getprop sys.boot_completed` | Capturar `bugreport` (vale ouro aqui); `adb reboot`; STOP |
| S4 | Display preto E adb morto, LED/vibra presente | panic após montagens ou hang em driver de display/audio; ou boot travado antes do adb | Sem diagnóstico remoto → evidência física (LED, vibração, calor) + aguardar 3 min (limite do doc) | Power 10–15 s; boot normal; ler `console-ramoops-0` + bugreport; STOP |
| S5 | Tela "Can't load Android system... data may be corrupt" | montagem falhou (ou queda no slot errado — checar!) | Fotografar a tela; anotar o "Reason:" exibido; escolher **Try again** | NUNCA Factory data reset (FMEA-24); após Try again confirmar `ro.build.version.incremental`=OS3.0.306.0 (exclui slot A); STOP |
| S6 | Loop no logo "Android" (>3 min, sem adb) | boot Services travados (ex.: vold esperando /data; HALs em crash-loop contido) | `adb wait-for-device` com timeout; se entrar, `logcat -b all \| grep -iE "vold\|fs_mgr\|FATAL\|crash"` | Power-cycle aos 3 min (regra do doc); pstore+bugreport; STOP. Se repetir 2×, RescueParty pode estar contando (com USB, suprimido — FACT §2v) — mesmo assim, não insistir: STOP após 1ª reprodução documentada |

---

## 5. Os 5 piores desfechos realistas + GO/NO-GO

**TOP-5 (probabilidade honesta por execução, operador cuidadoso):**
1. **`fastboot boot` inexistente/bugado no lake → dia perdido, zero dano** (P=média-alta, S=S0). É o desfecho mais provável e benigno; o protocolo o absorve (T0.2). [FACT fato 10]
2. **T2 parcial: Wi-Fi/BT mortos por refutação do cert no aparelho** (P=baixa, S=S1 funcional; volta ao stock com power-cycle). Modo de falha nº 1 conhecido, com Plano B mapeado. [MEASURED fatos 37/66]
3. **Slot _b marcado unbootable durante T2 parcial → próximo boot cai no slot A (OS3.0.20.0) sobre /data nova** (P=baixa, S=S2/S3-(d)). Único vetor plausível de escalada para perda de dados sem dedo humano. Exige a verificação do §6. [INFERRED FMEA-26]
4. **Dono escolhe "Factory data reset" na tela de corrupção** (P=baixa se briefado, S=S3-(d) permanente — M5: sem backup de userdata). Vetor de wipe nº 1. [AOSP recovery.cpp + M5]
5. **Comando proibido por engano (`set_active a`, `flash`, `erase`, `flashing lock`)** (P=baixa, S=S2–S3-(b/c/d)). `flashing lock` = wipe por desenho + possível tijolo. Mitigável com shell-guard (§6). [INFERRED FMEA-28]

Explicitamente **fora** do TOP-5 por implausibilidade evidenciada: hard-brick (c) — nenhum passo escreve preloader/lk/seccfg/nv*; wipe automático por software — refutado no §2.

**GO/NO-GO T0:** **GO CONDICIONAL** — se e somente se: (i) P1 3×OK + P2 confere com §0 (NONE/0/v4, kernel_sizes 14555421); (ii) A2 identidade exata (lake/_b/OS3.0.306.0/orange/unlocked) com **aborto explícito se slot≠_b**; (iii) bateria ≥60%; (iv) baseline A4/A5 recapturados no dia; (v) R3 com `is-userspace: no`; (vi) dono briefado: qualquer FAILED=STOP, "Try again" sempre, nunca factory reset. Se `unknown command` → NO-GO para T2 (nada mudou; fim).
**GO/NO-GO T2:** **GO CONDICIONAL** — somente se T0 ramo (b)+T0.3 100% verde (boot stock-equivalente indistinguível: módulos diff vazio, dmesg limpo) **e** todas as condições do T0 **e** após T2.6: checar estado dos slots antes do primeiro boot normal (adição §6). 1ª anomalia em qualquer gate → NO-GO definitivo do dia (sem "tentar de novo com outro cabo" mais de 1×; sem insistência — insistência alimenta os únicos vetores de escalada: FMEA-26 e RescueParty).

---

## 6. Achados do revisor (lacunas reais no DEVICE_COMMANDS_T0_T2.md)

1. **[FMEA-06] Sem aborto explícito para `current-slot=a`.** Adicionar em R3: `fastboot getvar current-slot` → se ≠ `b`, STOP (fato 62).
2. **[FMEA-13] Sem checagem `is-userspace`.** Adicionar em R3: exigir `is-userspace: no` (prova de LK real, não fastbootd) antes de T0.1.
3. **[FMEA-16] Só prevê `unknown command`.** Generalizar T0.1: **qualquer `FAILED (...)` → T0.2 + STOP** (rejeição de assinatura é o ramo mais informativo).
4. **[FMEA-26 — principal] Sem verificação de slots pós-T2.** Adicionar entre T2.6 e o boot normal: em fastboot, `fastboot getvar all` (+ `slot-successful:_a/_b`, `slot-retry-count:_a/_b`, `slot-unbootable:_a/_b` se expostos); primeiro boot normal só após confirmar _b saudável; no Android, confirmar `ro.build.version.incremental`=OS3.0.306.0 antes de desbloquear a tela. Exceção de recuperação documentada: se _b marcado unbootable pelo teste, autorizar `fastboot set_active _b`? NÃO — recomendo em vez disso: não sair do fastboot, fotografar getvar, e decidir com calma (o flash de _b está intacto; o marcador é reversível por boot bem-sucedido futuro ou por `set_active` deliberado fora do protocolo).
5. **[FMEA-28] Sem guarda contra comando proibido.** Adicionar shell-guard no host + regra "colar, nunca digitar" + conferência em voz alta antes de cada T (dois pares de olhos no `boot` vs `flash`).
6. **[FMEA-08] Baseline do dia.** Tornar A4/A5 obrigatoriamente recapturados no dia (não reutilizar baseline antigo).

## 7. PROVA DE SABOTAGEM (auto-teste da FMEA: passo hipotético `fastboot flash vbmeta_b vbmeta_b.img`)

Aplico a mesma grade a um WRITE real para demonstrar que ela dispara:
- **Classe:** WRITE em cadeia de verificação AVB (proibido pelo doc; aqui hipotético).
- **Modos de falha:** (i) imagem com hash/assinatura divergente do resto do slot → LK em orange tolera (fato 48) mas em cenário de relock futuro = brick; (ii) interrupção USB no meio do flash → **vbmeta_b corrompido → slot _b não boota E fallback A/B pode não salvar (slot A é firmware antigo — fato 62) → soft-brick S2 com recuperação só via fastboot + backup**; (iii) `flash vbmeta_b` com arquivo errado (ex.: vbmeta_a ou de outro aparelho) → boot recusado, rollback-index-location embaralhado → S2/S3; (iv) em `flashing locked` hipotético = recusa + risco de wipe.
- **Probabilidade:** média de algo dar errado sem os gates P1/P2 (que para flash exigiriam verificação de digest contra `avbtool info_image` do backup — ausente no hipotético).
- **Severidade: ALTA (S2, beirando S3)** — gravação irreversível sem o próprio backup como rede; quebra a invariante "flash intacto" que sustenta toda a segurança de T0/T2; recuperação exige `fastboot flash vbmeta_b <backup>` (que pressupõe fastboot vivo — se o LK rejeitar tudo, S3/serviço Xiaomi, fato 41).
- **Veredito da grade: NO-GO como teste; só como recuperação documentada (T3).**
A FMEA marca o hipotético como **risco alto com recuperação complexa**, enquanto marca T0/T2 como S0/S1 — a grade discrimina corretamente WRITE vs RAM.

## 8. Auto-revisão (rebaixamentos aplicados)

- Afirmação "LK tolera footer NONE em orange" → rebaixada para **UNVERIFIED** (FMEA-16; fato 48 cobre init_boot-hash, não boot-NONE).
- "cmd_boot ignora ramdisk do vendor_boot" (OPENCODE2e) → contestada e marcada **UNKNOWN** (FMEA-18; fonte antiga, sem evidência no aparelho).
- "formattable = pode auto-formatar" → **refutada** com código AOSP (§2.2 i–ii); `formattable` em first-stage = ignora falha.
- "RescueParty pode dar wipe sozinho" → **refutada**: nível final é prompt com confirmação obrigatória + supressão com USB conectado (FACT §2.2v).
- Todo "provavelmente ok" sem número foi substituído por P explícita com justificativa ou UNKNOWN.
- Nenhum achado inventado onde a evidência falta: passo 3 carrega 4 UNKNOWNs explícitos (§3.1a/c, §3.2-parcial, §3.4-sticky).

## 9. Fontes (todas verificáveis)

- Plano: `tabs-agent-os/.hermes/plans/2026-10-05_kernel-hunter-lake-PLANO-v2.md` (fatos 1–67; Tabelas F6, §4).
- Alvo: `lake-kernel/research/DEVICE_COMMANDS_T0_T2.md` (P/A/R/T0/T2 + lista proibida).
- fstab: `lake-kernel/audit/system/fstab.txt:68,73,74,77,79-86,107,113` ; ausência de `wipe`: grep vazio em `audit/system/`.
- Estado: `audit/getprop.txt` (lake/_b/orange/unlocked/OS3.0.306.0), `audit/proc/cmdline.txt` (ramoops), `audit/proc/lsmod.txt` (ufs_mediatek_mod, rpmb), `audit/modules/modules.csv` (ufs-mediatek-mod.ko ramdisk), `audit/config.stock` (F2FS/DM_DEFAULT_KEY/FS_ENCRYPTION/UFS/verity/XTS), `audit/proc/mounts.txt:77` (/data f2fs inlinecrypt dm-61).
- Backup (só lido): `backup-2026-10-05/` (sem userdata — M5), `boot_b.img`/`vbmeta_b.img` (rollback 0 — M6).
- Imagens (cópias /tmp): T0/T2 hashes+headers+footers (M1–M2); `dist_cert/Image` = T2 descomprimido (M1); `.config` da dist_cert = stock+1 linha (M3).
- LK: `research/OPENCODE2e_lk_repack_review.md:9-38` (cmd_boot, SCRATCH_ADDR, ausência de A/B no mirror, retry UNKNOWN).
- AOSP: `platform/system/core/+/refs/heads/main/init/first_stage_mount.cpp` (formattable→ignore); `platform/system/core/+/main/fs_mgr/fs_mgr.cpp` (formato só se wiped); `platform/bootable/recovery/+/HEAD/recovery.cpp` + `recovery_main.cpp` (wipe só via --wipe_data/escolha); `services/core/.../RescueParty.java` + `source.android.com/docs/core/tests/debug/rescue-party` (gatilhos 5×/5min, prompt final, supressão com USB).
