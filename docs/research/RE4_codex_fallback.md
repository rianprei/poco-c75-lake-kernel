# RE4 — Fallback A/B: retry, exaustão total e rollback (desmontagem do lk_b real)

> Continuação focada da frente B (RE2_codex_bootmode.md). MESMO método/base (ARM32 Thumb-2, file 0x200 ↔ 0x4C400000, vaddr = file + 0x4C3FFE00; idioma `ldr.w rX,[pool=OFFSET] … add rX,pc`, alvo = (add+4)+offset). Cópia em `<workdir>/lk_b.img`; projeto r2 `lkproj` reutilizado. Sem aparelho, sem execução, sem push.

## D1. O contador de retry (FACT com trechos)

**Leitura — `get_retry_count` = fcn.4c453d30 (0x4C453D30, 90 B), INTEIRA relevante:**
```
0x4c453d30  push {r4,r5,lr} / sub sp,0x24
0x4c453d34  bl fcn.4c453a88              ; lê bootctrl (boot_para) p/ buffer em sp
0x4c453d38  cmp r0, 1
0x4c453d4a  mov r0, sp
0x4c453d4c  movs r1, 0
0x4c453d4e  bl fcn.4c45389c              ; bootctrl → buffer (r1 = índice do slot)
0x4c453d52  subs r5, r0, 0
0x4c453d56  add r3, sp, 0x20
0x4c453d58  add.w r4, r3, r4, lsl 1      ; r4 = &slot_entry[idx]
0x4c453d5c  ldrb r0, [r4, -0x14]         ; byte do slot
0x4c453d60  ubfx r0, r0, 4, 3            ; BITS[6:4], 3 bits = tries_remaining (0–7)
0x4c453d64  add sp, 0x24
0x4c453d66  pop {r4,r5,pc}               ; RETORNA tries_remaining
; em falha: add r0,pc@0x4c453d6c → '[LK] get_retry_count failed, slot: 0x%x'; bl print; RETORNA 0
```
Reproduzir: `r2 -q -p lkproj -c 'e scr.color=false;e asm.bits=16; s fcn.4c453d30; pd 60'`. Callers (axt): retry-print fcn.4c42aff8@0x4C42B00C + seleção case-23 @0x4C42CB28 (_a) e @0x4C42CB58 (_b).

**(a) Decremento ANTES de bootar? UNVERIFIED.** Vasculhei o caminho de seleção (case-23 em fcn.4c40eaf8/fcn.4c42c82c) e o cluster 0x4C453xx: há leitura (`ubfx`), comparação e escrita SOMENTE em `set_active_slot` (D1-nota abaixo); **nenhuma sequência sub+bfi+partition_write de decremento foi isolada no caminho de tentativa**. Ausência de achado ≠ prova de ausência — fica UNVERIFIED, não "não".

**(b) Condição unbootable: SIM (retry == 0 → slot pulado).** No case-23, após cada `bl get_retry`: `cmp r0, 0` + `ble.w trampolim` (0x4C42CAE8→0x4C42D188; 0x4C42CB08→0x4C42D182), e os trampolins saltam DE VOLTA para tentar o outro sufixo (`b 0x4c42caf2` / `b 0x4c42cb12`). Como a falha de LEITURA também retorna 0, a condição efetiva é **retry==0 OU boot_para ilegível → pula o slot**. Irmã `fcn.4c453df8` confirma o campo: `ldrb; ands r0, 0xf` (nibble) com retorno 1/0.

**(c) Inicial/máximo: UNVERIFIED como constante; máximo 7 INFERRED da largura (ubfx 3 bits).** `movs r,7` ocorre 45× na região sem atribuição vinculável; o valor vem de boot_para em runtime. Default AOSP (7) é contexto, não prova.

**(d) Troca IMEDIATA na mesma inicialização: SIM.** Os desvios de fallback são back-edges `b`/`ble.w` diretos dentro do mesmo fluxo (sem `mtk_arch_reset`, sem `bl reboot`, sem retorno ao preloader entre as tentativas _a→_b). Snippet-prova (case-23, FACT):
```
0x4c42cae2  bl fcn.4c453df8        ; retry(_a)
0x4c42cae6  cmp r0, 0
0x4c42cae8  ble.w 0x4c42d188        ; esgotado → trampolim…
0x4c42caec  …                       ; …que faz `b 0x4c42caf2` (tenta _b)
0x4c42cb02  bl fcn.4c453df8        ; retry(_b)
0x4c42cb06  cmp r0, 0
0x4c42cb08  ble.w 0x4c42d182        ; …`b 0x4c42cb12` (retenta/alternativa)
```
`set_active_slot` = fcn.4c453b8c (0x4C453B8C, 392 B): monta sufixo via snprintf com `_a`@0x4C49E68C/`_b`@0x4C49EBD8, lê bootctrl (`bl fcn.4c469ac4`), testa nibble (`and r1,r3,0xf; cmp r1,0xf`), escreve de volta, e em erro imprime `[LK] set_active_slot failed, slot: 0x%x` (add@0x4C453CCC). Chamadores: fcn.4c42dc24 +2 sites (axt).

## D2. Ambos inválidos → FASTBOOT (não loop, não off)

Cadeia de retorno (pares provados por axt): decap fcn.4c452924 (−1) → fcn.4c468438 (loop de candidatos `_a`/`_b` via snprintf+`bl decap`; `cmp r0,0; beq próximo`) → fcn.4c468750 → fcn.4c42b0a8 (switch por modo; case 4 = boot normal: `bl boot_load; bl verify; cmp r0,0`) → em falha (`bne.w 0x4c42b264` vindo de 0x4c42b0fc):
```
0x4c42b264  movs r0, 1
0x4c42b266  bl fcn.4c461724     ; fastboot_init: bringup USB (MMIO 0x1000_7xxx)…
0x4c42b26a  cmp.w sb, 0         ; (código morto: fastboot_init não retorna —
0x4c42b26e  bge.w 0x4c42b100    ;  termina em `b 0x4c4617ec`, loop infinito)
```
Reproduzir: `r2 -q -p lkproj -c 'e scr.color=false;e asm.bits=16; s 0x4c42b250; pd 20'`. O mesmo `bl fastboot_init` aparece em ≥3 saídas de falha do fluxo (0x4C42B266, 0x4C42B28C, 0x4C42AF40 — esta última no ramo de tecla). **VEREDITO D2: fastboot.** Nenhum `mtk_arch_reset`/poweroff foi encontrado nos blocos de falha lidos; o terminal é fastboot_init (USB halt loop, aparelho acessível). Ressalva honesta: provei o terminal e os elos decap→…→case4→fastboot_init por pares de caller/callee; a travessia completa fim-a-fim tem 1 elo INFERRED (qual falha exata alimenta cada site — todos convergem, sem ramo de reboot/off visível).

Implicação protocolar (INFERRED, declarada): 'invalidar o outro slot' NÃO é proteção nem perigo de loop — o LK cai em fastboot com o aparelho recuperável; o perigo real continua sendo humano (W7 de REVIEW6_codex_statemachine.md — retido, não publicado) e de firmware (slot A antigo), não entra em reboot-loop.

## D3. Rollback ao subir slot antigo: checagem EXISTE mas NÃO barra este slot A

Código (FACT): AVB-verify fcn.4c464a14 contém o ramo (add@0x4C46525C → `: Image rollback index is less than the stored rollback index`):
```
0x4c465270  bl fcn.4c466a08        ; compara rollback (imagem × armazenado/RPMB)
0x4c465274  ldr.w r3, [sp, 0x568]
0x4c465278  cmp r3, 0
0x4c46527a  beq.w 0x4c464c2c       ; ok → continua
0x4c46527e  b 0x4c464e1a           ; violação → caminho de falha (não boota a imagem)
```
Lookup de partição com sufixo provado pelas strings `Partition name and suffix does not fit.` / `[PART_COMMON_LK]find %s(add suffix for %s) index %d` + construção `_a`/`_b` no código de seleção — **o LK usa vbmeta/AVB do slot selecionado normalmente**.

Porém (MEASURED, decisivo): `audit/avb/vbmeta_a.txt` e o vbmeta_b (REVIEW6_codex_statemachine.md M6 — retido, não publicado) têm **Rollback Index 0**, e os footers de boot_a/boot_b/T0/T2 também **rollback 0**. Violação exigiria imagem < armazenado; com tudo em 0, **o slot A antigo (OS3.0.20.0) NÃO é barrado por rollback AVB** — ele passa e boota o OS antigo (confirmando o perigo do fato 62 do plano por via independente). Aplicabilidade em orange (tolerância a erro de verificação, cf. init_boot/Magisk que boota — fato 48) reforça: mesmo se houvesse divergência, o estado orange tende a tolerar. ARB Xiaomi (`anti` getvar existe; seccfg) é mecanismo SEPARADO e **UNVERIFIED** neste binário.
**VEREDITO D3: checagem existe no código (sim), mas não impede o slot A antigo nestas condições (não, por índices iguais); ARB: UNVERIFIED.**

## Sabotagem (método ldr.w+add-pc; scanner python stdlib, janela 256 B)

- `slot-successful:a` (file 0x9D554): **1 xref** (add@file 0x4CAB6 = vaddr **0x4C42CAB6 — idêntico ao `axt` do r2**, 2 métodos concordam).
- `ZZZ_ORPHAN_check` plantada em file 0x200000 da CÓPIA `lk_sabot.img`: **0 xrefs**. Método discrimina referenciada × órfã.

## Auto-revisão

- Cada endereço com comando r2 (`-p lkproj` + `s`/`pd`/`axt`); trechos ≥6 insns; pool→string conferidos byte a byte (alvo = (add+4)+offset, sem máscara — documentado após erro inicial com &~3).
- Rebaixados: semântica Vol− (INFERRED), decremento (UNVERIFIED), retry inicial (UNVERIFIED), elo final D2 (1 hop INFERRED), ARB (UNVERIFIED), aplicabilidade do rollback em orange (UNVERIFIED).
- Nada fora de `<workdir>` (+ projeto r2 pré-existente e relatório); binário nunca executado.

## Fontes

Binário `backup-2026-10-05/lk_b.img` (cópias em `<workdir>/`); strings `strs6.txt`; RE2_codex_bootmode.md (base/método); audit `avb/vbmeta_a.txt` (rollback 0); REVIEW6 M6 (rollback 0 em vbmeta_b/boot).
