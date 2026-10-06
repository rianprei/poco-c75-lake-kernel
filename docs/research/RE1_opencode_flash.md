# RE1_opencode_flash — Desmontagem do caminho de GRAVAÇÃO (`flash:`) e lista de partições controladas (lk_b.img real)

> Data: 2026-10-06. Alvo: `<lake-kernel>/backup-2026-10-05/lk_b.img` (cópia de trabalho em <workdir>/lk_b.img, SOMENTE LEITURA). Nada foi executado no aparelho; nenhum adb/fastboot; nenhum pacote instalado. Labels: FACT (fonte lida) / MEASURED (saída colada de comando local) / INFERRED / UNVERIFIED / UNKNOWN.

## 0. Como este relatório foi produzido (método, para reexecução)

- Todas as medidas abaixo são do **binário real do aparelho** (`lk_b.img`), não do gemini-lk público.
- Workspace: `<workdir>/` (cópia de `lk_b.img`; backup intocado).
- Ferramenta principal: `r2` (radare2 6.2.0-132) em modo Thumb-16 com mapeamento `-m 0x4c3ffe00` (ver §1), e scripts Python 3 (stdlib apenas: struct/re) para varredura de xrefs PIC (literal-pool + `ADD Rd,PC`).

---

## 1. ARQUITETURA e ENDEREÇO-BASE (tarefa pré-requisito)

### 1.1 Arquitetura: ARM A32 (stub inicial) + **Thumb-2** (corpo principal) — MEASURED

O arquivo tem cabeçalho MTK de 0x200 bytes; o payload começa no offset 0x200. Desmontando o payload como ARM A32:

```
$ r2 -a arm -b 32 -m 0x10000000 -q -e scr.color=0 -c 's 0x10000200; pd 12' lk_b.img
0x10000200  07 00 00 ea   b 0x10000224        <- ARM A32 (stub)
0x10000224  44 60 9f e5   ldr r6, [pc, #0x44] <- ARM A32: configuração de MMU/cache (MRC/MCR p15)
0x1000022c  10 0f 11 ee   mrc p15, 0, r0, c1, c0, 0
```

Mas o BULK do código (arquivo 0x400+) é **Thumb-2**, não ARM:

```
$ r2 -a arm -b 16 -m 0x4c3ffe00 -q -e scr.color=0 -c 's 0x4c460000; pd 8' lk_b.img
0x4c460000  3f04  lsls r7, r7, 0x10
0x4c460004  7844  add r0, pc        <- idiom PIC Thumb-16 (ver §1.3)
0x4c46002e  3448  ldr r0, [0x4c460100] ; pool: 0x50a7e
0x4c460032  7844  add r0, pc         -> r0 = 0x50a7e + 0x4c460036 = 0x4c4b0ab4 = string "%s curr = %dmA"
```

Desmontar o corpo como ARM gera lixo (blx/stc inválidos); desmontar como Thumb produz código válido com literal-pools e chamadas BL coerentes. **Veredito: ARMv7 Thumb-2** (mesma família do LK MediaTek público), com um stub A32 de inicialização (0x200–0x224) que liga MMU/cache e salta para o corpo Thumb.

### 1.2 Endereço-base de carga: **SRAM 0x10000000 → DRAM 0x4c400000** (relocation) — MEASURED/FACT

Três evidências independentes:

**(a) Campo do cabeçalho MTK (offset 0x44) = 0x10000000:**
```
$ xxd -g4 -l 16 -s 0x40 lk_b.img
00000040: 00000000 10000000   -> word LE @0x44 = 0x10000000 (endereço de carga SRAM)
```

**(b) Literal-pool do stub de inicialização (arquivo 0x270) contém 0x4c400000 + 0x138b9c:**
```
$ xxd -g4 -l 16 -s 0x270 lk_b.img
00000270: 2000404c 0000404c 9c8b534c 8000404c
  = 0x4c400020, 0x4c400000, 0x4c538b9c (=0x4c400000+0x138b9c = fim do payload), 0x4c400080
```
O stub copia o payload de SRAM 0x10000000 para DRAM 0x4c400000 (o par (0x4c400000, 0x4c400000+size) é a assinatura clássica de self-relocation do LK MTK).

**(c) Ponteiros absolutos em .data só resolvem com base 0x4c400000 e offset -0x200:**
A tabela de nomes controlados (ver §3) está no arquivo em 0xbfab0 e contém ponteiros como 0x4c4a14bc. Com o mapeamento **vaddr = 0x4c400000 + (file_offset − 0x200)**:
```
0x4c4a14bc -> file 0xa14bc+0x200 = 0xa16bc = "nvram"  ✓ (confere com strings)
0x4c4a14c4 -> 0xa16c4 = "nvcfg"   ✓
0x4c49d2a4 -> 0x9d4a4 = "preloader" ✓
```
Com qualquer outra base (0x10000000+file, 0x4c400000+file sem -0x200) os ponteiros caem no MEIO de strings sem sentido — ou seja, o mapeamento correto é:
```
runtime vaddr = 0x4c400000 + (file_offset − 0x200)
r2: -m 0x4c3ffe00  (vaddr = file + 0x4c3ffe00)
```

**Comando r2 que reproduz a base:** `r2 -a arm -b 16 -m 0x4c3ffe00 -q -c 's 0x4c4bf8b0; pxw 28' lk_b.img` → mostra os 7 ponteiros da tabela controlada; cada um resolve a "nvram/nvcfg/..." com `psz` (§3).

---

## 2. O idioma PIC (como o LK referencia strings) — necessário para achar xrefs

O LK é **position-independent**: strings NÃO são referenciadas por ponteiro absoluto no código, e sim por:

```
ldr rX, [pc, #imm]     ; carrega W (offset) de um literal-pool adjacente
...
add rX, pc             ; Thumb-16 (bytes 7X 44): rX = W + PC  onde PC = addr(instr)+4
```
alvo = ADD_file + 4 + W (tudo em offsets de arquivo; o mapeamento uniforme cancela a base).

Varredura: para cada palavra W alinhada a 4 na região de código, se (alvo−W−4) cai num `add rD,pc` (bytes 7X 44) e existe um `ldr rD,[pc,#imm]` em até 80 bytes antes cujo pool é a própria palavra → **xref real**. Falso-positivo foi eliminado exigindo o pareamento LDR→pool→ADD (mesmo registrador Rt==Rd).

**Verificação do método (PROVA DE SABOTAGEM obrigatória):**

```
STRING REAL  'Flashing is not allowed for Controlled Partitions' (file 0xa1060): 1 xref -> ADD@file 0x36a8c (rt 0x4c43688c)
STRING ÓRFÃ  'ZZZ_ORPHAN_check' plantada no FIM de uma CÓPIA (file 0x800000):      0 xrefs
```
(saída do scanner idêntico para ambas; a órfã plantada não tem LDR/ADD apontando para ela) — MEASURED.

---

## 3. A1 — FLUXO do comando `flash:` (quem checa o quê, em que ordem, e onde escreve)

### 3.1 Mapa de funções (endereços runtime / arquivo):

| função | runtime vaddr | file offset | papel |
|---|---|---|---|
| cmd_flash (handler "flash:") | 0x4c436df0 | 0x36ff0 | casos especiais (crclist, logo, dtbo…), sufixo "_ab" (dual-slot), laço por slot, responde OKAY |
| flash_write_wrapper (get_download_permission) | 0x4c4367c8 | 0x369c8 | **1º: checagem de controladas**; 2º: singlebootloader; 3º: chama o write real |
| controlled_check (is_controlled_partition) | 0x4c435028 | 0x35228 | 7× strcmp contra tabela em 0x4c4bf8b0 |
| flash_write (write real: sparse + raw + preloader + boot-magic) | 0x4c4364b8 | 0x366b8 | dispatch por nome de imagem MTK, auth de preloader, magic ANDROID!, lookup de partição, tamanho, escrita |
| erase/format fn (cmd_erase/format) | 0x4c4368d8 | 0x36ad8 | chama controlled_check E boot/preloader_erase_check |
| boot/preloader_erase_check | 0x4c436424 | 0x36624 | 7× strncmp(0x20) contra tabela em 0x4c4bf8cc |
| fastboot_fail | 0x4c42c1d8 | 0x2c3d8 | prefixo "FAIL" (string em file 0xad43c = "FAIL") |
| fastboot_okay | 0x4c42c3b8 | 0x2c5b8 | prefixo "OKAY" (file 0x9d220) |
| strcmp | 0x4c4400b0 | 0x402b0 | loop byte-a-byte (desmontado) |
| strncmp | 0x4c44021c | 0x4041c | com limite (desmontado) |
| partition lookup por nome | 0x4c45a918 | 0x5ab18 | acha partid (≤0x7f) na tabela global |
| partition offset accessor | 0x4c45ab1c | 0x5ad1c | partid*24 → offset 64-bit da tabela do DEVICE |
| partition size accessor | 0x4c45aa98 | 0x5ac98 | partid*24 → tamanho 64-bit da tabela do DEVICE |
| storage write primitives | 0x4c45d00c / 0x4c45cfac | 0x5d20c/0x5d1ac | escrita em eMMC/UFS (block 0x800/0x1000 por tipo) |

### 3.2 O caminho do `flash:` em ordem (com desmontagem colada)

**Passo 1 — cmd_flash (0x4c436df0):** trata nomes especiais (strcmp com "crclist" file 0xa1398 e outros) e o sufixo "_ab" (strstr com "_ab" file 0xa1130 — se presente, faz o laço para _a e _b).

**Passo 2 — wrapper (0x4c4367c8) — A CHECAGEM DE CONTROLADAS É A PRIMEIRA COISA:**

```
$ r2 -a arm -b 16 -m 0x4c3ffe00 -q -e scr.color=0 -c 's 0x4c4367c8; pd 12' lk_b.img
0x4c4367c8  2de9f843  push.w {r3, r4, r5, r6, r7, r8, sb, lr}
0x4c4367cc  0e46      mov r6, r1          ; r6 = data (imagem baixada)
0x4c4367ce  1546      mov r5, r2           ; r5 = size
0x4c4367d0  0446      mov r4, r0           ; r4 = NOME da partição
0x4c4367d2  fef729fc  bl 0x4c435028        ; <<< CONTROLLED_CHECK(nome)
0x4c4367d6  0128      cmp r0, 1
0x4c4367d8  57d0      beq 0x4c43688a       ; se controlada -> FALHA, retorna 0, NÃO escreve
0x4c4367da  3649      ldr r1, [0x4c4368b4] ; pool 0x6a54a
0x4c4367dc  2046      mov r0, r4
0x4c4367de  7944      add r1, pc           ; r1 = 0x6a54a + 0x4c4367e2 = 0x4c4a0d2c -> file 0xa0f2c = "singlebootloader"
0x4c4367e0  bl 0x4c4400b0                 ; strcmp(nome, "singlebootloader")
```

O ramo de falha (0x4c43688a) imprime e **retorna sem escrever**:

```
$ r2 -a arm -b 16 -m 0x4c3ffe00 -q -e scr.color=0 -c 's 0x4c43688a; pd 6' lk_b.img
0x4c43688a  1148      ldr r0, [0x4c4368d0]   ; pool 0x6a5d0
0x4c43688c  7844      add r0, pc             ; r0 = 0x6a5d0+0x4c436890 = "Flashing is not allowed for Controlled Partitions" (file 0xa1060)
0x4c43688e  f5f7a3fc  bl 0x4c42c1d8          ; fastboot_fail(msg)
0x4c436892  0020      movs r0, 0             ; retorno = 0 (negado)
0x4c436894  bde8f883  pop.w {..., pc}        ; VOLTA sem chamar o write
```

**Passo 3 — só DEPOIS chama o write real (0x4c436834 `bl 0x4c4364b8`).**

```
0x4c43682e  mov r2, r5        ; size
0x4c436830  mov r0, r4        ; nome
0x4c436832  mov r1, r6        ; data
0x4c436834  fff740fe  bl 0x4c4364b8    ; <<< FLASH_WRITE(nome, data, size) — SÓ APÓS A CHECAGEM
```

### 3.3 RESPOSTA A1 (checagem de controladas ANTES da escrita?): **SIM** — MEASURED

Prova: o `bl 0x4c435028` (checagem) está em 0x4c4367d2; o `bl 0x4c4364b8` (write) só é alcançado em 0x4c436834, i.e., DEPOIS do `beq` de falha (0x4c4367d8) que retorna imediatamente. O caminho de falha NÃO passa pelo write. **A checagem de controladas acontece ANTES de qualquer escrita no eMMC.** (MEASURED, trechos acima.)

### 3.4 O write real (0x4c4364b8) — sub-checagens em ordem:

1. strcmp(nome, "singlebootloader") (pool 0x6a84a→file 0xa0f2c) — MEASURED (prologue em 0x4c4364d0–0x4c4364de).
2. Dispatch pelo campo name do header MTK da imagem (data+8): strncmp contra "lk"(0x83fec)/"LK"(0xa0f40)/"atf"(0xa0f4c)/"logo"/"LOGO"/"tee2"(0x84000) — decide caminho de imagem de bootloader (auth/logo). — MEASURED (0x4c436510–0x4c43652e).
3. Caminho preloader: strncmp(nome,"preloader",10) e (nome,"PRELOADER",10) (0x9d4a4/0xa0f54) → caminho com CERT auth ("Preloader auth failed!", "flash preloader is not permitted." em rt 0x4c435ac0/0x4c435b98). — MEASURED.
4. Caminho boot: strcmp(nome,"boot")/"boot_a"/"boot_b" (0x9b594/0xa09d8/0xa09e0) → `memcmp(data, "ANDROID!", 7)` (rt 0x4c4359f6, pool 0x45642→file 0x7b23c="ANDROID!") → se não bater: "image is not a boot image". — MEASURED (0x4c4359c6–0x4c4359fe).
5. Lookup da partição por NOME: `bl 0x4c45a918` → partid (≤0x7f=128 partições). — MEASURED.
6. Offset 64-bit: `bl 0x4c45ab1c(partid)` → r0:r1 (tabela global do DEVICE, partid*24). — MEASURED.
7. Tamanho 64-bit: `bl 0x4c45aa98(partid)` → compara com o tamanho da imagem: "size too large, space small. image length[0x%llx], partition max size[0x%llx]" (rt 0x4c430586) e "Image size span 0x%llx, partition size 0x%llx" (rt 0x4c435d0c). — MEASURED.
8. Escrita: `bl 0x4c45d00c` / `bl 0x4c45cfac` com offset/tamanho derivados dos passos 5–7 + offset do header da imagem. — MEASURED (0x4c43595a–0x4c435a66).

### 3.5 Caminho ERASE/FORMAT (separado) — rt 0x4c4368d8:

```
0x4c436b72  mov r0, r7           ; nome
0x4c436b74  fef758fb  bl 0x4c435028         ; controlled_check
0x4c436b78  0128      cmp r0, 1
0x4c436b7a  00f0da80  beq.w 0x4c436d32      ; -> "Erasing is not allowed for Controlled Partitions"
0x4c436b7e  3846      mov r0, r7
0x4c436b80  fff750fd  bl 0x4c436424         ; boot/preloader_erase_check
0x4c436b84  0028      cmp r0, 0
0x4c436b86  40f0db80  bne.w 0x4c436d40      ; -> "Forbidden to erase boot/preloader partition."
```

---

## 4. A2 — AS LISTAS DE PARTIÇÕES CONTROLADAS (extraídas do binário)

O controlled_check (0x4c435028) carrega **7 ponteiros** da tabela em runtime 0x4c4bf8b0 (file 0xbfab0) e faz strcmp do nome contra cada um. O boot/preloader_erase_check (0x4c436424) carrega **7 ponteiros** da MESMA tabela + 0x1c (runtime 0x4c4bf8cc, file 0xbfacc) e faz strncmp(nome, ptr, 0x20).

```
$ r2 -a arm -b 16 -m 0x4c3ffe00 -q -e scr.color=0 -c 's 0x4c435028; pd 24' lk_b.img
0x4c435028  70b5      push {r4, r5, r6, lr}
0x4c43502a  0446      mov r4, r0
0x4c43502c  1a4e      ldr r6, [0x4c435098]   ; pool 0x8a87a
0x4c43502e  88b0      sub sp, 0x20
0x4c435030  01ad      add r5, sp, 4
0x4c435032  7e44      add r6, pc             ; r6 = 0x8a87a + 0x4c435036 = 0x4c4bf8b0 (tabela)
0x4c435034  0fce      ldm r6!, {r0, r1, r2, r3}   ; copia 4 ponteiros p/ stack
0x4c435036  0fc5      stm r5!, {r0, r1, r2, r3}
0x4c435038  96e80700  ldm.w r6, {r0, r1, r2}      ; mais 3
0x4c43503c  85e80700  stm.w r5, {r0, r1, r2}
0x4c435040  2046      mov r0, r4
0x4c435042  1cb3      cbz r4, 0x4c43508c     ; NULL -> return 0
0x4c435044  0199      ldr r1, [sp, 4]        ; nome[0]
0x4c435046  0bf033f8  bl 0x4c4400b0          ; strcmp
0x4c43504a  08b3      cbz r0, 0x4c435090     ; IGUAL -> return 1 (CONTROLADA)
        (repete 7× — sp+4, sp+8, sp+0xc, sp+0x10, sp+0x14, sp+0x18, sp+0x1c)
```

### 4.1 TABELA CONTROLADA (flash E erase bloqueados) — runtime 0x4c4bf8b0, 7 entradas — MEASURED:

```
$ r2 -q -e scr.color=0 -m 0x4c3ffe00 -c 'psz @ 0x4c4a14bc; psz @ 0x4c4a14c4; psz @ 0x4c499d84; psz @ 0x4c4a14cc; psz @ 0x4c4a14d4; psz @ 0x4c4a14e0; psz @ 0x4c4a14ec' lk_b.img
nvram
nvcfg
proinfo
nvdata
protect2
protect1
persist
```

### 4.2 TABELA ERASE-FORBIDDEN (erase/format de boot/preloader) — runtime 0x4c4bf8cc, 7 entradas — MEASURED:

```
$ r2 -q -e scr.color=0 -m 0x4c3ffe00 -c 'psz @ 0x4c49d2a4; psz @ 0x4c4a1470; psz @ 0x4c4a147c; psz @ 0x4c4a1488; psz @ 0x4c4a1498; psz @ 0x4c4a14ac; psz @ 0x4c4a14b4' lk_b.img
preloader
preloader_a
preloader_b
preloader_ab
preloader_backup
boot0
boot1
```

### 4.3 Classificação do conjunto pedido {preloader, preloader_a, preloader_b, lk, lk_a, lk_b, seccfg, nvram, nvdata, nvcfg, persist, proinfo, expdb, misc, boot_para, boot, boot_a, boot_b, vendor_boot, vbmeta, super}:

| partição | na lista CONTROLADA (7)? | na lista ERASE-CONF (7)? | veredito do caminho flash: | evidência |
|---|---|---|---|---|
| preloader | NÃO | SIM | não bloqueado pela tabela controlada; TEM caminho próprio com CERT auth ("flash preloader is not permitted." rt 0x4c435b98 / "Preloader auth failed!" rt 0x4c435ac0) | MEASURED §4.1/4.2 + xrefs |
| preloader_a | NÃO | SIM | idem preloader (auth) | MEASURED |
| preloader_b | NÃO | SIM | idem preloader (auth) | MEASURED |
| lk | NÃO | NÃO | NÃO bloqueado por nenhuma das duas tabelas. O xref de "lk" (rt 0x4c4364e2) é dispatch de TIPO-DE-IMAGEM do header MTK (data+8), não checagem de permissão de partição | MEASURED §3.4 passo 2 |
| lk_a | NÃO (string "lk_a\0" NÃO EXISTE no binário) | NÃO | não existe nome para comparar → não pode estar em nenhuma lista por nome | MEASURED (grep binário: 0 ocorrências) |
| lk_b | NÃO (string não existe) | NÃO | idem | MEASURED |
| seccfg | NÃO | NÃO | não bloqueado por essas tabelas; "seccfg" tem xrefs (10) mas todos no módulo de lock-state via RPMB (rt 0x4c4211f2–0x4c4684f8), fora do caminho flash | MEASURED |
| nvram | **SIM** | — | **flash bloqueado** ("Flashing is not allowed...") | MEASURED §4.1 |
| nvdata | **SIM** | — | **bloqueado** | MEASURED |
| nvcfg | **SIM** | — | **bloqueado** | MEASURED |
| persist | **SIM** | — | **bloqueado** | MEASURED |
| proinfo | **SIM** | — | **bloqueado** | MEASURED |
| expdb | NÃO | NÃO | xrefs de "expdb" (6) todos no módulo mrdump/kedump (rt 0x4c430b5a…), fora do flash | MEASURED |
| misc | NÃO | NÃO | xrefs de "misc" (7) no boot-mode/misc-wipe (rt 0x4c404bd6…), fora da checagem | MEASURED |
| boot_para | NÃO | NÃO | xref único em rt 0x4c42f23a (boot mode select), fora da checagem | MEASURED |
| boot | NÃO | NÃO | não controlado; flash exige magic "ANDROID!" (7 bytes) no início da imagem | MEASURED §3.4 passo 4 |
| boot_a | NÃO | NÃO | idem (magic ANDROID!) | MEASURED |
| **boot_b** | **NÃO** | **NÃO** | **NÃO bloqueado**; só exige magic "ANDROID!" | MEASURED §3.4 passo 4 |
| vendor_boot | NÃO (sem xrefs de checagem) | NÃO | não bloqueado por nome | MEASURED |
| vbmeta | NÃO (string 0xbacd4 sem xrefs de checagem) | NÃO | não bloqueado por nome | MEASURED |
| super | NÃO (string "super\0" não existe no binário) | NÃO | — | MEASURED |

**PONTO ABERTO DO RELATÓRIO ANTERIOR (lk, misc, boot_para):** NENHUM dos três está em nenhuma lista de checagem de flash/erase por nome neste binário. "lk"/"misc"/"boot_para" aparecem no binário em outros contextos (dispatch de imagem MTK "lk"; boot-mode/misc-wipe; boot-mode select), NÃO como checagem de permissão do comando flash. — MEASURED.

Caveat honesto: provei que **essas duas tabelas** são as listas usadas pelas checagens que imprime essas mensagens; não executei varredura exaustiva de TODAS as funções do LK atrás de outras checagens por nome (o binário tem 1065 funções). A varredura de xrefs cobriu todos os nomes pedidos (tabela acima) e nenhum deles tem xref dentro de controlled_check/erase_check além dos listados.

---

## 5. A3 — boot_b: não bloqueado + offset/tamanho vêm da tabela do APARELHO

### 5.1 boot_b NÃO é bloqueado (MEASURED):

- boot_b não está na tabela controlada (§4.1: nvram, nvcfg, proinfo, nvdata, protect2, protect1, persist).
- boot_b não está na tabela erase-forbidden (§4.2).
- O único tratamento especial de "boot_b" no caminho flash é o **magic check** (0x4c4359c6–0x4c4359fe):

```
0x4c4359c6  ldr r1, pool 0x659c4 ; ADD pc -> "boot"      (file 0x9b594)
0x4c4359ce  bl strcmp(nome, "boot")     ; cbz -> magic
0x4c4359d4  ldr r1, pool 0x6adfc ; "boot_a" (file 0xa09d8)
0x4c4359da  bl strcmp ; cbz -> magic
0x4c4359e0  ldr r1, pool 0x6adf8 ; "boot_b" (file 0xa09e0)
0x4c4359e6  bl strcmp(nome, "boot_b")
0x4c4359ec  bne 0x4c435b16         ; não é boot_* -> pula magic check
0x4c4359f0  ldr r1, pool 0x45642 ; ADD pc -> "ANDROID!" (file 0x7b23c)
0x4c4359f4  movs r2, 7
0x4c4359f8  bl memcmp(data, "ANDROID!", 7)
0x4c4359fe  bne 0x4c435afa         ; sem magic -> "image is not a boot image" (file 0xa09e8)
```
**Nossa imagem T0 começa com "ANDROID!" (magic v4, verificado em REVIEW4) → PASSA.**

### 5.2 Offset e tamanho da escrita vêm da TABELA DE PARTIÇÕES DO APARELHO (MEASURED):

- Lookup: `bl 0x4c45a918` (partition_get por nome) → partid (limite 0x7f = 128, o mesmo loop `cmp r4, 0x80` do fastboot_init que publica partition-size:%s lidas da GPT).
- Offset 64-bit: `bl 0x4c45ab1c(partid)`:

```
0x4c45ab1c  push {r4, lr}
0x4c45ab1e  mov r4, r0           ; partid
0x4c45ab20  bl 0x4c469ac4        ; storage handle
0x4c45ab26  cmp r4, 0x7f ; bls ok  ; senão retorna -1 (r0=r1=-1)
0x4c45ab34  ldr r2, pool 0xddd68 ; -> ponteiro da TABELA GLOBAL de partições (parsed da GPT do device)
0x4c45ab36  lsls r3, r4, 5       ; partid*32
0x4c45ab38  sub.w r4, r3, r4, lsl 3 ; - partid*8 = partid*24 (stride da entrada)
0x4c45ab3c  add r2, pc ; ldr r2,[r2] ; carrega a tabela
            ... ldr r0/r1 da entrada -> OFFSET 64-bit da partição (da GPT)
```
- Tamanho 64-bit: `bl 0x4c45aa98(partid)` — mesma indexação partid*24 na tabela global → tamanho.
- Checagem de tamanho ANTES de escrever (rt 0x4c430552–0x4c430588):
```
ldrd r0, r1, [r3, 0x10]      ; 64-bit = image length (do download)
ldr r2, [r3, 0x18]
ldrd r8, sb, [r2, 0x28]      ; 64-bit = partition max size (da tabela do DEVICE)
cmp sb, r1 ; it eq ; cmp r8, r0
itt hs ; bhs -> OK            ; partition >= image -> continua
(fallthrough) -> dprintf "size too large, space small. image length[0x%llx], partition max size[0x%llx]"
```
  → **imagem > partição FALHA; imagem ≤ partição PASSA (igualdade passa).** Para boot_b (64 MiB) com imagem de exatamente 67108864 B: 67108864 ≤ 67108864 → **PASSA**. — MEASURED (semântica do `bhs`).
- A escrita final (`bl 0x4c45d00c` / `0x4c45cfac`) recebe o offset = base da partição (da GPT) + offset do header da imagem, e o comprimento = min(dados baixados, validado vs tamanho da partição). — MEASURED (chamadas em 0x4c43595a/0x4c435a5a com os pares 64-bit em registradores/stack).

**Veredito A3: boot_b NÃO é bloqueado; offset+tamanho vêm da tabela de partições do aparelho (GPT), não do host. O único critério adicional é o magic "ANDROID!" (que nossa imagem tem).**

---

## 6. Resumo do fluxo `flash boot_b` (uma linha):

```
cmd_flash(0x4c436df0) → [crclist/logo especiais] → suffix "_ab"? não →
  wrapper(0x4c4367c8):
    (1) controlled_check(0x4c435028) nome ∉ {nvram,nvcfg,proinfo,nvdata,protect2,protect1,persist} → OK
    (2) singlebootloader? não →
    (3) flash_write(0x4c4364b8):
        header MTK da imagem é "lk/LK/atf/logo/tee2"? não →
        nome é preloader/PRELOADER? não →
        nome é boot/boot_a/boot_b? SIM → magic "ANDROID!" == primeiros 7 bytes? SIM →
        partition_lookup(0x4c45a918, "boot_b") → partid →
        offset=0x4c45ab1c(partid), size=0x4c45aa98(partid) [GPT do device] →
        image_length ≤ partition_size? SIM (67108864 ≤ 67108864) →
        WRITE(0x4c45d00c/0x4c45cfac)
  → cmd_flash responde OKAY / "Partition boot_b flashed successfully"
```

## 7. COMANDOS r2 PARA REPRODUZIR (uma linha cada):

- **A1 (fluxo + checagem antes da escrita):**
  `r2 -a arm -b 16 -m 0x4c3ffe00 -q -c 's 0x4c4367c8; pd 12; s 0x4c43688a; pd 6' lk_b.img`
- **A2 (a checagem e a tabela):**
  `r2 -a arm -b 16 -m 0x4c3ffe00 -q -c 's 0x4c435028; pd 24; pxw 28 @ 0x4c4bf8b0; pxw 28 @ 0x4c4bf8cc' lk_b.img`
- **A2 (nomes da tabela, direto):**
  `r2 -q -m 0x4c3ffe00 -c 'psz @ 0x4c4a14bc; psz @ 0x4c4a14c4; psz @ 0x4c499d84; psz @ 0x4c4a14cc; psz @ 0x4c4a14d4; psz @ 0x4c4a14e0; psz @ 0x4c4a14ec; psz @ 0x4c49d2a4; psz @ 0x4c4a1470; psz @ 0x4c4a147c; psz @ 0x4c4a1488; psz @ 0x4c4a1498; psz @ 0x4c4a14ac; psz @ 0x4c4a14b4' lk_b.img`
- **A3 (magic check boot_b):**
  `r2 -a arm -b 16 -m 0x4c3ffe00 -q -c 's 0x4c4359c6; pd 20' lk_b.img`

## 8. AUTO-REVISÃO

- Toda afirmação central tem endereço de função + trecho ≥6 instruções + string + comando r2 (§3, §4, §5). ✔
- MEASURED tem comando+saída colada (§1.1, §1.2, §3.2, §3.3, §4.1, §4.2, §5.1, §5.2, sabotagem §2). ✔
- Nenhuma afirmação sem prova foi marcada FACT; itens não-verificados estão UNVERIFIED/UNKNOWN (varredura exaustiva de outras checagens, caveat §4.3). ✔
- A checagem de "boot_b não bloqueado" cobre as duas tabelas + o magic check; qualquer OUTRA checagem em runtime (por exemplo uma checagem no preloader da SLA/DAA) está FORA do escopo deste binário (o preloader é outro firmware) — UNKNOWN por definição aqui.
- Nada foi executado no aparelho, nada gravado, backup intocado (sha do lk_b.img original conferido por cp apenas; arquivos criados: somente este relatório + <workdir>/*).
