# FIX8 — write-path rehearsal T-1 + disassembly findings + is-userspace guard (codex)

> Commit único local, sem push. Escopo proibido intocado: aparelho, `~/lake-build`, `audit/`, `backup-*`, vault tabs-agent-os. Só `~/Documentos/mods/poco-c75-lake-kernel` (+ leituras de `~/Documentos/mods/lake-kernel/research/RE2|RE4_codex_*.md`).

STATUS: DONE

## Item 1 — passo T-1 no protocolo (B18 + V18)

`docs/DEVICE-TEST-PROTOCOL.md`: nova seção `### T-1 — write-path rehearsal with identical content` entre Z0 e R3 — reflashes o **próprio backup de `boot_b`** (hash conferido) sobre `boot_b` via `command fastboot flash boot_b <backup>`; só após **Z0 PASS** e "yes" explícito do dono; T-1.3 confirma boot idêntico (incremental + `uname -r` stock). Textos ajustados para a nova contagem de escritas: intro (§"two write commands"), regra 5 (exceção T-1), linha T3 ("write command for the new kernel"), "The two write commands", guarda (`command fastboot ...` para T-1/T3), aviso T3 (pré-requisito **T-1 passed**).

- §B: `SPEC.md` linha B18 (primeira escrita era o kernel novo, sem demonstração prévia do caminho).
- §V: `SPEC.md` linha V18 (primeira escrita = rehearsal idêntico, Z0 PASS + owner yes + hash, sem frase "single write").
- Teste: `tools/check_protocol_invariants.sh` bloco V18 (6 oks: header T-1, gate Z0, gate owner, `sha256sum`, `identical`, forma `command fastboot flash boot_b`, ausência da frase `one and only write command`).
- Sabotagem: `tools/selftest_backprop.sh` caso 15 (deleta o header `### T-1 ` → `^V18 FAIL`; primeira mutação renomeava mas o intervalo `sed` ainda casava o prefixo — cego; trocada pela deleção, que detecta).

## Item 2 — achados de desmontagem no SAFETY (B19 + V19)

- `docs/research/RE2_codex_bootmode.md` + `docs/research/RE4_codex_fallback.md` copiados de `~/Documentos/mods/lake-kernel/research/` (94 + 85 linhas, byte a byte).
- `docs/SAFETY.md`, tabela LK: 3 linhas novas como MEDIDO (desmontagem): fallback imediato mesmo-boot (`RE4_codex_fallback.md` D1, `RE2_codex_bootmode.md` B2); ambos-inválidos → `fastboot_init` não-retornante (`fcn.4c461724`, fail-exit `0x4c42b264`; `RE4` D2, `RE2` B1c); retry com rótulo UNVERIFIED permanente.
- `SPEC.md` §T: bullets de fallback e Z0 atualizados com as citas de desmontagem (on-device continua UNVERIFIED).
- §B: linha B19 (tabela sem os achados RE2/RE4). §V: linha V19 (linhas da tabela citam RE2/RE4 + função/endereço; não-provado segue UNVERIFIED).
- Teste: bloco V19 (5 oks: `RE4_codex_fallback.md`, `RE2_codex_bootmode.md`, `fcn.4c461724`, `0x4c42b264`, `retry.*UNVERIFIED`).
- Sabotagem: caso 16 (deleta linhas com `fcn.4c461724` → `^V19 FAIL`).

## Item 3 — `is-userspace` existe no `lk_b` (B20 + V20)

Varredura: nenhuma instrução do repo afirma ausência da variável (SAFETY:36, protocolo R3/Z0 e SPEC §T já dizem que a string existe; B16 é registro histórico do erro antigo, preservado). Sem texto a corrigir — adicionada a guarda contra regressão:

- §B: linha B20. §V: linha V20 (escopo: `README.md`, `docs/SAFETY.md`, `DEVICE-TEST-PROTOCOL.md`, `PLAN-AND-FINDINGS.pt-BR.md`, `KMI-GATES.md`, `BUILD.md`; `docs/research/` fora, coberto pelo aviso V8).
- Teste: bloco V20 (rejeita `is-userspace … does not exist|not exist|absent|missing|no such` a até 90 colunas).
- Sabotagem: caso 17 (anexa `Note: is-userspace does not exist in lk_b.` → `^V20 FAIL`, citando `docs/SAFETY.md:62`).

## Item 4 — verificações

- `tools/run_all_checks.sh`: V1–V20 + GATE = **PASS** (21 verificações; fiação V18–V20 adicionada ao resumo).
- `tools/selftest_backprop.sh`: **17 sabotagens detectadas FAIL->PASS, 0 falhas** (casos 15/16/17 novos; caso 15 exigiu 2 abordagens de mutação).
- Varredura de sensíveis no repo (fora `.git`): `b3c3369d` = 0, `192.168` = 0, caminho absoluto da home do operador = 0, `serialno|serial_number` nos arquivos tocados = 0.

Commit único local (sem push): ver `git log -1 --format='%H %s'`; conteúdo de código/docs selado em 2b40b0c02f5acbdf13f6a855a59ca92e888c566d, este relatório anexado ao mesmo commit.
