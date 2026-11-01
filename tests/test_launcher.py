"""Launcher failure-path checks; no downloads or Godot installation required."""
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('play_web', Path(__file__).resolve().parents[1] / 'tools/play_web.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class Response(io.BytesIO):
    headers = {'Content-Length': '5'}


class LauncherTests(unittest.TestCase):
    def test_supported_architectures(self):
        cases = [('Windows', 'AMD64', 'win64.exe'), ('Windows', 'ARM64', 'windows_arm64.exe'),
                 ('Darwin', 'arm64', 'macos.universal'), ('Darwin', 'x86_64', 'macos.universal'),
                 ('Linux', 'x86_64', 'linux.x86_64'), ('Linux', 'aarch64', 'linux.arm64')]
        for system, arch, suffix in cases:
            with self.subTest(system=system, arch=arch):
                self.assertTrue(launcher.engine_asset(system, arch).endswith(suffix + '.zip'))
        with self.assertRaisesRegex(RuntimeError, 'Unsupported desktop'):
            launcher.engine_asset('Linux', 'mips')

    def test_bad_download_never_replaces_existing_file(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'engine.zip'
            target.write_bytes(b'existing')
            with patch.object(launcher.urllib.request, 'urlopen', return_value=Response(b'wrong')):
                with self.assertRaisesRegex(RuntimeError, 'Checksum mismatch'):
                    launcher.fetch('https://example.invalid/engine.zip', target, '0' * 128)
            self.assertEqual(target.read_bytes(), b'existing')
            self.assertFalse(target.with_suffix('.zip.part').exists())

    def test_verified_cached_download_needs_no_network(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'engine.zip'
            target.write_bytes(b'cached')
            with patch.object(launcher.urllib.request, 'urlopen', side_effect=AssertionError('unexpected network')):
                self.assertEqual(launcher.fetch('https://example.invalid/', target, launcher.checksum(target)), target)

    def test_archive_cannot_escape_install_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / 'malformed.zip'
            with zipfile.ZipFile(archive, 'w') as bundle:
                bundle.writestr('../escaped', 'bad')
            with self.assertRaisesRegex(RuntimeError, 'Unexpected path'):
                launcher.extract_engine(archive, root / 'install')
            self.assertFalse((root / 'escaped').exists())

    def test_incomplete_download_is_not_cached(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'engine.zip'
            with patch.object(launcher.urllib.request, 'urlopen', return_value=Response(b'no')):
                with self.assertRaisesRegex(RuntimeError, 'Incomplete download'):
                    launcher.fetch('https://example.invalid/', target)
            self.assertFalse(target.exists())
            self.assertFalse(target.with_suffix('.zip.part').exists())


if __name__ == '__main__':
    unittest.main()
