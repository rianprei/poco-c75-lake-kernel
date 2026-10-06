# FIX10 — real LK partition tables + REVIEW8 findings + exec bits (codex)

> Commit único local, sem push. Escopo proibido intocado: aparelho, `~/lake-build`, `audit/`, `backup-*`, vault tabs-agent-os, `lk_b.img`/dumps (só leitura). Base: HEAD b55408d.

STATUS: DONE

## Tarefa 1 — tabelas medidas no SAFETY/PROTO

- `docs/SAFETY.md:34`: linha errada (`preloader*`, `seccfg`, `expdb`) substituída por 3 linhas MEDIDO: controlada @`0x4c4bf8b0` (7 nomes), erase-forbidden @`0x4c4bf8cc` (7 nomes, boot0/boot1 = HW eMMC), e os 7 NÃO-protegidos com 7 frases explícitas (`docs/SAFETY.md:34,36-37`).
- `docs/SAFETY.md:28`: ordem checa→grava agora MEDIDO (RE1 §3; `bl` 0x4c4367d2 → `beq` 0x4c43688a → write só 0x4c436834; `bhs` = igualdade passa).
- `docs/SAFETY.md:7` regra 1: `protect1`, `protect2` adicionados ao never-touch.
- `docs/DEVICE-TEST-PROTOCOL.md` §NEVER: parágrafo da denylist reescrito com as tabelas medidas + `protect1, protect2` na lista.
- Verificação das tabelas contra o binário refeita por mim (strings da tabela via `psz`; 7+7 nomes conferem com RE1 §4.1/4.2).

## Tarefa 2 — RE1 copiado e redigido

- `docs/research/RE1_opencode_flash.md` (novo): cópia byte a byte do original com o prefixo de scratch do agente → `<workdir>` e o prefixo do vault → `<lake-kernel>` (únicas ocorrências de caminho de máquina; zero ocorrências após), registrado no índice de `docs/research/README.md`.

## Tarefa 3 — achados REVIEW8 (todos)

- F2.4: seção T-1 movida para depois de R3/pre-flight (`docs/DEVICE-TEST-PROTOCOL.md:82` T-1 > `:60` R3; V18 range atualizado para `/^### T-1/,/^| T2b/`).
- F5.1: T2b reescrito sem "RAM experiment" e sem `getvar all` (usa allowlist Z0.3); `:112` "photograph `getvar all`" → "photograph the fastboot screen and the allowlist output".
- F5.2: `README.md:89` → "two protected writes of `boot_b` (T-1 backup, T3 kernel)".
- F2.6: bloco "The two write commands" lista os dois comandos com gates (`:103-106`).
- F2.1: T-1.1 registra hash do operador + valor auditado `3890fb96…829fc7` e que `SHA256SUMS.log` vive com o backup, não no repo.
- F2.2: T-1.2 "T-1 usa o **backup**; `boot_b_new.img` é só para o T3".
- F2.3: T-1.2 avisa classe de risco de interrupção (reescreve slot ativo; Z0/bateria/cabo minimizam).
- F1.1: `docs/SAFETY.md:43` → "(`movs r0, 1` at `0x4c42b264`; `bl` at `0x4c42b266`)".
- F4.1: caminhos redigidos nas cópias RE2 (`:3,93`), RE4 (`:3,81,85`), FIX9 (`:9`), FIX8 (`:37`, caminho da home removido).
- F4.2: citas pendentes anotadas "(retido — não publicado)": RE2 `:94` (REVIEW3_opencode_cmdaudit), RE4 `:55` (W7 REVIEW6), `:69` (REVIEW6 M6). Desvio da sugestão literal: usei redação auto-resolvida em vez de "(retido; ver ... §dumps)" porque o README não tem seção §dumps (a seção correspondente é *Where the raw device dumps are*).
- F4.3: mojibake RE4 "não deциалoop" → "não entra em reboot-loop".
- F8.1: `docs/research/FIX8_codex_report.md:38` → "verificado pela árvore de c8bb481".

## Tarefa 4 — exec bits

- `chmod +x tools/*.sh` + `git update-index --chmod=+x`: 11 arquivos 100755 no índice e 755 no disco (7 estavam 644).

## Tarefa 5 — backprop (B28–B33 + V28–V33)

- `SPEC.md`: linhas B28–B33 (§B), V28–V33 (§V), TWINS ×7. `data/lk_tables.tsv` criado (14 linhas endereço+nome+tabela).
- Testes em `tools/check_protocol_invariants.sh:319-400` (V28–V33); fiação em `run_all_checks.sh:22-27,65,69`.
- Sabotagens 25–30 em `tools/selftest_backprop.sh:144-167` (uma por V).

## Tarefa 6 — suítes

- `bash tools/run_all_checks.sh`: PASS (V1–V33 + GATE, 34 verificações).
- `bash tools/selftest_backprop.sh`: 30/30 FAIL->PASS.
- `./tools/run_all_checks.sh`: PASS (exit 0 — prova do exec bit).
- Sensíveis: 0 ocorrências reais (fragmento cpuid, IP privado, seriais, tokens, caminho home).

## Mapa REVIEW8 → arquivo:linha (todos corrigidos)

- F1.1 → `docs/SAFETY.md:43` (endereços `movs`/`bl` separados).
- F2.1 → `docs/DEVICE-TEST-PROTOCOL.md:92` (hash do operador + valor auditado + `SHA256SUMS.log` fora do repo).
- F2.2 → `docs/DEVICE-TEST-PROTOCOL.md:93` (backup no T-1, `boot_b_new.img` só no T3).
- F2.3 → `docs/DEVICE-TEST-PROTOCOL.md:93` (classe de risco de interrupção, slot ativo).
- F2.4 → `docs/DEVICE-TEST-PROTOCOL.md:82` (T-1 depois de R3 `:60`; V18 range atualizado).
- F2.6 → `docs/DEVICE-TEST-PROTOCOL.md:103-106` (bloco com os dois comandos + gates).
- F4.1 → `docs/research/RE2_codex_bootmode.md:3,93`, `RE4:3,81,85`, `FIX9:9`, `FIX8:37` (redigidos); V33 em `tools/check_protocol_invariants.sh`.
- F4.2 → mesmas linhas com "(retido — não publicado)".
- F4.3 → `docs/research/RE4_codex_fallback.md:55` ("não entra em reboot-loop").
- F5.1 → `docs/DEVICE-TEST-PROTOCOL.md:100` (T2b sem RAM/getvar-all) e `:113` (foto da tela + allowlist).
- F5.2 → `README.md:89` ("two protected writes of `boot_b` (T-1 backup, T3 kernel)").
- F8.1 → `docs/research/FIX8_codex_report.md:38` ("verificado pela árvore de c8bb481").
- Tabelas LK → `docs/SAFETY.md:28,34,36-37` + `data/lk_tables.tsv` (14 linhas); regra 1 (`:7`) com protect1/protect2.
- B28–B33 → `SPEC.md:46-51`; V28–V33 → `SPEC.md:116-121`; testes `tools/check_protocol_invariants.sh`; sabotagens 25–30 `tools/selftest_backprop.sh:144-167`; fiação `tools/run_all_checks.sh:22-27`.

Commit único local (sem push): ver `git log -1 --format='%H %s'`; conteúdo de código/docs selado em 08049b2d2c4f1a41fa57ccd261b823810fb4d466, este relatório anexado ao mesmo commit.
