# CODEX6_review_repack — revisão adversarial de research/repack_boot.py (OpenCode #2)

> Data: 2026-10-05. Método: leitura linha a linha + fuzz de 32 casos + 2ª via por `unpack_bootimg`/`avbtool info_image`/python independente. Trabalho em `<HOME>/codex-work/fuzz` (cópias; audit/backup/official intactos; stock jamais sobrescrito — o caso in-place usou cópia). Nada flashado, sem adb.
> Legenda: `FACT` (URL/saída) / `MEASURED` (saída colada) / `INFERRED` / `UNVERIFIED` / `UNKNOWN`.

## 0. O que o script faz (lido, v1 de 105 linhas) e o que o OPENCODE2e mediu

- Parse do header v4 (`kernel_size@8`, `ramdisk_size@12`, `header_version@40`, zera `signature_size@1580`), kernel em offset 4096, footer por `rfind(b"AVBf")`; saída = header + kernel novo + pad 4096; footer via `avbtool add_hash_footer` (default NONE) ou `--keep-footer`.
- `MEASURED` (OPENCODE2e §2, refeito por mim em 2ª via §4): baseline header+kernel idênticos ao stock; footer stock `SHA256_RSA2048 image 14577664` vs novo `NONE image 14561280`; delta 16384 B = bloco de assinatura GKI.
- Layout do stock decodificado por mim (2 métodos: python + `avbtool info_image`): header(4096) + kernel gzip padded (14555421→14557184; fim 14561280) + **assinatura GKI 16 KiB `AVB0` (14561280..14577664)** + zeros + footer `AVBf` de 64 B em 67108800..67108864 (partição 67108864). `signature_size@1580` do stock = **0**.

## 1. Tabela BUG/BORDA → gravidade → correção (v2) → teste que prova

| # | achado (v1) | grav | correção na v2 (`research/repack_boot_v2.py`) | teste |
|---|---|---|---|---|
| B1 | input <44 B → `struct.error` traceback (medido: 20 B) | média | checa `len<4096` + try em unpack | 09b |
| B2 | `ramdisk_size!=0` ignorado: ramdisk descartado em silêncio, exit 0 (medido: `R*4096` sumiu do OUT) | **alta** | recusa `ramdisk_size!=0` | 13 |
| B3 | bloco AVB0 16 KiB descartado sem aviso; `@1580` zerado em silêncio | **alta** | detecta `AVB0`/sig_size e exige `--drop-signature` (keep-footer preserva e não pede) | 26, baseline |
| B4 | gzip só pelo magic: gzip corrompido (1 MB de 14 MB) aceito, exit 0 | **alta** | descompressão real + `d.eof` + teto 256 MiB | 16 |
| B5 | saída existente sobrescrita em silêncio; entrada==saída destrói o original (medido: `ovw.img` virou ANDROID!) | **alta** | recusa sem `--force`; entrada==saída sempre recusa | 17, 18 |
| B6 | avbtool ausente → `FileNotFoundError` traceback | média | checa `shutil.which`, exit 2 com instrução | 19 |
| B7 | avbtool falha → `CalledProcessError` traceback + `.nosig`/`.tmp` abandonados (medidos: 8 leftovers) | média | captura saída, erro limpo, `try/finally` + tempfile no dir de saída | 21, 22 |
| B8 | `body+256` mágico insuficiente (caso 22 passou no check e quebrou no avbtool) | média | teto `body+VBMETA_MAX_SIZE(64K, libavb)+footer` | 22 |
| B9 | rollback negativo → traceback do avbtool | baixa | valida `>=0` | 21 |
| B10 | `--salt`×NONE: avbtool ACEITA (medido: footer com salt, exit 0) — sem bug; documentado | info | repasse + documenta determinismo via salt fixo | 20, 25 |
| B11 | saídas não-determinísticas por default (salt aleatório do avbtool; medido: 63 B diferem; com salt fixo sha256 iguais) | média | documenta; teste de determinismo usa salt fixo | 25 |
| B12 | footer só por magic `rfind`: aceitaria `AVBf` fora do fim; campos em LE dariam leitura errada (footer é BE) | média | valida magic+versão major 1+offsets sãos (BE, cf. `avb_footer.h:53-67`)+posição no fim | 11, 12 |
| B13 | `out` variável morta; `.nosig` no CWD (colisão/concorrência) | baixa | removida; tempfile no dir do OUT | — |
| B14 | `--keep-footer` zerava o gap (bloco AVB0+vbmeta intermediária) em vez de preservar: OUT diferia do stock em 4607 B mesmo com kernel idêntico (medido) | média | preserva `orig[body:footer_off]` verbatim; `cmp` agora byte-idêntico | keep-manual |
| OK | `signature_size@1580`: **correto** (v4 = v3(1580B)+u32 → total 1584; `bootimg.h:413-415`) | — | mantido, agora com leitura prévia | 26, 31 |
| OK | página 4096 fixa: **correto p/ v3+** (`bootimg.h:232,341`) | — | mantido + citado | 06, 07 |
| OK | sem `image_size` stale: v3/v4 **não têm** campo image_size (offsets 44/48 são cmdline) | — | hipótese descartada após leitura do fonte | 28 |
| OK | endianness `<I` no header: **correto** (bootimg é LE; só o footer AVB é BE) | — | mantido | — |

Casos sem bug (passam iguais): 01–05, 08, 10, 14, 15, 24, 27, 29, 30. Total **32 casos** (31 fuzz + determinismo com salt fixo).

## 2. Descarte do bloco AVB0: quem verifica a assinatura GKI?

- `FACT` (`bootimg.h:413-415` + `mkbootimg.py`, refs/heads/main): v4 = v3 + `signature_size`; `add_boot_image_signature`: "the signature will only be verified in VTS to ensure a generic boot.img is used. **It will not be used by the device bootloader at boot time. The bootloader should only verify the boot vbmeta** ... via Android Verified Boot".
- `FACT` (source.android.com boot-image-header): "boot_signature ... The check is done in VtsSecurityAvbTest ... **isn't involved in the device-specific verified boot process and is only used in VTS**".
- `MEASURED` (grep `AVB0` em `libavb/avb_slot_verify.c` = **0** ocorrências): a libavb trata o bloco como dado opaco — só entra no hash da partição.
- 3 vias → conclusão: descartar o bloco só muda o hash (recoberto pelo footer novo); nenhum verificador de boot o exige. **Sim em orange**, com a ressalva LK-Xiaomi abaixo.

## 3. Footer NONE numa chain partition em orange: tolera ou rejeita?

- `FACT` (`avb_slot_verify.c`, main): hash mismatch → `ERROR_VERIFICATION` (l.444-448); vbmeta não-assinado → `OK_NOT_SIGNED` → `ERROR_VERIFICATION` (l.~820); pubkey divergente → `PUBLIC_KEY_REJECTED` (l.866-870); os três **continuam** sse `allow_verification_error` (`result_should_continue`, l.61-78; `VBMETA_MAX_SIZE` l.44). Footer novo NONE: hash confere (gerado por nós) — só falta assinatura → `OK_NOT_SIGNED` → continua sse permitido.
- `FACT` (`vbmeta_a.txt` do audit): chain `boot` → chave `b2a02f1e…` (a mesma do stock); `ALLOW_VERIFICATION_ERROR` é setado pelo bootloader quando unlocked (l.1431-1448: "typically only UNLOCKED mode").
- `MEASURED` (precedente no aparelho, fato do plano): `init_boot_b` com Magisk (hash ≠ descriptor) **boota** — tolerância provada neste dispositivo/estado.
- LK Xiaomi é fechado → comportamento exato do LK **UNKNOWN**; convergência das 3 vias (fonte + precedente + semântica orange) ⇒ **tolera** em orange/unlocked. Em locked ⇒ rejeita (fora do escopo: aparelho já é orange/unlocked).

## 4. Logs de teste (colados; v1 e v2)

### 4.1 v1 — 31 casos (falhas que motivaram a v2; log integral)
```
SCRIPT: <workdir>/repack_boot_v1.py (primeira suíte; corpus idêntico ao da v2)
01-baseline: exit=0 :: + avbtool add_hash_footer ... --algorithm NONE ...
02-tiny-gz: exit=0 :: + avbtool ...
03-recompressed: exit=0 :: + avbtool ...
04-exact-page-multiple: exit=0 :: + avbtool ...
05-near-64MiB: exit=0 :: + avbtool ...   (60 MiB cabe: 62918656 < 67108864 — aceito corretamente)
06-header-v3: exit=1 :: ERRO: header_version=3 (este script assume v4)
07-header-v2: exit=1 :: ERRO: header_version=2 (este script assume v4)
08-bad-magic: exit=1 :: ERRO: header não é ANDROID!
09-truncated-100B: exit=1 :: ERRO: kernel_size inválido no stock
10-truncated-5000B: exit=1 :: ERRO: kernel_size inválido no stock
11-no-footer: exit=1 :: ERRO: footer AVBf não localizado
12-avbf-inside-kernel-nofooter: exit=1 :: ERRO: footer AVBf não localizado
13-ramdisk-present: exit=1 :: ERRO: footer AVBf não localizado  (corpus malformado; prova real no §4.3)
14-kernelsize-0: exit=1 :: ERRO: kernel gzip do stock não confere (1f8b)
15-raw-image: exit=1 :: ERRO: kernel novo não parece gzip
16-corrupt-gzip: exit=0 :: + avbtool ...   << B4: gzip corrompido ACEITO
17-inplace: exit=0 :: + avbtool ...   << B5: entrada sobrescrita (runner antigo não testava in==out de verdade)
18-exists: exit=EXC :: ValueError('embedded null byte')  << bug do RUNNER (bytes como argv), não do script
19-avbtool-missing: exit=1 :: FileNotFoundError: [Errno 2] No such file or directory: 'avbtool'  << B6 traceback
20-salt-with-none: exit=0 :: + avbtool ...   (avbtool aceita salt com NONE — documentado, sem bug)
21-rollback-neg: exit=1 :: subprocess.CalledProcessError ...  << B9 traceback
22-small-partition: exit=1 :: subprocess.CalledProcessError ...  << B7+B8: check próprio insuficiente + traceback
23-keep-samesize: exit=0 :: BYTECHECK: novo=67108864 stock=67108864
24-keep-diffsize: exit=1 :: ERRO --keep-footer exige kernel novo com mesmo size alinhada do stock
25-determinism: exit=0 :: + avbtool ...
26-sigsize-set: exit=0 :: + avbtool ...   << B3: zeramento silencioso
27-empty-kernel: exit=1 :: ERRO: kernel novo não parece gzip
28-header-preserve: exit=0 :: + avbtool ...
29-huge-kernelsize: exit=1 :: ERRO: kernel_size inválido no stock
30-zeros-magic: exit=1 :: ERRO: header_version=0 (este script assume v4)
31-header-size: exit=0 :: + avbtool ...
total=31 / EXIT=0
```

### 4.2 v2 — 32 casos, todos com comportamento projetado (log integral, código final sha256 `122936a8...`)
```
SCRIPT: <HOME>/codex-work/repack_boot_v2.py
01-baseline: exit=0 :: Hash Algorithm: sha256   (header+kernel iguais ao stock, §4.3)
02-tiny-gz: exit=0 :: Hash Algorithm: sha256
03-recompressed: exit=0 :: Hash Algorithm: sha256
04-exact-page-multiple: exit=0 :: Hash Algorithm: sha256
05-near-64MiB: exit=0 :: Hash Algorithm: sha256
06-header-v3: exit=1 :: ERRO: header_version=3 (só v4; página 4096 fixa no v3+)
07-header-v2: exit=1 :: ERRO: header_version=2 (só v4; página 4096 fixa no v3+)
08-bad-magic: exit=1 :: ERRO: header não é ANDROID!
09-truncated-100B: exit=1 :: ERRO: orig tem 100 B (< página de header)
09b-truncated-20B: exit=1 :: ERRO: orig tem 20 B (< página de header)
10-truncated-5000B: exit=1 :: ERRO: kernel_size inválido no stock (além do EOF)
11-no-footer: exit=1 :: ERRO: footer AVBf não localizado
12-avbf-inside-kernel-nofooter: exit=1 :: ERRO: footer AVBf fora do fim do arquivo (off=4111, len=67108864)
13-ramdisk-present: exit=1 :: ERRO: ramdisk_size=4096 != 0 (esta ferramenta só maneja boot sem ramdisk)
14-kernelsize-0: exit=1 :: ERRO: kernel do stock não é gzip (1f8b)
15-raw-image: exit=1 :: ERRO: kernel novo não parece gzip (magic 1f8b)
16-corrupt-gzip: exit=1 :: ERRO: kernel novo gzip truncado/corrompido (stream incompleto)
17-inplace: exit=1 :: ERRO: orig e output são o mesmo arquivo (recusa sobrescrever entrada)
18-exists: exit=0 :: Hash Algorithm: sha256   (--force explícito; sem --force recusa — verificado manual)
19-avbtool-missing: exit=1 :: ERRO: avbtool não encontrado no PATH (instale android-sdk libsparse/avb).
20-salt-with-none: exit=0 :: Hash Algorithm: sha256
21-rollback-neg: exit=1 :: ERRO: rollback-index negativo
22-small-partition: exit=1 :: ERRO: avbtool falhou (exit=1): Partition size of 1000000 is not a multiple of the image block size 4096.
23-keep-samesize: exit=0 :: BYTECHECK: novo=67108864 stock=67108864 footer preservado  (+`cmp` byte-idêntico, §4.3)
24-keep-diffsize: exit=1 :: ERRO: --keep-footer exige kernel novo com mesmo size alinhado do stock
25-determinism: exit=0 :: Hash Algorithm: sha256   (+ salt fixo => sha256 iguais, §4.3)
26-sigsize-set: exit=0 :: Hash Algorithm: sha256   (com --drop-signature; sem a flag recusa — smoke manual)
27-empty-kernel: exit=1 :: ERRO: kernel novo não parece gzip (magic 1f8b)
28-header-preserve: exit=0 :: Hash Algorithm: sha256   (só bytes 8,9,10 diferem = kernel_size)
29-huge-kernelsize: exit=1 :: ERRO: kernel_size inválido no stock (além do EOF)
30-zeros-magic: exit=1 :: ERRO: header_version=0 (só v4; página 4096 fixa no v3+)
31-header-size: exit=0 :: Hash Algorithm: sha256
total=32 / EXIT=0
```
12 aceitos + 20 recusas limpas; 0 tracebacks; 0 leftovers (try/finally + tempfile).

### 4.3 Provas manuais de 2ª via (trechos colados)
- `struct.error` v1 em 20 B: `struct.error: unpack_from requires a buffer of at least 24 bytes ... (actual buffer size is 20)` (v2: `ERRO: orig tem 20 B`).
- Ramdisk v1: OUT 67108864 B sem `R*4096` (`ramdisk preservado? False`, exit 0) — prova da perda silenciosa.
- Sobrescrita v1: `ovw.img` ("SENTINELA2") virou `ANDROID!` sem aviso.
- Salt: 2 runs default diferem em 63 B (região do descritor); com `--salt 0011...` sha256 `f57d3116...` idênticos (2 métodos: diff de bytes + info_image mostra `Salt:`).
- Baseline v2: `header+kernel equal: True`; `unpack_bootimg` parseia (v4, kernel_size 14555421, ramdisk 0); keep-footer: `cmp stock keep1.img` silencioso = byte-idêntico.
- Pós-correções da própria revisão (fuzz também me pegou): footer AVB é **BE** (`avb_footer.h:53-67`; 1ª v2 lia LE e recusava tudo); `ValueError` do caso 18 era bug do **runner**, não do script; `/tmp` lotou (7.8G/100%) — suíte migrada para `<workdir>` e relançada do zero (regra /tmp conflitou com realidade: documentado aqui).
- v2 final: `research/repack_boot_v2.py`, 224 linhas, sha256 `122936a8f9db28b525d42ec3b9404dd7a8cd78520b89f9d892074c9cb0c6d1ec`.

## 5. TOP-5 riscos residuais
- LK Xiaomi pode exigir `signature_size`/bloco AVB0 por caminho fora do AVB (UNKNOWN; mitigação: teste Q3 com stock + baseline).
- `fastboot boot` UNKNOWN (Q3) — sem dry-run, primeiro teste é escrita no slot inativo.
- Footer NONE muda `image_size/vbmeta_offset` (14577664→14561280): qualquer leitor que use offset absoluto do stock quebra (só o próprio AVB lê; OK).
- Determinismo exige `--salt` fixo; sem ele, G-REPRO por hash total é impossível (comparar por regiões).
- v2 ainda não maneja `ramdisk!=0` (recusa) — boot com ramdisk precisa de outra ferramenta.
