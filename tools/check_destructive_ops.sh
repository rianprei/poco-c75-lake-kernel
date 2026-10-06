#!/usr/bin/env bash
# check_destructive_ops.sh — V6 (invariant): every `rm -rf` that the shell actually executes in
# tools/**.sh and scripts/**.sh must target a directory the script itself created with `mktemp -d`
# and removes through a trap (or a cleanup function wired to a trap). A literal path
# (`rm -rf /tmp/opencode`) can delete a user's directory and is a hard FAIL — that is BUG B6.
#
# Only real command positions are considered (start of line, after ; & | { (, after then/do/else,
# or inside a `trap '...'`), and comment lines are ignored, so the checker's own message strings and
# the sabotage fixture in tools/selftest_backprop.sh are not reported as if the shell ran them.
#
# usage: tools/check_destructive_ops.sh      (read-only; prints V6 PASS|FAIL lines)
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"

python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
RM = re.compile(r'\brm\s+(-[a-zA-Z]*[rf][a-zA-Z]*[rf]?[a-zA-Z]*)\s+(.*)$')
MKTEMP = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"?\$\(mktemp\s+-d')
TRAP = re.compile(r'trap\s+(["\'])(.*?)\1')
ALLOWED_PREV = {'', ';', '&', '|', '{', '(', 'then', 'do', 'else'}


def command_position(line, start):
    """True if the `rm` at `start` is at a position where the shell would run it."""
    prefix = line[:start]
    prev = prefix.rstrip()
    if not prev:
        return True
    if prev[-1] in ';&|{(' or (prev[-1] in '"\'' and 'trap ' in line):
        return True
    word = re.split(r'[\s;&|({]', prev)[-1]
    return word in ('then', 'do', 'else')


fails, sites = [], 0
for sh in sorted(list((root / 'tools').rglob('*.sh')) + list((root / 'scripts').rglob('*.sh'))):
    text = sh.read_text()
    lines = text.splitlines()
    mktemp_vars = {m.group(1) for m in MKTEMP.finditer(text)}
    has_trap = any('trap ' in l for l in lines)
    for i, line in enumerate(lines, 1):
        if line.strip().startswith('#'):
            continue
        body = line
        if 'trap ' in line and RM.search(line):
            t = TRAP.search(line)
            body = t.group(2) if t else line
        m = RM.search(body)
        if not m:
            continue
        if not command_position(body, m.start()):
            continue
        rest = m.group(2).strip().split(';')[0].strip()
        if not rest:
            continue
        sites += 1
        for operand in rest.split():
            operand = operand.strip('"\';')
            if operand.startswith('$'):
                var = operand.lstrip('${').rstrip('}')
                if var in mktemp_vars and has_trap:
                    print(f'V6 OK   {sh.relative_to(root)}:{i} rm -rf ${var} (mktemp -d + trap)')
                else:
                    fails.append(f'{sh.relative_to(root)}:{i} rm -rf ${var} mas ${var} não vem de mktemp -d com trap')
            else:
                fails.append(f'{sh.relative_to(root)}:{i} rm -rf em caminho LITERAL: {operand}')
for f in fails:
    print(f'V6 FAIL {f}')
if fails:
    print(f'V6 FAIL {len(fails)} operação(ões) destrutiva(s) fora de mktemp/trap')
    sys.exit(1)
print(f'V6 PASS {sites} rm -rf executável(is), todos em diretórios criados por mktemp -d e removidos por trap')
PY
