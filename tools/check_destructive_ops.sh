#!/usr/bin/env bash
# check_destructive_ops.sh — V6 (invariant): destructive operations in
# tools/**.sh and scripts/**.sh must target directories the script itself created
# with `mktemp -d` and removes through a trap (or be absent entirely).
# Covered classes (item 26): `rm -rf/-f`, `dd of=`, `truncate`, `mkfs.*`,
# `fastboot flash|erase|format`, `set_active`, writes to /dev/block|sd*|mmc*|nvme*.
# A literal path (`rm -rf /tmp/opencode`) can delete a user's directory and is a
# hard FAIL — that is BUG B6. Line continuations (`\`) are joined before scanning.
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
DD_OF = re.compile(r'\bdd\s+(?:[^\s]+\s+)*of=([^\s]+)')
TRUNC = re.compile(r'\btruncate\s+(?:-[a-zA-Z]+\s+)*(?:-s\s*[^\s]+\s+)?([^\s]+)')
MKFS = re.compile(r'\bmks?(?:fs\.|wap-swap|fs\b)[a-z0-9.]*\b')
DEVWRITE = re.compile(r'(?:of=|>\s*>?\s*)(/dev/(?:block|sd[a-z]+|mmcblk\d+|nvme\d+n\d+)[^\s"\']*)')
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


def in_quotes(line, pos):
    """True if position sits inside single/double quotes (pattern string, not a command)."""
    seg = line[:pos]
    return seg.count("'") % 2 == 1 or seg.count('"') % 2 == 1


fails, sites = [], 0
for sh in sorted(list((root / 'tools').rglob('*.sh')) + list((root / 'scripts').rglob('*.sh'))):
    text = sh.read_text()
    # join backslash continuations so split commands are still visible
    text = re.sub(r'\\\n', ' ', text)
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
    # --- extended classes (item 26): same file, command-position + unquoted -----------------------
    for i, line in enumerate(lines, 1):
        if line.strip().startswith('#'):
            continue
        m = DD_OF.search(line)
        if m and command_position(line, m.start()) and not in_quotes(line, m.start()):
            tgt = m.group(1).strip('"\';')
            if tgt.startswith('$'):
                var = tgt.lstrip('${').rstrip('}')
                if var in mktemp_vars and has_trap:
                    print(f'V6 OK   {sh.relative_to(root)}:{i} dd of=${var} (mktemp -d + trap)')
                else:
                    fails.append(f'{sh.relative_to(root)}:{i} dd of=${var} mas ${var} não vem de mktemp -d com trap')
            else:
                fails.append(f'{sh.relative_to(root)}:{i} dd of=LITERAL: {tgt}')
        m = TRUNC.search(line)
        if m and command_position(line, m.start()) and not in_quotes(line, m.start()):
            tgt = m.group(1).strip('"\';')
            if tgt.startswith('$'):
                var = tgt.lstrip('${').rstrip('}')
                if not (var in mktemp_vars and has_trap):
                    fails.append(f'{sh.relative_to(root)}:{i} truncate em ${var} fora de mktemp/trap')
            elif tgt not in ('', '-'):
                fails.append(f'{sh.relative_to(root)}:{i} truncate em LITERAL: {tgt}')
        for pat, label in ((MKFS, 'mkfs*'),):
            m = pat.search(line)
            if m and command_position(line, m.start()) and not in_quotes(line, m.start()):
                fails.append(f'{sh.relative_to(root)}:{i} {label} em script host (nunca permitido)')
        # whole-command matches (line start or after a chain separator), unquoted.
        # (Keyword-mid-line matching under-reports: `fastboot set_active` starts at
        # `fastboot`, so test the command head, not the keyword.)
        m = re.search(r'(?:^|[;&|]\s*)fastboot\s+(flash|erase|format)\b', line)
        if m and not in_quotes(line, m.start()):
            fails.append(f'{sh.relative_to(root)}:{i} fastboot {m.group(1)} em script host (só o guard executa flash)')
        m = re.search(r'(?:^|[;&|]\s*)(?:\S+\s+)?set_active\b', line)
        if m and not in_quotes(line, m.start()):
            fails.append(f'{sh.relative_to(root)}:{i} set_active em script host (troca de slot proibida)')
        m = re.search(r'(?:^|[;&|]\s*)\S*--set-active\b', line)
        if m and not in_quotes(line, m.start()):
            fails.append(f'{sh.relative_to(root)}:{i} --set-active em script host (troca de slot proibida)')
        m = DEVWRITE.search(line)
        if m and not in_quotes(line, m.start()):
            fails.append(f'{sh.relative_to(root)}:{i} escrita em dispositivo: {m.group(1)}')
for f in fails:
    print(f'V6 FAIL {f}')
if fails:
    print(f'V6 FAIL {len(fails)} operação(ões) destrutiva(s) fora de mktemp/trap')
    sys.exit(1)
print(f'V6 PASS {sites} rm -rf executável(is), todos em diretórios criados por mktemp -d e removidos por trap')
PY
