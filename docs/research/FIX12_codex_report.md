# FIX12 — V31 fix for duplicate fastboot flash in T-1.2 table (codex)

> Commit único local, sem push. Escopo: correção do V31 (comando `fastboot flash` duplicado na tabela T-1.2). Base: HEAD 3ab04bd (FIX11b).

STATUS: DONE

## O problema (V31 FAIL)
O protocolo tinha 3 ocorrências de `fastboot flash`:
1. Linha 93: T-1.2 tabela com `command fastboot flash boot_b <path/to/backup/boot_b.img>`
2. Linha 106: Bloco "The two write commands" - T-1
3. Linha 107: T3

O V31 conta 3 ocorrências mas README afirma 2 escritas protegidas (T-1 backup + T3 kernel).

## Correção
Removido o comando `command fastboot flash boot_b <path/to/backup/boot_b.img>` da linha T-1.2 da tabela (que referenciava o bloco "The two write commands" abaixo). Agora T-1.2 diz: "run the T-1 command from *The two write commands* below".

Arquivo alterado: `docs/DEVICE-TEST-PROTOCOL.md:92`

## Verificações
- `./tools/run_all_checks.sh`: PASS (V1-V34 + GATE, 35 verificações)
- `./tools/selftest_backprop.sh`: 35/35 sabotagens FAIL→PASS
- `./tools/run_all_checks.sh` (com `./`): PASS (prova do exec bit)

## Commit
Commit único local, sem push. Hash no relatório.