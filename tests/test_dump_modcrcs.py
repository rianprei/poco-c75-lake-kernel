#!/usr/bin/env python3
"""Unit tests for tools/dump_modcrcs.py — malformed-ELF handling (item 47/48).

Run:  python3 -m unittest discover -s tests -p 'test_*.py'
No device, no network, no binaries published: every fixture is synthetic.
"""
import io
import os
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'tools'))
import dump_modcrcs as dm


def make_elf(sections, shstrndx=0, cls=2, shoff=None, shnum=None):
    """Build a minimal ELF64-LE image.

    sections: list of (name_bytes, content_bytes). Section 0 should be the
    null section; shstrndx points at the strtab section index.
    """
    hdr = bytearray(0x40)
    hdr[0:4] = b'\x7fELF'
    hdr[4] = cls
    hdr[5] = 1  # LE
    data_off = 0x200
    img = bytes(hdr) + b'\0' * (data_off - 0x40)
    offs = []
    # the strtab section content is derived from the names (callers pass b'');
    # a hand-passed blob would desync name offsets from file bytes.
    fixed = [(n, (None if n == b'.shstrtab' else c)) for n, c in sections]
    strtab = b'\0'
    name_offs = []
    for name, _c in fixed:
        name_offs.append(len(strtab))
        strtab += name + b'\0'
    for _name, content in fixed:
        offs.append(len(img))
        img += strtab if content is None else bytes(content)
    shoff_v = len(img) if shoff is None else shoff
    shnum_v = len(fixed) if shnum is None else shnum
    for idx, (noff, coff, (_name, content)) in enumerate(zip(name_offs, offs, fixed)):
        size = len(strtab) if content is None else len(content)
        img += struct.pack('<IIQQQQIIQQ', noff, 1, 0, 0, coff, size, 0, 0, 1, 0)
    img = bytearray(img)
    struct.pack_into('<Q', img, 0x28, shoff_v)
    struct.pack_into('<HHH', img, 0x3A, 64, shnum_v, shstrndx)
    return bytes(img)


def ver_blob(sym, crc):
    return struct.pack('<Q', crc) + sym + b'\0' * (56 - len(sym))


class TmpKo:
    def __init__(self, test, data, suffix='.ko'):
        self.dir = tempfile.mkdtemp(prefix='dmtest.')
        test.addCleanup(__import__('shutil').rmtree, self.dir, True)
        self.path = os.path.join(self.dir, 'm' + suffix)
        with open(self.path, 'wb') as f:
            f.write(data)


class TestSections(unittest.TestCase):
    def test_valid_versions(self):
        secs = [(b'', b''), (b'__versions', ver_blob(b'printk', 0x1234)),
                (b'.shstrtab', b'\0__versions\0.shstrtab\0')]
        d = make_elf(secs, shstrndx=2)
        names = [n for n, _o, _s in dm._sections(d)]
        self.assertIn(b'__versions', names)

    def test_invalid_magic(self):
        with self.assertRaises(dm._ELFError):
            dm._sections(b'NOTELF' + b'\0' * 100)

    def test_truncated_header(self):
        with self.assertRaises(dm._ELFError):
            dm._sections(b'\x7fELF\x02' + b'\0' * 10)

    def test_shstrndx_out_of_range(self):
        secs = [(b'', b''), (b'.shstrtab', b'\0.shstrtab\0')]
        d = make_elf(secs, shstrndx=9)
        with self.assertRaises(dm._ELFError):
            dm._sections(d)

    def test_section_out_of_range(self):
        secs = [(b'', b''), (b'__versions', ver_blob(b'x', 1)),
                (b'.shstrtab', b'\0__versions\0.shstrtab\0')]
        d = bytearray(make_elf(secs, shstrndx=2))
        # corrupt section 1 (offset/size) to point past EOF
        shoff, = struct.unpack_from('<Q', d, 0x28)
        struct.pack_into('<QQ', d, shoff + 64 + 32, 0xFFFFFF, 0xFFFFFF)
        with self.assertRaises(dm._ELFError):
            dm._sections(bytes(d))


class TestMain(unittest.TestCase):
    def test_truncated_file_strict_fails(self):
        t = TmpKo(self, b'\x7fELF\x02' + b'\0' * 20)
        self.assertNotEqual(dm.main([t.path]), 0)

    def test_invalid_elf_strict_fails(self):
        t = TmpKo(self, b'garbage' * 20)
        self.assertNotEqual(dm.main([t.path]), 0)

    def test_invalid_elf_permissive_warns_only(self):
        t = TmpKo(self, b'garbage' * 20)
        err = io.StringIO()
        old = sys.stderr
        sys.stderr = err
        try:
            rc = dm.main(['--permissive', t.path])
        finally:
            sys.stderr = old
        self.assertEqual(rc, 0)
        self.assertIn('AVISO', err.getvalue())

    def test_module_without_versions_warns(self):
        secs = [(b'', b''), (b'.modinfo', b'vermagic=abc\0'),
                (b'.shstrtab', b'\0.modinfo\0.shstrtab\0')]
        t = TmpKo(self, make_elf(secs, shstrndx=2))
        err = io.StringIO()
        old = sys.stderr
        sys.stderr = err
        try:
            rc = dm.main([t.path])
        finally:
            sys.stderr = old
        self.assertEqual(rc, 0)
        self.assertIn('no __versions', err.getvalue())

    def test_slot_prefix_collision(self):
        self.assertEqual(dm.module_id('vb_a_r00__foo.ko', False), 'foo.ko')
        self.assertEqual(dm.module_id('vb_b_r12__foo.ko', False), 'foo.ko')
        self.assertEqual(dm.module_id('vb_a_r00__foo.ko', True), 'vb_a_r00__foo.ko')

    def test_same_basename_divergent_crc(self):
        secs1 = [(b'', b''), (b'__versions', ver_blob(b'sym', 0xAAAA)),
                 (b'.shstrtab', b'\0__versions\0.shstrtab\0')]
        secs2 = [(b'', b''), (b'__versions', ver_blob(b'sym', 0xBBBB)),
                 (b'.shstrtab', b'\0__versions\0.shstrtab\0')]
        t1 = TmpKo(self, make_elf(secs1, shstrndx=2), suffix='1.ko')
        t2 = TmpKo(self, make_elf(secs2, shstrndx=2), suffix='2.ko')
        out = io.StringIO()
        old = sys.stdout
        sys.stdout = out
        try:
            rc = dm.main([t1.path, t2.path])
        finally:
            sys.stdout = old
        self.assertEqual(rc, 0)
        rows = out.getvalue().strip().splitlines()
        # same symbol, two CRCs, distinct module basenames: both rows survive
        self.assertEqual(len(rows), 2)
        self.assertNotEqual(rows[0].split('\t')[1], rows[1].split('\t')[1])


if __name__ == '__main__':
    unittest.main()
