#!/usr/bin/env python3
"""Unit tests for tools/repack_boot_v2.py — items 54-62/48.

Run:  python3 -m unittest discover -s tests -p 'test_*.py'
Offline-safe: synthetic v4 images only; avbtool paths that need the binary
are covered via keep-footer (no avbtool) + unittest.mock for failure injection.
"""
import os
import struct
import sys
import tempfile
import unittest
import zlib
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'tools'))
import repack_boot_v2 as rb


def arm64_image(size=65536):
    img = bytearray(b'\0' * size)
    img[0x38:0x3C] = b'ARM\x64'  # Linux arm64 Image magic
    return bytes(img)


def gz(data):
    co = zlib.compressobj(9, zlib.DEFLATED, 31)
    return co.compress(data) + co.flush()


def make_stock(kernel_gz, with_sig=False):
    """Synthetic stock boot v4 image + footer. Returns full image bytes."""
    hdr = bytearray(4096)
    hdr[0:8] = b'ANDROID!'
    struct.pack_into('<I', hdr, 8, len(kernel_gz))
    struct.pack_into('<I', hdr, 12, 0)  # ramdisk_size = 0
    struct.pack_into('<I', hdr, 40, 4)  # version 4
    struct.pack_into('<I', hdr, 1580, 16384 if with_sig else 0)
    body = bytes(hdr) + kernel_gz
    body += b'\0' * ((4096 - len(body) % 4096) % 4096)
    gap = b'AVB0' + b'\0' * 100 if with_sig else b''
    vbmeta = b'AvB0' + b'\0' * 4096
    img_wo_footer = body + gap + vbmeta
    footer = bytearray(64)
    footer[0:4] = b'AVBf'
    struct.pack_into('>I', footer, 4, 1)  # version
    struct.pack_into('>Q', footer, 12, len(img_wo_footer) + 64)  # original_image_size
    struct.pack_into('>Q', footer, 20, len(body) + len(gap))  # vbmeta_off
    struct.pack_into('>Q', footer, 28, len(vbmeta))  # vbmeta_size
    return img_wo_footer + bytes(footer)


class TmpFiles(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix='rbtest.')
        self.addCleanup(__import__('shutil').rmtree, self.dir, True)

    def w(self, name, data):
        p = os.path.join(self.dir, name)
        with open(p, 'wb') as f:
            f.write(data)
        return p

    def run_main(self, *argv):
        old = sys.argv
        sys.argv = ['repack_boot_v2.py'] + list(argv)
        try:
            rb.main()
            return 0
        except SystemExit as e:
            return e.code if isinstance(e.code, int) else 1
        finally:
            sys.argv = old


class TestErrExitCode(TmpFiles):
    def test_err_preserves_code(self):
        with self.assertRaises(SystemExit) as cm:
            rb.err('boom', code=2)
        self.assertEqual(cm.exception.code, 2)

    def test_err_default_code_1_no_traceback(self):
        err = __import__('io').StringIO()
        old = sys.stderr
        sys.stderr = err
        try:
            with self.assertRaises(SystemExit):
                rb.err('boom')
        finally:
            sys.stderr = old
        self.assertIn('ERRO: boom', err.getvalue())
        self.assertNotIn('Traceback', err.getvalue())


class TestStockValidation(TmpFiles):
    def test_truncated_orig_clean_error(self):
        p = self.w('o.img', b'ANDROID!' + b'\0' * 100)
        k = self.w('k.gz', gz(arm64_image()))
        self.assertNotEqual(self.run_main(p, k, os.path.join(self.dir, 'o.bin')), 0)

    def test_bad_magic_clean_error(self):
        p = self.w('o.img', b'NOTANDROID' + b'\0' * 5000)
        k = self.w('k.gz', gz(arm64_image()))
        self.assertNotEqual(self.run_main(p, k, os.path.join(self.dir, 'o.bin')), 0)

    def test_new_kernel_not_gzip(self):
        p = self.w('o.img', make_stock(gz(arm64_image())))
        k = self.w('k.gz', b'plain-text-not-gzip')
        self.assertNotEqual(self.run_main(p, k, os.path.join(self.dir, 'o.bin')), 0)

    def test_new_kernel_not_arm64(self):
        p = self.w('o.img', make_stock(gz(arm64_image())))
        k = self.w('k.gz', gz(b'\0' * 70000))  # valid gzip, no ARMd magic
        self.assertNotEqual(self.run_main(p, k, os.path.join(self.dir, 'o.bin')), 0)

    def test_dash_prefixed_output_rejected(self):
        p = self.w('o.img', make_stock(gz(arm64_image())))
        k = self.w('k.gz', gz(arm64_image()))
        # argparse sees '-o.bin' as a flag -> clean usage error, never a stray write
        self.assertNotEqual(self.run_main(p, k, '-o.bin'), 0)

    def test_same_in_out_rejected(self):
        p = self.w('o.img', make_stock(gz(arm64_image())))
        k = self.w('k.gz', gz(arm64_image()))
        self.assertNotEqual(self.run_main(p, k, p), 0)


class TestKeepFooter(TmpFiles):
    def test_identical_kernel_roundtrips_without_avbtool(self):
        kgz = gz(arm64_image())
        p = self.w('o.img', make_stock(kgz))
        k = self.w('k.gz', kgz)
        out = os.path.join(self.dir, 'o.bin')
        # no --drop-signature needed (no sig block); avbtool never invoked
        self.assertEqual(self.run_main(p, k, out, '--keep-footer'), 0)
        with open(out, 'rb') as produced, open(p, 'rb') as stock:
            self.assertEqual(produced.read(), stock.read())

    def test_different_kernel_rejected(self):
        p = self.w('o.img', make_stock(gz(arm64_image())))
        k = self.w('k.gz', gz(arm64_image(70000)))
        out = os.path.join(self.dir, 'o.bin')
        self.assertNotEqual(self.run_main(p, k, out, '--keep-footer'), 0)
        self.assertFalse(os.path.exists(out))

    def test_info_image_failure_is_fatal(self):
        kgz = gz(arm64_image())
        p = self.w('o.img', make_stock(kgz))
        k = self.w('k.gz', kgz)
        out = os.path.join(self.dir, 'o.bin')
        real_run = rb.subprocess.run

        def fake_run(cmd, **kw):
            if cmd[0] == 'avbtool' and 'info_image' in cmd:
                return mock.Mock(returncode=1, stdout='', stderr='bogus footer')
            return real_run(cmd, **kw)

        with mock.patch.object(rb.subprocess, 'run', side_effect=fake_run):
            self.assertNotEqual(self.run_main(p, k, out, '--force'), 0)


if __name__ == '__main__':
    unittest.main()
