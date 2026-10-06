#!/usr/bin/env python3
"""Dump (crc, symbol) pairs from the __versions section of kernel modules (.ko, ELF64 LE). Read-only.
usage: dump_modcrcs.py <dir-or-ko>... > pairs.tsv   (columns: symbol \t 0xcrc \t module)"""
import struct, sys, os
def versions(path):
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF': return []
    shoff, = struct.unpack_from('<Q', d, 0x28); shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3A)
    secs = []
    for i in range(shnum):
        o = shoff + i*shentsize
        name, typ, flags, addr, off, size = struct.unpack_from('<IIQQQQ', d, o)
        secs.append((name, off, size))
    stroff = secs[shstrndx][1]
    out = []
    for name, off, size in secs:
        n = d[stroff+name:d.index(b'\0', stroff+name)]
        if n == b'__versions':
            for p in range(off, off+size, 64):
                crc, = struct.unpack_from('<Q', d, p); s = d[p+8:p+64].split(b'\0')[0].decode()
                if s: out.append((s, crc & 0xffffffff))
    return out
files = []
for a in sys.argv[1:]:
    if os.path.isdir(a):
        for r, _, fs in os.walk(a): files += [os.path.join(r, f) for f in fs if f.endswith('.ko')]
    else: files.append(a)
for f in sorted(files):
    for s, c in versions(f): print(f"{s}\t0x{c:08x}\t{os.path.basename(f)}")
