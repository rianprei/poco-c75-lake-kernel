# FIX11b — V29 bidirectional check (codex)

> Commit único local, sem push. Escopo: `tools/check_protocol_invariants.sh`, `tools/selftest_backprop.sh`, `SPEC.md`. Base: HEAD 2111f69.

STATUS: DONE

## O problema (REVIEW10 F3)
O V29 original só verificava se os nomes da TSV existiam no SAFETY.md (arquivo inteiro). Não validava:
1. Se os nomes estavam na **linha correta da tabela** (controlada vs erase-forbidden)
2. Se a linha da tabela continha **nomes extras** não presentes na TSV
3. Se a linha da tabela tinha **nomes faltando** presentes na TSV

## Correção (V29 bidirecional)
`tools/check_protocol_invariants.sh`: V29 agora:
- Extrai a linha da tabela controlada (contém `0x4c4bf8b0`) e erase-forbidden (`0x4c4bf8cc`)
- Extrai os nomes de cada linha do SAFETY.md
- Constrói conjuntos esperados a partir de `data/lk_tables.tsv` (controlled / erase-forbidden)
- **Bidirecional**: SAFETY == TSV (sem nomes extras, sem nomes faltando, na tabela correta)

## Sabotagens novas (tools/selftest_backprop.sh casos 27-28)
- Caso 27: insere `seccfg, ` na linha da tabela controlada → V29 FAIL (nome extra na controlada)
- Caso 28: move `boot0` da linha erase-forbidden para a controlada → V29 FAIL (nome movido entre tabelas)

## Verificações
- `./tools/run_all_checks.sh`: PASS (V1–V34 + GATE, 35 verificações)
- `./tools/selftest_backprop.sh`: 35/35 sabotagens FAIL→PASS
- `./tools/run_all_checks.sh` (com `./`): PASS — prova do exec bit

## SPEC.md
- B36: V29 só checava existência no arquivo, não correspondência exata por linha
- V29 atualizada: "Bidirectional: SAFETY table rows must match TSV exactly (no extra, no missing)."

## Commit
Commit único local (sem push): `git log -1 --format='%H %s'`.