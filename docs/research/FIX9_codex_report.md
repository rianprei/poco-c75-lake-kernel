# FIX9 — Z0′ do revisor incorporado ao protocolo (codex)

> Commit único local, sem push. Escopo proibido intocado: aparelho, `<HOME>/lake-build`, `audit/`, `backup-*`, vault tabs-agent-os. Só `<HOME>/Documentos/mods/poco-c75-lake-kernel` (+ leitura de `<HOME>/Documentos/mods/lake-kernel/research/Z0_review_freebuff.md` e do dump via `strings -n 5`, só leitura).

STATUS: DONE

## Reconfirmação prévia (item 11 do prompt)

Dump refeito em `<workdir>/lk_strings.txt`: **byte a byte idêntico** ao `<workdir>/lk_b_strings.txt` do revisor (14014 linhas). Linhas citadas conferidas: 5088, 5171–5172, 6537–6538, 6698–6705, 6850–6863, 7133, 7140–7180 (tabela getvar com todos os 15 nomes da allowlist), 7155–7197 (comandos `oem`, incl. `oem allow-wipe-userdata` 7119–7121/7193), 7182, 8500. `getvar all` ausente (confirmado — revisor correto). Único deslize do revisor: `unlocked` duplicado na lista Z0′-3 (deduplicado aqui; resto do relatório sem erro encontrado).

## Itens a–g (B21–B27 + V21–V27)

- **a) Allowlist fechada (B21/V21):** Z0.3 com 15 `getvar` (um por linha) + proibição de `getvar all`, qualquer `oem` (citando `oem allow-wipe-userdata`) e fora-da-lista. Teste: 17 oks (15 nomes + 2 proibições). Sabotagem 18 (deleta 1 nome).
- **b) PASS por teclas (B22/V22):** Z0.1 aparelho desligado + Vol−+Power; Z0.0 `adb reboot bootloader` marcado opcional/documental. Teste: 2 oks. Sabotagem 19 (Z0.0 vira "mandatory").
- **c) slot!=b (B23/V23):** Z0.4 exceção — power off por teclas, never `fastboot reboot`. Teste: 1 ok. Sabotagem 20 (inversão always/never).
- **d) Carregador (B24/V24):** pré-condição "charger disconnected". Teste: 1 ok. Sabotagem 21 (connected).
- **e) Sem adb em 3 min (B25/V25):** Power longo → teclas → uma vez; segunda falha ends the day; no USB improvisation. Teste: 1 ok (3 tokens). Sabotagem 22.
- **f) Baseline do dia (B26/V26):** módulos ⊇ baseline do dia; `~429` só referência. Teste: 1 ok (linha com 429+reference). Sabotagem 23.
- **g) Lista honesta (B27/V27):** "What Z0 does not prove" + UNVERIFIED. Teste: 1 ok. Sabotagem 24.
- SPEC §V: linhas V21–V27; §B: linhas B21–B27; TWINS ×8; `run_all_checks.sh` fiado (loop, resumo, 21→28 verificações).

## Item 4 — verificações

- `tools/run_all_checks.sh`: **PASS (V1–V27 + GATE, 28 verificações)**.
- `tools/selftest_backprop.sh`: **24 sabotagens FAIL->PASS, 0 falhas** (casos 18–24 novos, todos de primeira).
- Sensíveis: 0 ocorrências reais dos 5 padrões do prompt (só há menções-meta no relatório FIX8, pré-existentes); `cpuid` como nome de getvar sequer entrou na allowlist. Cuidado do prompt observado: busquei pelo fragmento hexadecimal, não pela palavra `cpuid` (evita o falso-positivo `cpuidle`).

Commit único local (sem push): ver `git log -1 --format='%H %s'`; conteúdo de código/docs selado em 9c3bdebd5c1da533c86c48c1f988bb6ee24946c9, este relatório anexado ao mesmo commit.
