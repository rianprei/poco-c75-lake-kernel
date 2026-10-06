#!/usr/bin/env python3
"""Dump (symbol, CRC) pairs from the __versions section of kernel modules (.ko, ELF64 LE). Read-only.

Regenerating the two published data files (see docs/KMI-GATES.md, "Regenerating the data"):

  MODS=<dir with the 557 .ko of the device>          # <MODS>/ramdisk/ (342 files) + <MODS>/vendor_dlkm/ (215)
  python3 tools/dump_modcrcs.py "$MODS/ramdisk" "$MODS/vendor_dlkm"             > tools/data/modules_required_crcs.tsv
  python3 tools/dump_modcrcs.py --inventory "$MODS/ramdisk" "$MODS/vendor_dlkm" > tools/data/modules_inventory.tsv

Modes:
  (default)     symbol<TAB>0xCRC<TAB>module_basename    sorted, deduplicated
  --inventory   module_basename<TAB>copies<TAB>vermagic sorted

Module identity: the device audit stores the vendor_boot ramdisk files as
`vb_<slot>_r<NN>__<name>.ko`, so the same module exists twice (slot a/b). The slot prefix is
stripped, which is why 557 files map to 370 distinct modules (172 ramdisk slots + 215 vendor_dlkm
names, 17 of which appear in both trees). Pass --keep-prefix to keep the raw file names.

The pure-python ELF parsing below is intentional: the tool must run on a bare host (no pyelftools)
and must never execute or load anything from the input.
"""
import os
import re
import struct
import sys

# vb_a_r00__foo.ko / vb_b_r12__foo.ko -> foo.ko  (audit-side ramdisk extraction prefix)
SLOT_PREFIX = re.compile(r'^vb_[a-z]+_r\d+__')
MAGIC = b'\x7fELF'


def _sections(d):
    """Return [(name, offset, size)] for every section, or None if not a valid ELF64."""
    if d[:4] != MAGIC or len(d) < 5 or d[4] != 2:  # 2 = ELFCLASS64
        return None
    shoff, = struct.unpack_from('<Q', d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
    if not shnum or shoff + shnum * shentsize > len(d):
        return None
    raw = []
    for i in range(shnum):
        o = shoff + i * shentsize
        name, _typ, _flags, _addr, off, size = struct.unpack_from('<IIQQQQ', d, o)
        raw.append((name, off, size))
    stroff = raw[shstrndx][1]
    out = []
    for name, off, size in raw:
        end = d.find(b'\0', stroff + name)
        if end < 0:
            continue
        out.append((d[stroff + name:end], off, size))
    return out


def versions(path):
    """(symbol, crc) pairs imported by the module (__versions entries are 64 B each)."""
    d = open(path, 'rb').read()
    secs = _sections(d)
    if secs is None:
        return []
    out = []
    for name, off, size in secs:
        if name != b'__versions':
            continue
        for p in range(off, off + size - 63, 64):
            crc, = struct.unpack_from('<Q', d, p)
            sym = d[p + 8:p + 64].split(b'\0')[0]
            if sym:
                out.append((sym.decode('utf-8', 'replace'), crc & 0xffffffff))
    return out


def vermagic(path):
    """vermagic string from the .modinfo section, or '' if absent."""
    d = open(path, 'rb').read()
    secs = _sections(d)
    if secs is None:
        return ''
    for name, off, size in secs:
        if name != b'.modinfo':
            continue
        for line in d[off:off + size].split(b'\0'):
            if line.startswith(b'vermagic='):
                return line.split(b'=', 1)[1].decode('utf-8', 'replace').strip()
    return ''


def collect(args):
    files = []
    for a in args:
        if os.path.isdir(a):
            for root, _dirs, names in os.walk(a):
                files += [os.path.join(root, f) for f in names if f.endswith('.ko')]
        else:
            files.append(a)
    return sorted(files)


def module_id(path, keep_prefix):
    base = os.path.basename(path)
    return base if keep_prefix else SLOT_PREFIX.sub('', base)


def main(argv):
    inventory = False
    keep_prefix = False
    args = []
    for a in argv:
        if a == '--inventory':
            inventory = True
        elif a == '--keep-prefix':
            keep_prefix = True
        elif a in ('-h', '--help'):
            print(__doc__.strip())
            return 0
        else:
            args.append(a)
    if not args:
        print('usage: dump_modcrcs.py [--inventory] [--keep-prefix] <dir-or-ko>...', file=sys.stderr)
        return 2
    files = collect(args)
    if not files:
        print('no .ko files found in: %s' % ' '.join(args), file=sys.stderr)
        return 2

    if inventory:
        mods = {}
        for f in files:
            m = module_id(f, keep_prefix)
            copies, vm = mods.get(m, (0, set()))
            vm = set(vm)
            vm.add(vermagic(f))
            mods[m] = (copies + 1, vm)
        for m in sorted(mods):
            copies, vm = mods[m]
            print('%s\t%d\t%s' % (m, copies, '|'.join(sorted(v for v in vm if v))))
    else:
        rows = set()
        for f in files:
            m = module_id(f, keep_prefix)
            for sym, crc in versions(f):
                rows.add((sym, '0x%08x' % crc, m))
        for sym, crc, m in sorted(rows):
            print('%s\t%s\t%s' % (sym, crc, m))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
