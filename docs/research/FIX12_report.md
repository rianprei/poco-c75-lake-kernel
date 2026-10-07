# FIX12 — REVIEW9 F4-F10, REVIEW10 F4, RUNBOOK A1-A14/L1-L6 (opencode)

> Commit único local, sem push. Base: main 3d82a2d (FIX11b) + branch fix12 (0fc9cdf, base 5746802).
> Método do projeto: cada defeito → linha §B no SPEC.md + invariante §V + teste em
> `tools/` ligado em `tools/run_all_checks.sh` + sabotagem em `tools/selftest_backprop.sh`
> (plantar defeito → FAIL → restaurar → PASS).

STATUS: DONE

## SABOTAGENS

`./tools/selftest_backprop.sh`: **62/62 FAIL→PASS** (casos 1–58, com variantes b).
`./tools/run_all_checks.sh`: **PASS (V1–V9 + aliases V10–V13 + V14–V56 + gate self-test, 57 verificações)**.

## Renumeração (exigência do GOAL: nenhum ID duplicado)

O main já usava B34–B36/V34 (FIX11) e continha as linhas do FIX12 sem renumerar
(B34–B36 e V43 duplicados, V41 ausente). O bloco FIX12 foi para depois do maior ID
do main: §B B37–B56, §V V35–V54. Resultado: **B1–B56 sequencial, V1–V54 (V10–V13
aliases), zero duplicados** — verificado por contagem (SPEC.md).

## MAPA — cada item das fontes → arquivo:linha

### REVIEW9 F4–F10 (F1–F3 já corrigidos pelo FIX10 — confirmado abaixo)

| ID | Fonte | Destino arquivo:linha | §B/§V | Sabotagem |
|----|-------|------------------------|-------|-----------|
| F1 já corrigido | REVIEW9 §2 (T2b `getvar all`) | `docs/DEVICE-TEST-PROTOCOL.md:100` (T2b relê só a allowlist, seis `getvar` inline) | — | caso 27 |
| F2 já corrigido | REVIEW9 §3.1 (README "one protected write") | `README.md:89` ("two protected writes of `boot_b` (T-1 backup, T3 kernel)") | — | — |
| F3 já corrigido | REVIEW9 §3.2 (T-1 antes de R3) | `docs/DEVICE-TEST-PROTOCOL.md:82` (`### R3`), `:88` (`### T-1`) | V32 | caso 29 |
| F4 | REVIEW9 §3.3 | `docs/DEVICE-TEST-PROTOCOL.md:27` (mandatory/optional + boot reason) | B37/V35 | caso 31 |
| F5 | REVIEW9 §3.4 | `docs/SAFETY.md:10` ("two protected writes") | B38/V36 | caso 32 |
| F6 | REVIEW9 §5.1 | `tools/check_regex_controls.sh:22-27` (5 docs) | B39/V37 | caso 53 |
| F7 | REVIEW9 §8/V21 | `tools/check_protocol_invariants.sh:533` (V38, closed, sem extras) | B40/V38 | casos 18b, 33 |
| F8 | REVIEW9 §8/V18 | `tools/check_protocol_invariants.sh:545` (V39, sem sentença stale + README duas escritas) | B41/V39 | caso 34 |
| F9 | REVIEW9 §8/V22+V26 | `tools/check_protocol_invariants.sh:315` (V22 frase exata), `:349` (V26 linha exata) | B42/V40 | casos 19b, 23b |
| F10 | REVIEW9 §9/F10 | `docs/research/README.md` (warning + tabela UNVERIFIED) | B43/V41 | caso 35 |

### REVIEW10 F4 (F1/F2/F5/F6 = F5/F4/F9/F10 acima; F3 = V29, feito pelo FIX11)

| ID | Fonte | Destino arquivo:linha | §B/§V | Sabotagem |
|----|-------|------------------------|-------|-----------|
| R10-F3 | REVIEW10 §8/V29 | `tools/check_protocol_invariants.sh:385` (V29 bidirecional linha-a-linha vs `data/lk_tables.tsv`) | B36/V29 (FIX11, preservado) | casos 26, 48, 49 |
| R10-F4 | REVIEW10 §8/V30 | `tools/check_protocol_invariants.sh:436` (V30 estrito: proibir + não-ordenar) | B44/V42 | casos 27b, 47 |

### RUNBOOK A1–A14, L1–L6

| ID | Fonte | Destino arquivo:linha | §B/§V | Sabotagem |
|----|-------|------------------------|-------|-----------|
| A1 = F4 | RUNBOOK §A1 | `docs/DEVICE-TEST-PROTOCOL.md:27` | B37/V35 | caso 31 |
| A8 = F5 | RUNBOOK §A8 | `docs/SAFETY.md:10` | B38/V36 | caso 32 |
| A2 | RUNBOOK §A2 | `docs/DEVICE-TEST-PROTOCOL.md:51` (rollback index 0 → LK CAN boot old slot A) | B45/V43 | caso 36 |
| A3 | RUNBOOK §A3 | `docs/DEVICE-TEST-PROTOCOL.md:64` + `docs/SAFETY.md:38` (string exists; `no`/`Variable not found`; `yes` = STOP) | B46/V44 | caso 37 |
| A4 | RUNBOOK §A4 | `docs/DEVICE-TEST-PROTOCOL.md:78` + `docs/SAFETY.md:28` (RE1 §3.3, `bl 0x4c4367d2` antes de `bl 0x4c436834`, MEASURED) | B47/V45 | caso 38 |
| A5 | RUNBOOK §A5 | `docs/DEVICE-TEST-PROTOCOL.md:93` (T-1.2 referencia o bloco; sem 3ª cópia inline — decisão: dedup do V31 vence inline; ver Decisões) + `:100` (T2b com os seis `getvar` inline) | B48/V46 | caso 39 |
| A6/A11 | RUNBOOK §A6/§A11 | `docs/DEVICE-TEST-PROTOCOL.md:106-107` (mesma forma `command fastboot` em T-1 e T3) + `:133` (guard bloqueia `flash lk`, permite exatamente os 2) | B49/V47 | caso 40 |
| A7 | RUNBOOK §A7 | `docs/DEVICE-TEST-PROTOCOL.md:110-111`, `docs/SAFETY.md:7`, (`README.md` não lista as partições — perna vacuosa) | B50/V48 | caso 41 |
| A9 | RUNBOOK §A9 | `docs/DEVICE-TEST-PROTOCOL.md:53` ("429 modules (example only); your number is your baseline") | B51/V49 | caso 42 |
| A10 | RUNBOOK §A10 | `docs/DEVICE-TEST-PROTOCOL.md:173` ("next normal boot on a good kernel") | B52/V50 | caso 43 |
| A12 | RUNBOOK §A12 | `docs/SAFETY.md:7` ("project policy — wider than...") | B53/V51 | caso 44 |
| A13 | RUNBOOK §A13 | `docs/DEVICE-TEST-PROTOCOL.md:121` (digitar a frase exata no terminal) | B54/V52 | caso 45 |
| L1–L6 | RUNBOOK §L | `docs/DEVICE-TEST-PROTOCOL.md:201-206` (tabela de lacunas) | B55/V53 | caso 46 |

Numeração final §B: FIX11 B34–B36, FIX12 B37–B55, SIGPIPE B56 (achado extra
desta sessão). Numeração final §V: FIX11 V34, FIX12 V35–V53, SIGPIPE V54.

### Ajustes exigidos pelo GOAL (V34/V35/V38 + sabotagens V41/V50/V51/V52)

| Item | Destino | Sabotagem real |
|------|---------|----------------|
| V34 (never-touch, FIX11, preservado do main) | `tools/check_protocol_invariants.sh:493`, SPEC B35/V34 | casos 50, 51, 52 |
| V35 (GOAL chamava V34: header Z0) | `:507`, SPEC B37/V35 | caso 31 |
| V36 (GOAL chamava V35: SAFETY duas escritas) | `:518`, SPEC B38/V36 | caso 32 |
| V38 (allowlist fechada) | `:533`, SPEC B40/V38 | casos 18b, 33 |
| V39 (GOAL chamava V38: sem sentença stale) | `:545`, SPEC B41/V39 | caso 34 |
| V42 ex-V41 (getvar-all estrito) | `:578`, SPEC B44/V42 | casos 27b, 47 |
| V50 ex-V49 (pstore) | `:659`, SPEC B52/V50 | caso 43 |
| V51 ex-V50 (project policy) | `:667`, SPEC B53/V51 | caso 44 |
| V52 ex-V51 (accept in writing) | `:675`, SPEC B54/V52 | caso 45 |

## Decisões de merge (preservando os dois lados)

1. **V29**: ficada a versão bidirecional linha-a-linha do main (FIX11b), não a
   presença-por-nome do fix12. Mais forte; casos 48/49 a provam.
2. **V31**: nem a versão do fix12 (só-bloco, cega fora do bloco) nem a do main
   (arquivo-todo, quebra com as 2 menções-referência em células de tabela).
   Contagem por **posição de comando** (linha começa com o comando):
   `tools/check_protocol_invariants.sh:456`.
3. **V30**: ficada a versão estrita do fix12 (proibir + não-ordenar), superconjunto
   da do main.
4. **V18/V22**: ficadas as formas exatas do fix12 (mais fortes que as frouxas do main).
5. **T-1.2 (A5)**: referência indireta ao bloco (dedup do V31, já no main) vence o
   "inline" sugerido no RUNBOOK; T2b/A14 com os seis `getvar` inline (RUNBOOK atendido).
6. **T3 (A6)**: mesma forma `command fastboot` nos dois comandos (decisão B37 do main).
7. **SPEC do main**: descartadas as linhas duplicadas (B34–B36 e V43 duplo, V41
   ausente); mantidas as 3 linhas FIX11 (B34–B36) e inseridas antes do bloco FIX12.

## Achados extras da releitura hostil (esta sessão, todos com backprop)

| # | Achado | Backprop |
|---|--------|----------|
| E1 | Race `pipefail`+SIGPIPE: 33 pipelines `printf … \| grep -q` + 2 nos harnesses flakavam sob carga (141). Convertidos para herestring. | B56/V54, `tools/check_sigpipe.sh`, caso 54 |
| E2 | V38 tinha check morto (backticks escapados `\`` = âncora GNU, nunca casava). | B56 (mesma linha), corrigido + TWINS |
| E3 | Homoglyph cirílico U+0430 em "não bootа" (tabela L2, herdado do 0fc9cdf). Varredura: único no repo. | corrigido em `docs/DEVICE-TEST-PROTOCOL.md:202` |
| E4 | Nota V37 dizia "V36:" (número stale pós-renumeração). | corrigido |
| E5 | Caso 41 invocava `sed` no README sem o par `protect1/protect2` (no-op desonesto). | removido do caso; TWINS documenta perna vacuosa |

## Verificação (observada, não inferida)

- `./tools/run_all_checks.sh` → `run_all_checks: PASS (V1-V9 + aliases V10-V13 + V14-V54 + gate self-test)` (55 verificações), exit 0.
- `./tools/selftest_backprop.sh` → `SABOTAGENS: 58 detectada(s) FAIL->PASS, 0 falha(s)`, estável em 3+ rodadas (o flake E1 foi eliminado na causa-raiz, não com retry).
- `git status` limpo; worktree de integração e branch `fix12` removidos após o merge.
- Nenhum ID §B/§V duplicado: B1–B56, V1–V54 (V10–V13 aliases).

## ABERTO

Nenhum — exceto §T do SPEC.md (itens sabidamente não-provados, por desenho).

| E6 | Symptom-table citava SAFETY:11 para o fato userdata-backup (vive em SAFETY:8). | B57/V55, refs corrigidas para SAFETY:8 |

| E7 | SAFETY recovery path sem o prefixo `command` (guard bloquearia o rollback). | B59/V47, forma corrigida + V47 estendido |
| E8 | README com ranges stale da suite + falta de `check_sigpipe.sh` na lista. | B58/V39, texto range-free + V39 estendido |
| E9 | T-1.3/baseline sem `adb shell` (leria o host). | B60/V56, prefixos + V56 novo |
