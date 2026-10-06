# RE2 (FRENTE B) — Seleção de modo de boot e boot inválido, por DESMONTAGEM do lk_b real

> Autor: frente B (reversor) | Data: 2026-10-06 | Alvo (SOMENTE LEITURA): `backup-2026-10-05/lk_b.img` → cópia em `<workdir>/lk_b.img` (+ `lk_work.img`, `lk_sabot.img` p/ sabotagem).
> Ferramentas: `r2 6.2.0`, `objdump`/`llvm-objdump` (instalados), python3 stdlib. NADA instalado, nenhum push, aparelho intocado, LK nunca executado.
> Rótulos: FACT (código lido) / MEASURED (saída colada) / INFERRED / UNVERIFIED / UNKNOWN.

## 0. ARQUITETURA + BASE (com 3 determinações independentes)

**Veredito: ARM32 (A32 no entry + Thumb-2 no corpo), base de carga 0x4C400000 com header MTK de 0x200 bytes REMOVIDO (offset-arquivo 0x200 ↔ vaddr 0x4C400000; i.e. vaddr = file_off + 0x4C3FFE00).**

Método 1 — votação por literais (MEASURED): 17.646 `ldr rX,[pc]`/`ldr.w` extraídos; para cada pool (u32 em 0x40000000–0xC0000000) testei 2.048 bases alinhadas a 1 MB contando acertos exatos em inícios de strings (`strings -t x`, 11.428). Resultado: **0x4C400000 com 82 acertos; todas as demais bases <4 (ruído)**. Ex.: pool@file 0xBA9C6→P=0x4C47BB28 = vaddr de `raw data`@file 0x7BD28.

Método 2 — pools do próprio entry ARM (MEASURED): `ldr r6,[pc]`@file 0x224 → pool@0x270 = 0x4C400020/0x4C400000/0x4C538B9C/0x4C400080; com o mapeamento acima resolvem para file 0x220/0x200/**0x138DBC**/0x280 — e **0x4C538B9C − 0x4C400000 = 0x138B9C = campo de tamanho do payload no header MTK** (bytes 4–8: `9c8b1300`). O código conhece seu próprio fim.

Método 3 — lógica de auto-relocação no entry (FACT, r2): em 0x4C400024+: `mov r0,pc; sub r0,#0x48` (=0x4C400000); `ldr r1,=0x4C400000`; `beq` pula cópia; senão copia [r0,r1)→até r2=`ldr`=0x4C538B9C; depois zera BSS [0x4C538B9C,0x4C5F0810); `blx 0x4C426AF4` (main Thumb); `b .`:
```
0x4c400040  0f00a0e1  mov r0, pc
0x4c400044  480040e2  sub r0, r0, 0x48
0x4c400048  24109fe5  ldr r1, [0x4c400074]   ; =0x4c400000
0x4c40004c  010050e1  cmp r0, r1
0x4c400050  0a00000a  beq 0x4c400080
0x4c400054  1c209fe5  ldr r2, [0x4c400078]   ; =0x4c538b9c
0x4c400058  043090e4  ldr r3, [r0], 4
0x4c40005c  043081e4  str r3, [r1], 4
0x4c400060  020051e1  cmp r1, r2
0x4c400064  fbffff1a  bne 0x4c400058
0x4c400110  779a00fa  blx 0x4c426af4
0x4c400114  feffffea  b 0x4c400114
```
Reproduzir: `r2 -q -a arm -m 0x4C3FFE00 -c 'e asm.bits=32;e scr.color=false; s 0x4C400000; pd 40' lk_b.img`.

Idioma de referência a strings (descoberto após 8 formas testadas e FALHADAS: ponteiro absoluto, ADR16/32, ADR-ARM, MOVW/MOVT, base+offset±8K — todas 0 hits): **`ldr.w rX,[pool]` (OFFSET 32 bits, não endereço!) … `add rX,pc`, alvo = (addr_do_add + 4) + offset, SEM mascarar bit1**. Ex. verificado byte a byte: `ldr.w r2,[0x4c40439c]`(=0x7697E) … `add r2,pc`@0x4C403CB6 → 0x4C403CBA+0x7697E = **0x4C47A638 = `boot mode select`** exato; idem `add r0,pc`@0x4C40375A+0x76C16 = **0x4C47A374 = ` => FASTBOOT mode...`** exato; `add r0,pc`@0x4C452D28+0x5808C = **0x4C4AADB8 = `invalid boot image version`** exato. O projeto r2 (`aaa`, salvo como `lkproj`) confirma por emulação as mesmas 4 âncoras via `axt`.

## B1. Seleção de modo × validação do boot — ORDEM PROVADA

Funções (vaddr, tamanho r2): bootmode-select **fcn.4c403a10** (0x4C403A10, 2628 B); dispatcher **fcn.4c426a0c** (chama bootmode @0x4C426ABC); fluxo principal **fcn.4c428fe0** (chama dispatcher @0x4C4290BE; contém o site `booting linux` @0x4C42AD5C, ~7 KB adiante); impressão FASTBOOT **fcn.4c403740** (0x4C403740, 44 B); fastboot_init (USB) **fcn.4c461724** (0x4C461724, 202 B, 8 callers); retry-print **fcn.4c42aff8** (chamada de DENTRO do bootmode @0x4C403ACE); log **fcn.4c43efa8** (centenas de callers).

B1a — detecção de tecla no INÍCIO do bootmode-select (FACT): nos primeiros ~200 B da função, 3 leituras de tecla `bl fcn.4c41a97c` (tabela por código: `lsl r3,r0,4; sub r3,r0,lsl2; ldr r4,[r2,r3]` + `ldrh/ldrb` + `bl fcn.4c41a97c→f...`):
```
0x4c403aa2  16f06bff  bl fcn.4c41a97c   ; (r0=0x11c6, r1=9)
0x4c403aac  16f066ff  bl fcn.4c41a97c   ; (r0=0x10d5, r1=1)
0x4c403abe  16f05dff  bl fcn.4c41a97c   ; (r0=0x10d5, r1=0)
```
53 xrefs totais; cluster 0x4C41Ax–0x4C41Bx (driver de keypad); string `MT65XX_BOOT_MENU_KEY 0x%x` usada em fcn.4c4053a0@0x4C4054CC. Semântica exata tecla↔código: INFERRED (mapeamento Vol− específico não extraído; strings `Yes (Volume UP): Confirm and Boot.` / `No (Volume Down): Abort.` sustentam o padrão MTK).

B1b — print `boot mode select` ainda no prólogo decisório (FACT): `ldr.w r2,[0x4c40439c]`(=0x7697E) … `add r2,pc`@0x4C403CB6 → 0x4C47A638; `bl log`. Comando r2: `r2 -q -p lkproj -c 'e scr.color=false; axt @ 0x4C47A638'` → `fcn.4c403a10 0x4c403cb6`.

B1c — ramo FASTBOOT (FACT): fcn.4c403740 testa global (`ldr r3,[...0x4c53b5a4]; cmp r3,0x63`): se `==0x63` imprime ` => FASTBOOT mode...` (`ldr r0,[pool=0x76c16]; add r0,pc; b.w print`) senão outra string; chamada SOMENTE de fcn.4c403a10@0x4C403F2A (axt). fastboot_init faz bringup USB (MMIO 0x1000_7xxx: `movw/movt; str`) e **termina em `b 0x4c4617ec` (loop infinito — nunca retorna ao fluxo de boot)**:
```
0x4c4617da  b9f7bdf8  bl fcn.4c41a958
0x4c4617de  47f21403  movw r3, 0x7014
0x4c4617e6  c1f20003  movt r3, 0x1000
0x4c4617ea  1a60      str r2, [r3]
0x4c4617ec  fee7      b 0x4c4617ec
```

B1d — ordem no fluxo principal (FACT): em fcn.4c428fe0, `bl fcn.4c426a0c`@0x4C4290BE (dispatcher→bootmode-select) precede o site `booting linux`@0x4C42AD5C no mesmo fluxo; validação/decap (fcn.4c452924) é chamada de outro ramo (fcn.4c468438@0x4C4684AC), nunca do caminho de tecla. **VEREDITO B1: SIM — decisão por tecla + print de modo + desvio a fastboot_init (não-retornante) ocorrem ANTES de qualquer leitura/validação da partição boot.** Cadeia: reset@0x4C400000 → relocate/BSS → blx main@0x4C426AF4 → … → fcn.4c428fe0 → dispatcher → bootmode-select (teclas→modo→[fastboot_init | retorna p/ fluxo normal→decap→boot_linux]).

## B2. Boot inválida — print + return −1, SEM reboot/fastboot/troca DENTRO da função

Função de validação **fcn.4c452924** (0x4C452924, 1288 B, switch por tipo: cases 0/1/3/4): padrão de falha uniforme (≥6 instruções, FACT) — ex. bloco 0x4C452D0C:
```
0x4c452d0c  3748      ldr r0, [0x4c452dec]   ; off=0x580ee → (0x4c452d12+4)+off = 0x4c4aae04
0x4c452d0e  6ff00104  mvn r4, 1              ; r4 = -1 (código de erro)
0x4c452d12  7844      add r0, pc            ; = 'main dtb is not packed with valid fdt format'
0x4c452d14  ecf748f9  bl fcn.4c43efa8       ; print
0x4c452d18  40e7      b 0x4c452b9c          ; → epílogo
0x4c452b9c  fff7dafc  bl fcn.4c452554
0x4c452ba0  2044      add r0, r4            ; r0 = ret + (-1)
0x4c452ba2  0df5d46d  add.w sp, sp, 0x6a0
0x4c452ba6  bde8f081  pop.w {r4,r5,r6,r7,r8,pc}  ; RETORNA
```
Resoluções conferidas byte a byte (add+4+offset): 0x4C452D28→`invalid boot image version`; 0x4C452D3C→`invalid vendorboot image header v4`; 0x4C452D50→`invalid vendorboot image header v3`; 0x4C452D5C→`can't find dtb`; `boot image decapsulate fail!` via add@0x4C452BC8 (r1) e `boot image is NULL` via add@0x4C452C90 (r0), ambos em fcn.4c452924 (axt+rastreio próprio). Chamadores: fcn.4c468438@0x4C4684AC (loop de candidatos: `bl decap; cmp r0,0; beq próximo` — itera sufixos `_a`/`_b` via snprintf `blx fcn.4c43fe58`) e 0x4C42E0B2. **VEREDITO B2: após `decapsulate fail`/`load fail` o LK imprime e RETORNA erro (−1); não reinicia, não entra em fastboot e não troca slot DENTRO da função** — o chamador tenta o próximo candidato (fallback sequencial); terminal de falha total (ambos os slots) = UNVERIFIED (não rastreado até o fim; sem `reboot`/`mtk_arch_reset` nesses blocos).

## B3. Retry/contador e troca automática — mecanismo parcial PROVADO

Achados (FACT): (i) **fcn.4c42aff8** lê sufixo (`bl fcn.4c453ae4`) + retry (`bl fcn.4c453d30`, byte guardado) e imprime `[%s:%d] p_AB_suffix: %s, AB_retry_count: %d` — chamada de DENTRO do bootmode-select@0x4C403ACE: o estado A/B é lido antes do boot; (ii) região 0x4C42CA90+ (case 23 do switch de fcn.4c40eaf8): tenta sufixo `_a` (`bl get_retry`-like fcn.4c453d94/fcn.4c453df8; `cmp r0,0; ble.w trampolim`), em falha salta e tenta `_b` — **fallback sequencial _a→_b em código**; (iii) **fcn.4c453b8c** (`set_active_slot`, 0x4C453B8C, 392 B): monta sufixo via snprintf com `_a`@0x4C49E68C/`_b`@0x4C49EBD8, lê bootctrl (`bl fcn.4c469ac4/fcn.4c469e08`), máscara nibble (`and r1,r3,0xf; cmp r1,0xf`), escreve de volta, e em erro imprime `[LK] set_active_slot failed, slot: 0x%x` (add@0x4C453CCC); (iv) strings `slot-retry-count:{a,b}`, `slot-unbootable:{a,b}`, `ab_suffix is null!`, `p_AB_suffix` presentes e referenciadas na mesma região (axt: retry-b←0x4C42CB7A via fcn.4c40eaf8; retry-a←0x4C42CB48).
**VEREDITO B3: troca automática entre slots EXISTE como fallback sequencial no código (try _a → em falha try _b; set_active_slot implementado e chamado de fcn.4c42dc24); o DECREMENTO explícito do retry + comparação `==0` não foi isolado em instrução citada → mecanismo de exaustão: INFERRED (estrutura sustenta), valor inicial do retry: UNVERIFIED** (vem de boot_para em runtime; `movs r,7` ocorre 45× na região sem atribuição possível; default AOSP 7 apenas contexto, não prova).

## Sabotagem (método distingue referenciada × órfã) — MEASURED

`ZZZ_ORPHAN_check` plantada em file 0x200000 de CÓPIA (`lk_sabot.img`); mesmo scanner ldr-w/ldr-t16 + `add Rd,pc` (janela 256 B, registro consistente): **`boot mode select` (file 0x7A838): 1 xref (ldr@file 0x3EAA/add@file 0x3EB6 = vaddr 0x4C403CB6 — idêntico ao `axt` do r2, 2 métodos concordam); `ZZZ_ORPHAN_check`: 0 xrefs.** Comandos: `cp lk_b.img lk_sabot.img` + python (struct, sem libs externas) + `r2 -q -p lkproj -c 'axt @ 0x4C47A638'`.

## Auto-revisão

- Toda vaddr = file_off + 0x4C3FFE00 (3 provas, §0); trechos ≥6 instruções colados de `pd` com `asm.bits` declarado.
- Rebaixado a INFERRED/UNVERIFIED: semântica exata tecla↔Vol−; loop de comandos fastboot (`fastboot: processing commands` sem xref — entrada provavelmente via tabela/ponteiro); terminal de falha total; decremento do retry; retry inicial.
- Não afirmei 'seguro': B1 responde ORDEM (sim), não segurança absoluta; B2/B3 delimitam o não-provado.
- Reprodutibilidade: `r2 -q -a arm -m 0x4C3FFE00 lk_b.img` (projeto salvo `lkproj`: `aaa` + `axt @ <vaddr>`); entrada ARM: `e asm.bits=32; s 0x4C400000; pd`; corpo: `e asm.bits=16`.

## Fontes

- Binário: `backup-2026-10-05/lk_b.img` (lido; cópias em `<workdir>/`); strings `<workdir>/lk_b_strings.txt` + `strs6.txt` (offsets, gerado local).
- Cruzamento: REVIEW3_opencode_cmdaudit.md §1 (retido — não publicado; strings do cmd_boot legacy — este relatório NÃO usa gemini-lk; todas as provas são do binário real).
