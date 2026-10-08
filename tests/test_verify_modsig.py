#!/usr/bin/env python3
"""Unit tests for tools/verify_modsig.sh error paths (U3, item 51).

Run:  python3 -m unittest discover -s tests -p 'test_*.py'
Black-box through the script (mod_split python is embedded in bash):
unsigned/truncated modules must fail CLEANLY (ERRO + exit != 0, no Traceback).
Needs: openssl in PATH. No device, no network.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.join(os.path.dirname(__file__), '..')
SCRIPT = os.path.join(REPO, 'tools', 'verify_modsig.sh')


def make_cert(path):
    r = subprocess.run(
        ['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
         '-keyout', path + '.key', '-out', path + '.crt', '-days', '2',
         '-subj', '/CN=unittest-modsig/'],
        capture_output=True)
    assert r.returncode == 0, r.stderr.decode()[:200]
    with open(path + '.crt', 'rb') as f:
        der = f.read()
    # openssl req -out gives PEM; convert
    r = subprocess.run(['openssl', 'x509', '-in', path + '.crt', '-outform', 'DER'],
                       capture_output=True)
    assert r.returncode == 0
    return r.stdout


class TestModsigErrors(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix='vmtest.')
        self.addCleanup(shutil.rmtree, self.dir, True)
        der = make_cert(os.path.join(self.dir, 'c'))
        # fake Image: junk + DER cert + junk (carve_certs scans for 0x30 0x82)
        with open(os.path.join(self.dir, 'Image'), 'wb') as f:
            f.write(b'\0' * 1000 + der + b'\0' * 1000)
        self.img = os.path.join(self.dir, 'Image')

    def run_verify(self, ko):
        return subprocess.run(['bash', SCRIPT, self.img, ko],
                              capture_output=True, text=True, timeout=120)

    def test_unsigned_module_clean_error(self):
        ko = os.path.join(self.dir, 'plain.ko')
        with open(ko, 'wb') as f:
            f.write(b'\x7fELF' + b'\0' * 5000)
        r = self.run_verify(ko)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('ERRO', r.stderr)
        self.assertNotIn('Traceback', r.stderr)
        self.assertNotIn('Traceback', r.stdout)

    def test_truncated_signature_clean_error(self):
        ko = os.path.join(self.dir, 'trunc.ko')
        with open(ko, 'wb') as f:
            f.write(b'\x7fELF' + b'\0' * 5000)
            f.write(b'~Module signature appended~\n')
        r = self.run_verify(ko)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('ERRO', r.stderr)
        self.assertNotIn('Traceback', r.stderr + r.stdout)


if __name__ == '__main__':
    unittest.main()
