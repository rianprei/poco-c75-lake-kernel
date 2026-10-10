#!/usr/bin/env bash
# dmesg_new_errors.sh — T3 acceptance: print dmesg error lines that the stock boot did not log.
#
# usage: tools/dmesg_new_errors.sh <dmesg.txt>
# Exit 0 = no new line, 1 = at least one new line (printed on stdout), 2 = usage or missing input.
# Read-only. The stock set is data/stock_dmesg_known.txt (normalized lines; '#' comments ignored).
set -uo pipefail; export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
KNOWN="$ROOT/data/stock_dmesg_known.txt"
IN="${1:-}"
if [ -z "$IN" ] || [ ! -f "$IN" ]; then
  echo "usage: tools/dmesg_new_errors.sh <dmesg.txt>" >&2
  exit 2
fi
[ -s "$KNOWN" ] || { echo "error: missing stock dmesg set: $KNOWN" >&2; exit 2; }

python3 - "$IN" "$KNOWN" <<'PY'
import re, sys
src_path, known_path = sys.argv[1], sys.argv[2]
TS = re.compile(r'^\[[ \t]*[0-9.]+\](?: \[[^]]*\])? ')
OLD = re.compile(
    r'Unknown symbol|disagrees about version|exports protected symbol|'
    r'Invalid module format|kCFI|Kernel panic', re.I)
WARN = re.compile(r'WARNING:')
BUG = re.compile(r'(?<![A-Za-z])BUG:')
OOPS = re.compile(r'(?<![A-Za-z])Oops(?![A-Za-z])')
TRACE = re.compile(r'Call trace:')
FRAME = re.compile(r'\S+\+0x[0-9a-fA-F]+/0x[0-9a-fA-F]+')
REG = re.compile(r'(?:x[0-9]+|pc|lr|sp)\s*:')

def payload(line):
    return TS.sub('', line, count=1)

def is_modlist(s):
    if s.startswith('Modules linked in'):
        return True
    toks = s.split()
    if len(toks) < 2:
        return False
    for t in toks:
        t = re.sub(r'\([A-Za-z+]+\)$', '', t)
        if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.+-]*', t):
            return False
    return True

def is_meta(p):
    s = p.strip()
    if not s:
        return True
    if s.startswith('#'):
        return True
    if s.startswith('Call trace:'):
        return True
    if s.startswith('---[ cut here') or s.startswith('---[ end trace'):
        return True
    if s.startswith('CPU:') or s.startswith('Hardware name:') or s.startswith('Workqueue:'):
        return True
    if is_modlist(s):
        return True
    if s.startswith('pstate:'):
        return True
    if REG.match(s):
        return True
    if FRAME.match(s):
        return True
    return False

def norm(p):
    s = re.sub(r'\bCPU:\s*\d+\s+PID:\s*\d+\b', '', p)
    s = re.sub(r'\+0x[0-9a-fA-F]+/0x[0-9a-fA-F]+', '', s)
    s = re.sub(r'0x[0-9a-fA-F]{8,}', '0x', s)
    s = re.sub(r'[ \t]+', ' ', s).strip()
    return s

def is_class(p):
    return bool(OLD.search(p) or WARN.search(p) or BUG.search(p) or OOPS.search(p))

def signatures(lines):
    found = set()
    for i, line in enumerate(lines):
        p = payload(line)
        if p.lstrip().startswith('#'):
            continue
        if TRACE.search(p):
            j = i - 1
            while j >= 0:
                q = payload(lines[j])
                if not is_meta(q):
                    n = norm(q)
                    if n:
                        found.add(n)
                    break
                j -= 1
        elif is_class(p):
            n = norm(p)
            if n:
                found.add(n)
    return found

def known_set(text):
    out = set()
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        out.add(s)
    return out

lines = open(src_path, errors='replace').read().splitlines()
known = known_set(open(known_path, errors='replace').read())
new = sorted(signatures(lines) - known)
for n in new:
    print(n)
sys.exit(1 if new else 0)
PY
