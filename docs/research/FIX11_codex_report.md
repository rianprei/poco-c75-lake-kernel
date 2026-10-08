# FIX11 — V29 table-row check + V34 never-touch completeness (codex)

> Commit único local, sem push. Escopo proibido intocado: aparelho, `<HOME>/lake-build`, `audit/`, `backup-*`, vault tabs-agent-os. Só `<HOME>/Documentos/mods/poco-c75-lake-kernel`.

STATUS: DONE

## Resumo das correções (itens REVIEW8 B34, B35 + V29 fix, V34)

### 1. V29: checagem por linha da tabela (não arquivo inteiro) — B34
**Problema:** O V29 original buscava os nomes das tabelas controlada/erase-forbidden no arquivo inteiro do SAFETY.md, permitindo que um nome removido da tabela ainda passasse se aparecesse em outro lugar (ex.: na regra 1 "Never touch").

**Correção:** `tools/check_protocol_invariants.sh` agora extrai a linha da tabela controlada (que contém `0x4c4bf8b0`) e a linha da tabela erase-forbidden (que contém `0x4c4bf8cc`), e valida que cada um dos 7+7 nomes está presente **na respectiva linha**. Testado com sabotagem: remover `protect2` da linha da tabela controlada → V29 FAIL; cópia limpa → PASS.

Arquivos: `tools/check_protocol_invariants.sh` (linhas 336-355), `tools/selftest_backprop.sh` caso 26.

### 2. Regra 1 "Never touch" + V34 — inclusão de `misc`, `boot_para`, `expdb` — B35, V34
**Problema:** A regra 1 do SAFETY.md listava apenas 10 itens; a tabela medida tem 14 nomes (7 controlados + 7 erase-forbidden). Faltavam `misc`, `boot_para`, `expdb` na regra 1, embora o SAFETY.md:36 já declarasse que o bootloader NÃO os protege. O protocolo já os proibia na lista NEVER.

**Correção:** 
- `docs/SAFETY.md:7` regra 1 agora lista os 13 itens críticos (preloader, lk, seccfg, nvram, nvdata, nvcfg, persist, proinfo, protect1, protect2, **misc, boot_para, expdb**).
- `docs/DEVICE-TEST-PROTOCOL.md` lista NEVER já continha os 3 itens.
- Nova invariante **V34**: verifica que a regra 1 e a lista NEVER do protocolo contêm exatamente o conjunto {preloader, lk, seccfg, nvram, nvdata, nvcfg, persist, proinfo, protect1, protect2, misc, boot_para, expdb}. Sabotagens: remover `misc` da regra 1 → V34 FAIL; remover `boot_para`/`expdb` da lista NEVER → V34 FAIL.

Arquivos: `docs/SAFETY.md:7`, `docs/DEVICE-TEST-PROTOCOL.md:111`, `tools/check_protocol_invariants.sh` (V34), `tools/selftest_backprop.sh` casos 31-33, `tools/run_all_checks.sh` (V34 no resumo).

### 3. Execução dos testes

- `./tools/run_all_checks.sh`: PASS (V1–V34 + GATE)
- `./tools/selftest_backprop.sh`: **33/33 sabotagens FAIL→PASS**

## Arquivos alterados

- `docs/SAFETY.md`: regra 1 + tabela medida (linha 7, 28, 34, 36-37)
- `docs/DEVICE-TEST-PROTOCOL.md`: lista NEVER já continha os 3 itens
- `tools/check_protocol_invariants.sh`: V29 por linha de tabela, V34 novo
- `tools/run_all_checks.sh`: V34 no loop e resumo
- `tools/selftest_backprop.sh`: sabotagens 31-33 (Python heredoc para evitar problemas de quoting)
- `SPEC.md`: B34, B35 + V34; TWINS atualizados

## Commit

Commit único local (sem push): `git log -1 --format='%H %s'` → hash no relatório.