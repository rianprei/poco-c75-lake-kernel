#!/usr/bin/env bash
# check_regex_controls.sh — V2 (invariant): every `grep` pattern a reader is told to run must have
# a POSITIVE control (matches a planted bad line) and a NEGATIVE control (matches nothing in a
# clean log), and no -E pattern may use `\|` (a literal pipe: it can never match, which is exactly
# how the dmesg check silently passed before — BUG B2).
#
# Scope of the "reader is told to run" set: every grep command extracted from
# docs/DEVICE-TEST-PROTOCOL.md. Each one is classified by the artifact it reads:
#   dmesg               -> tests/fixtures/dmesg_bad.txt | dmesg_clean.txt
#   SHA256SUMS          -> tests/fixtures/sha256sums_bad.txt | sha256sums_clean.txt
#   anything else       -> FAIL (no control exists; add a fixture or drop the command)
# The same `\|`-in--E rule is applied to every shell script under tools/ and scripts/.
#
# usage: tools/check_regex_controls.sh      (read-only; prints V2 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"

python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
doc = root / 'docs/DEVICE-TEST-PROTOCOL.md'
fix = root / 'tests/fixtures'
fails = []
def fail(m): fails.append(m); print(f'V2 FAIL {m}')

CMD = re.compile(r'grep\s+((?:-[A-Za-z]+)\s+)*?["\'](.*?)["\']')
QUOTED = re.compile(r'grep\s+(-[A-Za-z]+(?:\s+-[A-Za-z]+)*)\s+(["\'])(.*?)\2')

# ---- 1. every -E grep in the protocol, with its control -----------------------------------------
patterns = []          # (line_no, flags, pattern, fixture_pair|None)
for i, line in enumerate(doc.read_text().splitlines(), 1):
    for m in QUOTED.finditer(line):
        flags, _, pat = m.groups()
        if 'E' not in flags:
            continue
        if r'\|' in pat:
            fail(f'docs/DEVICE-TEST-PROTOCOL.md:{i} padrão -E com pipe escapado (nunca casa): {pat!r}')
            continue
        if 'dmesg' in line:
            pair = ('dmesg_bad.txt', 'dmesg_clean.txt')
        elif 'SHA256SUMS' in line:
            pair = ('sha256sums_bad.txt', 'sha256sums_clean.txt')
        else:
            pair = None
        patterns.append((i, flags, pat, pair))
        if pair is None:
            fail(f'docs/DEVICE-TEST-PROTOCOL.md:{i} grep {flags} sem fixture de controle: {pat!r}')
            continue
        try:
            rx = re.compile(pat, re.IGNORECASE if 'i' in flags else 0)
        except re.error as e:
            fail(f'docs/DEVICE-TEST-PROTOCOL.md:{i} padrão inválido ({e}): {pat!r}')
            continue
        bad_hits = [l for l in (fix / pair[0]).read_text().splitlines() if rx.search(l)]
        clean_hits = [l for l in (fix / pair[1]).read_text().splitlines() if rx.search(l)]
        if not bad_hits:
            fail(f'docs/DEVICE-TEST-PROTOCOL.md:{i} controle POSITIVO falhou ({pair[0]}): {pat!r}')
        if clean_hits:
            fail(f'docs/DEVICE-TEST-PROTOCOL.md:{i} controle NEGATIVO falhou ({pair[1]} casou {len(clean_hits)} linha(s)): {pat!r}')
        if bad_hits and not clean_hits:
            print(f"V2 OK   docs/DEVICE-TEST-PROTOCOL.md:{i} controle positivo+negativo ({pair[0]}: {len(bad_hits)} linhas)")

# every reader-runnable dmesg check must exist at all
dmesg_runnable = [p for p in patterns if p[3] and p[3][0] == 'dmesg_bad.txt']
if not dmesg_runnable:
    fail('docs/DEVICE-TEST-PROTOCOL.md não contém NENHUM comando grep -E executável sobre o dmesg '
         '(o critério de aceitação "dmesg has no Unknown symbol…" não é verificável pelo leitor)')

# ---- 2. every planted error class must be covered ----------------------------------------------
if dmesg_runnable:
    rxs = [re.compile(p[2], re.IGNORECASE if 'i' in p[1] else 0) for p in dmesg_runnable]
    for line in (fix / 'dmesg_bad.txt').read_text().splitlines():
        if 'Booting Linux' in line:
            continue
        if not any(r.search(line) for r in rxs):
            fail(f'tests/fixtures/dmesg_bad.txt classe de erro não coberta pelos padrões dos docs: {line.strip()[:80]}')

# ---- 3. same `\|`-in--E ban across the shell tooling -------------------------------------------
for sh in sorted(list((root / 'tools').rglob('*.sh')) + list((root / 'scripts').rglob('*.sh'))):
    for i, line in enumerate(sh.read_text().splitlines(), 1):
        for m in QUOTED.finditer(line):
            flags, _, pat = m.groups()
            if 'E' in flags and r'\|' in pat:
                fail(f'{sh.relative_to(root)}:{i} grep -E com pipe escapado: {pat!r}')

if fails:
    print(f'V2 FAIL {len(fails)} controle(s) ausente(s)/invertido(s)')
    sys.exit(1)
print(f'V2 PASS {len(patterns)} padrão(ões) -E com controles positivo+negativo; 0 pipe escapado')
PY
