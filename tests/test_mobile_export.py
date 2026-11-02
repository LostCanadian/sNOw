"""CLI, SDK/signing validation and export orchestration without downloads/devices."""
import contextlib
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import export_mobile as mobile


class MobileExportTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.base = Path(self.folder.name)
        self.env = patch.dict(os.environ, {}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def fake_sdk(self, bundle=False):
        sdk, jdk = self.base / 'sdk', self.base / 'jdk'
        paths = ['platform-tools/adb', f'platforms/{mobile.ANDROID_PLATFORM}/android.jar',
                 f'build-tools/{mobile.BUILD_TOOLS}/zipalign', f'build-tools/{mobile.BUILD_TOOLS}/apksigner']
        if bundle:
            paths += [f'ndk/{mobile.NDK}/source.properties', f'cmake/{mobile.CMAKE}/bin/cmake']
        for prefix, names in [(sdk, paths), (jdk, ['bin/java', 'bin/keytool'])]:
            for name in names:
                target = prefix / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.touch()
        return sdk, jdk

    def args_android(self, *extra):
        sdk, jdk = self.fake_sdk('--format' in extra and 'aab' in extra)
        return mobile.arguments(['android', '--android-sdk', str(sdk), '--java-home', str(jdk), *extra])

    def fake_project(self):
        root = self.base / 'repo'
        root.mkdir()
        for name in mobile.SOURCE_ENTRIES:
            target = root / name
            if name in ('assets', 'scripts'):
                target.mkdir()
                (target / 'example').write_text('source')
            else:
                target.write_text('original presets' if name == 'export_presets.cfg' else 'source')
        (root / 'tools').mkdir()
        (root / 'tools/mobile_setup.gd').write_text('setup')
        return root

    def test_target_defaults_and_format_validation(self):
        android = mobile.arguments(['android'])
        self.assertEqual((android.format, android.release), ('apk', False))
        ios = mobile.arguments(['ios', '--team-id', 'ABCDE12345'])
        self.assertEqual(ios.format, 'project')
        self.assertTrue(mobile.arguments(['android', '--format', 'aab']).release)
        for argv in (['ios', '--format', 'apk'], ['android', '--format', 'aab', '--install'],
                     ['android', '--output', 'wrong.zip'], ['android', '--bundle-id', 'bad id'],
                     ['android', '--build-number', '0'], ['android', '--device', 'serial']):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                mobile.arguments(argv)
        os.environ['SNOW_IOS_TEAM_ID'] = 'ABCDE12345'
        self.assertEqual(mobile.arguments(['android']).team_id, '')

    def test_missing_sdk_check_does_not_download_or_create_outputs(self):
        with patch.object(mobile, 'runtime') as runtime, contextlib.redirect_stderr(io.StringIO()):
            code = mobile.main(['android', '--check', '--android-sdk', str(self.base / 'missing')])
        self.assertEqual(code, 1)
        runtime.assert_not_called()
        self.assertFalse((self.base / 'missing').exists())

    def test_android_preflight_and_missing_build_tool(self):
        args = self.args_android()
        java = subprocess.CompletedProcess([], 0, '', 'openjdk version "17.0.14"')
        with patch.object(mobile.subprocess, 'run', return_value=java):
            tools = mobile.preflight(args, {}, 'Linux')
        self.assertEqual(tools['android_sdk'], str(args.android_sdk))
        (args.android_sdk / f'build-tools/{mobile.BUILD_TOOLS}/zipalign').unlink()
        with self.assertRaisesRegex(RuntimeError, 'zipalign'):
            mobile.preflight(args, {}, 'Linux')

    def test_release_signing_uses_environment_not_staged_configuration(self):
        args = self.args_android('--release')
        java = subprocess.CompletedProcess([], 0, '', 'openjdk version "21.0.1"')
        with patch.object(mobile.subprocess, 'run', return_value=java):
            with self.assertRaisesRegex(RuntimeError, 'GODOT_ANDROID_KEYSTORE_RELEASE'):
                mobile.preflight(args, {}, 'Linux')
            keystore = self.base / 'private.jks'
            keystore.touch()
            env = dict(zip(mobile.RELEASE_ENV, [str(keystore), 'private-alias', 'PRIVATE_PASSWORD']))
            tools = mobile.preflight(args, env, 'Linux')
        config = mobile.configuration(args, tools, self.base / 'templates')
        serialized = json.dumps(config)
        self.assertNotIn('PRIVATE_PASSWORD', serialized)
        self.assertNotIn('private-alias', serialized)
        self.assertNotIn('private.jks', serialized)

    def test_aab_requires_source_template_and_gradle_mode(self):
        args = self.args_android('--format', 'aab')
        config = mobile.configuration(args, {}, self.base)
        self.assertTrue(config['options']['gradle_build/use_gradle_build'])
        self.assertEqual(config['options']['gradle_build/export_format'], 1)
        self.assertIn('android_source.zip', mobile.template_names(args))

    def test_ios_requires_mac_before_any_apple_tools_run(self):
        args = mobile.arguments(['ios', '--team-id', 'ABCDE12345'])
        with patch.object(mobile.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'macOS'):
                mobile.preflight(args, {}, 'Linux')
        run.assert_not_called()

    def test_ios_project_and_ipa_prerequisites(self):
        args = mobile.arguments(['ios', '--team-id', 'ABCDE12345'])
        with patch.object(mobile.subprocess, 'run'):
            self.assertEqual(mobile.preflight(args, {}, 'Darwin'), {})
            args.format = 'ipa'
            with self.assertRaisesRegex(RuntimeError, 'export-options'):
                mobile.preflight(args, {}, 'Darwin')
            args.export_options = self.base / 'ExportOptions.plist'
            args.export_options.write_bytes(plistlib.dumps({'method': 'debugging', 'teamID': 'ABCDE12345'}))
            self.assertEqual(mobile.preflight(args, {}, 'Darwin'), {})
        args.team_id = 'My Name'
        with self.assertRaisesRegex(RuntimeError, '10-character'):
            mobile.preflight(args, {}, 'Darwin')

    def test_staging_leaves_source_and_presets_intact(self):
        root = self.fake_project()
        destination = self.base / 'staged'
        destination.mkdir()
        config = mobile.configuration(mobile.arguments(['android']), {}, self.base)
        with patch.object(mobile, 'ROOT', root):
            mobile.stage_project(destination, config)
        (destination / 'export_presets.cfg').write_text('changed')
        self.assertEqual((root / 'export_presets.cfg').read_text(), 'original presets')
        self.assertTrue((destination / 'mobile_setup.gd').is_file())
        self.assertEqual(json.loads((destination / 'mobile_config.json').read_text()), config)
        self.assertFalse((destination / '.git').exists())

    def test_apk_pipeline_produces_verified_package_and_installs_only_when_requested(self):
        root = self.fake_project()
        args = mobile.arguments(['android', '--output', str(self.base / 'out.apk')])
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if '--export-debug' in command:
                with zipfile.ZipFile(command[-1], 'w') as archive:
                    archive.writestr('AndroidManifest.xml', '<manifest/>')
            return subprocess.CompletedProcess(command, 0)
        with patch.object(mobile, 'ROOT', root), patch.object(mobile.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()):
            result = mobile.export(args, 'godot', {}, self.base, {'android_sdk': '/sdk', 'java_home': '/jdk'})
        self.assertEqual(result, args.output)
        self.assertTrue(zipfile.is_zipfile(result))
        self.assertFalse(any('install' in call for call in calls))
        self.assertFalse(list((root / 'build').glob('mobile-*')))
        self.assertEqual((root / 'export_presets.cfg').read_text(), 'original presets')

    def test_export_failure_preserves_previous_artifact_and_removes_staging(self):
        root = self.fake_project()
        args = mobile.arguments(['android', '--output', str(self.base / 'out.apk')])
        args.output.write_bytes(b'previous apk')
        def run(command, **kwargs):
            if '--export-debug' in command:
                raise subprocess.CalledProcessError(1, command)
            return subprocess.CompletedProcess(command, 0)
        with patch.object(mobile, 'ROOT', root), patch.object(mobile.subprocess, 'run', side_effect=run):
            with self.assertRaises(subprocess.CalledProcessError):
                mobile.export(args, 'godot', {}, self.base, {})
        self.assertEqual(args.output.read_bytes(), b'previous apk')
        self.assertFalse(list((root / 'build').glob('mobile-*')))

    def test_ios_default_exports_project_without_claiming_ipa(self):
        root = self.fake_project()
        args = mobile.arguments(['ios', '--team-id', 'ABCDE12345', '--output', str(self.base / 'ios')])
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if '--export-debug' in command:
                project = args.output / 'sNOw.xcodeproj'
                project.mkdir()
                (project / 'project.pbxproj').write_text('project')
            return subprocess.CompletedProcess(command, 0)
        with patch.object(mobile, 'ROOT', root), patch.object(mobile.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()):
            artifact = mobile.export(args, 'godot', {}, self.base, {})
        self.assertEqual(artifact.suffix, '.xcodeproj')
        self.assertFalse(any(call[0] == 'xcodebuild' for call in calls))

    def test_ipa_uses_xcode_archive_and_explicit_export_options(self):
        args = mobile.arguments(['ios', '--team-id', 'ABCDE12345', '--format', 'ipa',
                                 '--output', str(self.base / 'ios'), '--export-options', str(self.base / 'Signing Options.plist')])
        project = args.output / 'sNOw.xcodeproj'
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if '-exportArchive' in command:
                package = args.output / 'ipa/sNOw.ipa'
                package.parent.mkdir(parents=True)
                package.touch()
            return subprocess.CompletedProcess(command, 0)
        with patch.object(mobile.subprocess, 'run', side_effect=run):
            result = mobile.ios_package(args, project, {})
        self.assertEqual(result.name, 'sNOw.ipa')
        self.assertIn('archive', calls[0])
        self.assertIn('iphoneos', calls[0])
        self.assertIn('-allowProvisioningUpdates', calls[0])
        self.assertEqual(calls[1][calls[1].index('-exportOptionsPlist')+1], str(args.export_options))

    def test_copy_failure_cannot_destroy_previous_package(self):
        previous, source = self.base / 'existing.apk', self.base / 'new.apk'
        previous.write_bytes(b'old valid package')
        source.write_bytes(b'new package')
        with patch.object(mobile.shutil, 'copyfileobj', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                mobile.publish_package(source, previous)
        self.assertEqual(previous.read_bytes(), b'old valid package')
        self.assertFalse(list(self.base.glob('.*.tmp')))

    def test_native_template_installer_extracts_only_requested_platform(self):
        cache = self.base / 'cache'
        name = mobile.launcher.engine_asset('Linux', 'x86_64')
        engine = cache / mobile.launcher.RELEASE / name.removesuffix('.zip') / name.removesuffix('.zip')
        engine.parent.mkdir(parents=True)
        engine.touch()
        archive = self.base / 'templates.tpz'
        with zipfile.ZipFile(archive, 'w') as bundle:
            for filename in (*mobile.ANDROID_TEMPLATES, 'web_debug.zip', 'version.txt'):
                bundle.writestr('templates/' + filename, filename)
        manifest = self.base / 'SHA512-SUMS.txt'
        template_asset = f'Godot_v{mobile.launcher.RELEASE}_export_templates.tpz'
        manifest.write_text('0' * 128 + ' ' + template_asset)
        def fetch(url, target, expected=None):
            return manifest if url.endswith('SHA512-SUMS.txt') else archive
        version = subprocess.CompletedProcess([], 0, mobile.launcher.VERSION + '.stable.official.test')
        with patch.object(mobile.launcher, 'CACHE', cache), patch.object(mobile.launcher.platform, 'system', return_value='Linux'), patch.object(mobile.launcher.platform, 'machine', return_value='x86_64'), patch.object(mobile.launcher, 'fetch', side_effect=fetch), patch.object(mobile.launcher.subprocess, 'run', return_value=version), contextlib.redirect_stdout(io.StringIO()):
            _, env = mobile.launcher.install(mobile.ANDROID_TEMPLATES)
        templates = mobile.launcher.template_directory('Linux', env)
        self.assertTrue((templates / 'android_debug.apk').exists())
        self.assertTrue((templates / 'android_release.apk').exists())
        self.assertFalse((templates / 'web_debug.zip').exists())

    def test_offline_template_check_never_downloads(self):
        with patch.object(mobile.launcher, 'CACHE', self.base / 'empty-cache'), patch.object(mobile.launcher, 'fetch') as fetch:
            with self.assertRaisesRegex(RuntimeError, 'not cached'):
                mobile.launcher.install(mobile.ANDROID_TEMPLATES, download=False)
        fetch.assert_not_called()
        self.assertFalse((self.base / 'empty-cache').exists())

    def test_check_passes_without_export_or_download(self):
        with patch.object(mobile, 'preflight', return_value={}), patch.object(mobile, 'runtime', return_value=('godot', {}, self.base)), patch.object(mobile, 'export') as export, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(mobile.main(['android', '--check']), 0)
        export.assert_not_called()


if __name__ == '__main__':
    unittest.main()
