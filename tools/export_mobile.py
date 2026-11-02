#!/usr/bin/env python3
"""Export sNOw to Android APK/AAB or iOS Xcode/IPA without opening the Godot UI.
Python 3.9+, standard library only. See docs/MOBILE_EXPORT.md for SDK/signing setup.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import play_web as launcher

ROOT = launcher.ROOT
SOURCE_ENTRIES = ('assets', 'scripts', 'project.godot', 'main.tscn', 'export_presets.cfg')
ANDROID_TEMPLATES = ('android_debug.apk', 'android_release.apk')
BUILD_TOOLS = '35.0.1'
ANDROID_PLATFORM = 'android-35'
NDK = '28.1.13356709'
CMAKE = '3.10.2.4988404'
RELEASE_ENV = tuple('GODOT_ANDROID_KEYSTORE_RELEASE_' + part for part in ('PATH', 'USER', 'PASSWORD'))


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=('android', 'ios'))
    parser.add_argument('--format', choices=('apk', 'aab', 'project', 'ipa'), help='Default: apk on Android, project on iOS.')
    parser.add_argument('--release', action='store_true', help='Release build. AAB/IPA always use release mode.')
    parser.add_argument('--check', action='store_true', help='Check prerequisites offline; do not download or export.')
    parser.add_argument('--no-download', action='store_true', help='Use cached Godot/templates only.')
    parser.add_argument('--godot', help='Use an installed Godot 4.6.3 executable instead of the portable installer.')
    parser.add_argument('--templates-dir', type=Path, help='Folder containing matching native export templates.')
    parser.add_argument('--output', type=Path, help='APK/AAB file, or output directory for iOS. Defaults under build/.')
    parser.add_argument('--bundle-id', default='com.lostcanadian.snow', help='Android package / Apple bundle identifier.')
    parser.add_argument('--version', default='0.1.0', help='Three-part app version (default: 0.1.0).')
    parser.add_argument('--build-number', type=int, default=1, help='Positive version code / Apple build number.')
    parser.add_argument('--android-sdk', type=Path, help='SDK folder; otherwise ANDROID_HOME / ANDROID_SDK_ROOT or standard location.')
    parser.add_argument('--java-home', type=Path, help='JDK folder; otherwise JAVA_HOME or auto-detection.')
    parser.add_argument('--team-id', help='10-character Apple team ID; or SNOW_IOS_TEAM_ID.')
    parser.add_argument('--export-options', type=Path, help='Xcode ExportOptions.plist, required for --format ipa.')
    parser.add_argument('--install', action='store_true', help='Install the exported Android APK with adb -r.')
    parser.add_argument('--device', help='adb device serial, used with --install.')
    args = parser.parse_args(argv)
    args.format = args.format or ('apk' if args.target == 'android' else 'project')
    if args.format not in (('apk', 'aab') if args.target == 'android' else ('project', 'ipa')):
        parser.error('--format does not match the target platform')
    if args.install and (args.target != 'android' or args.format != 'apk'):
        parser.error('--install requires Android APK output')
    if args.device and not args.install:
        parser.error('--device requires --install')
    if args.target == 'android' and (args.team_id or args.export_options):
        parser.error('--team-id and --export-options are iOS options')
    args.team_id = (args.team_id or os.environ.get('SNOW_IOS_TEAM_ID', '')) if args.target == 'ios' else ''
    if args.target == 'ios' and (args.android_sdk or args.java_home):
        parser.error('--android-sdk and --java-home are Android options')
    segment = r'[A-Za-z][A-Za-z0-9_]*' if args.target == 'android' else r'[A-Za-z0-9][A-Za-z0-9-]*'
    if not re.fullmatch(segment + r'(\.' + segment + r')+', args.bundle_id):
        parser.error('--bundle-id must be a valid dotted package identifier')
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version) or args.build_number < 1:
        parser.error('--version must be three numbers; --build-number must be positive')
    args.release = args.release or args.format in ('aab', 'ipa')
    default = ROOT / 'build' / args.target
    args.output = (args.output or (default / f'sNOw-{"release" if args.release else "debug"}.{args.format}'
                                if args.target == 'android' else default)).expanduser().resolve()
    if args.target == 'android' and args.output.suffix.lower() != '.' + args.format:
        parser.error('--output extension must match --format')
    return args


def sdk_location(args, env, system):
    if args.android_sdk:
        return args.android_sdk.expanduser().resolve()
    for name in ('ANDROID_HOME', 'ANDROID_SDK_ROOT'):
        if env.get(name):
            return Path(env[name]).expanduser().resolve()
    if system == 'Darwin':
        return Path.home() / 'Library/Android/sdk'
    if system == 'Windows':
        return Path(env.get('LOCALAPPDATA', str(Path.home() / 'AppData/Local'))) / 'Android/Sdk'
    return Path.home() / 'Android/Sdk'


def jdk_location(args, env, system):
    value = args.java_home or env.get('JAVA_HOME')
    if value:
        return Path(value).expanduser().resolve()
    if system == 'Darwin':
        for command in (['/usr/libexec/java_home', '-v', '17'], ['/usr/libexec/java_home']):
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode == 0:
                return Path(result.stdout.strip())
    executable = shutil.which('java')
    if not executable:
        raise RuntimeError('JDK missing. Install OpenJDK 17 and set JAVA_HOME or --java-home.')
    return Path(executable).resolve().parent.parent


def preflight(args, env, system):
    """Validate SDK/signing before any engine downloads or project changes."""
    if args.target == 'ios':
        if system != 'Darwin':
            raise RuntimeError('iOS exports require macOS with full Xcode installed. Android exports are supported on this host.')
        if not re.fullmatch(r'[A-Z0-9]{10}', args.team_id):
            raise RuntimeError('Set --team-id to your 10-character Apple developer team ID, or use SNOW_IOS_TEAM_ID.')
        for command in (['xcodebuild', '-version'], ['xcrun', '--sdk', 'iphoneos', '--show-sdk-path']):
            try:
                subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
            except (OSError, subprocess.CalledProcessError) as error:
                raise RuntimeError('Full Xcode and its iOS SDK are required; select Xcode with xcode-select.') from error
        if args.format == 'ipa':
            if not args.export_options or not args.export_options.expanduser().is_file():
                raise RuntimeError('--format ipa requires --export-options /path/to/ExportOptions.plist and Apple signing credentials.')
            with args.export_options.expanduser().open('rb') as source:
                options = plistlib.load(source)
            if not isinstance(options, dict) or not isinstance(options.get('method'), str) or not options['method']:
                raise RuntimeError('ExportOptions.plist must contain an Xcode export method.')
        return {}
    sdk = sdk_location(args, env, system)
    if not sdk.is_dir():
        raise RuntimeError('Android SDK missing. Set ANDROID_HOME or --android-sdk. See docs/MOBILE_EXPORT.md for command-line SDK setup.')
    java = jdk_location(args, env, system)
    exe = '.exe' if system == 'Windows' else ''
    required = [sdk / ('platform-tools/adb' + exe), sdk / f'platforms/{ANDROID_PLATFORM}/android.jar',
                sdk / f'build-tools/{BUILD_TOOLS}/zipalign{exe}',
                sdk / f'build-tools/{BUILD_TOOLS}/apksigner{".bat" if system == "Windows" else ""}']
    required += [java / f'bin/java{exe}', java / f'bin/keytool{exe}']
    if args.format == 'aab':
        required += [sdk / f'ndk/{NDK}/source.properties', sdk / f'cmake/{CMAKE}/bin/cmake{exe}']
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise RuntimeError('Missing Android/JDK tools:\n  ' + '\n  '.join(missing) + '\nSee docs/MOBILE_EXPORT.md for the sdkmanager command.')
    result = subprocess.run([str(java / f'bin/java{exe}'), '-version'], capture_output=True, text=True, check=True, timeout=15)
    version = re.search(r'(?:version|openjdk)\s+"?(\d+)', result.stdout + result.stderr)
    if not version or int(version[1]) < 17:
        raise RuntimeError('Godot 4.6.3 requires JDK 17 or newer; OpenJDK 17 is recommended.')
    if args.release:
        missing_env = [name for name in RELEASE_ENV if not env.get(name)]
        if missing_env:
            raise RuntimeError('Release signing requires environment variables: ' + ', '.join(missing_env))
        if not Path(env[RELEASE_ENV[0]]).expanduser().is_file():
            raise RuntimeError('The release keystore file does not exist. Check GODOT_ANDROID_KEYSTORE_RELEASE_PATH.')
    return {'android_sdk': str(sdk), 'java_home': str(java)}


def template_names(args):
    if args.target == 'ios':
        return ('ios.zip',)
    return ANDROID_TEMPLATES + (('android_source.zip',) if args.format == 'aab' else ())


def isolated_environment():
    env = os.environ.copy()
    system = platform.system()
    if system == 'Windows':
        env['APPDATA'] = str(launcher.CACHE / 'appdata')
    elif system != 'Darwin':
        for name, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            env[name] = str(launcher.CACHE / folder)
    return env


def runtime(args):
    names = template_names(args)
    if not args.godot:
        executable, env = launcher.install(() if args.templates_dir else names, download=not (args.check or args.no_download))
    else:
        executable = shutil.which(args.godot) or str(Path(args.godot).expanduser().resolve())
        env = isolated_environment()
        result = subprocess.run([str(executable), '--headless', '--version'], env=env, check=True, capture_output=True, text=True)
        if not result.stdout.strip().startswith(launcher.VERSION + '.stable.'):
            raise RuntimeError('Use Godot ' + launcher.VERSION + ' stable and matching templates.')
    templates = args.templates_dir.expanduser().resolve() if args.templates_dir else launcher.template_directory(platform.system(), env)
    missing = [name for name in names if not (templates / name).is_file()]
    if missing:
        raise RuntimeError('Missing native templates: ' + ', '.join(missing) + '. Use --templates-dir or run the portable installer without --godot.')
    return str(executable), env, templates


def configuration(args, tools, templates):
    section = 'preset.1' if args.target == 'android' else 'preset.2'
    options = {'custom_template/debug': str(templates / ('android_debug.apk' if args.target == 'android' else 'ios.zip')),
               'custom_template/release': str(templates / ('android_release.apk' if args.target == 'android' else 'ios.zip'))}
    if args.target == 'android':
        options.update({'package/unique_name': args.bundle_id, 'version/name': args.version,
                        'version/code': args.build_number, 'gradle_build/use_gradle_build': args.format == 'aab',
                        'gradle_build/export_format': 1 if args.format == 'aab' else 0})
        if args.format == 'aab':
            options['gradle_build/android_source_template'] = str(templates / 'android_source.zip')
    else:
        options.update({'application/app_store_team_id': args.team_id, 'application/bundle_identifier': args.bundle_id,
                        'application/short_version': args.version, 'application/version': str(args.build_number),
                        'application/export_project_only': True})
    return {'section': section, 'options': options, **tools}


def stage_project(destination, config):
    """Build from a temporary source copy; never rewrite the checkout's presets."""
    for name in SOURCE_ENTRIES:
        source = ROOT / name
        if source.is_dir():
            shutil.copytree(source, destination / name)
        else:
            shutil.copy2(source, destination / name)
    shutil.copy2(ROOT / 'tools/mobile_setup.gd', destination / 'mobile_setup.gd')
    (destination / 'mobile_config.json').write_text(json.dumps(config), encoding='utf-8')


def ios_package(args, project, env):
    archive = args.output / 'sNOw.xcarchive'
    subprocess.run(['xcodebuild', '-project', str(project), '-scheme', 'sNOw', '-configuration', 'Release',
                    '-sdk', 'iphoneos', '-destination', 'generic/platform=iOS', '-archivePath', str(archive),
                    '-allowProvisioningUpdates', 'archive'], env=env, check=True)
    destination = args.output / 'ipa'
    subprocess.run(['xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportPath', str(destination),
                    '-exportOptionsPlist', str(args.export_options.expanduser().resolve()),
                    '-allowProvisioningUpdates'], env=env, check=True)
    packages = list(destination.glob('*.ipa'))
    if not packages:
        raise RuntimeError('Xcode did not produce an IPA. Check its signing/export log.')
    return packages[0]


def publish_package(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.' + destination.name, suffix='.tmp', delete=False) as output:
            temporary = Path(output.name)
            with source.open('rb') as data:
                shutil.copyfileobj(data, output)
        temporary.replace(destination)
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


def export(args, executable, env, templates, tools):
    build_root = ROOT / 'build'
    build_root.mkdir(exist_ok=True)
    (build_root / '.gdignore').touch()
    env = env.copy()
    if tools:
        env['JAVA_HOME'] = tools['java_home']
        env['ANDROID_HOME'] = tools['android_sdk']
    if env.get(RELEASE_ENV[0]):
        env[RELEASE_ENV[0]] = str(Path(env[RELEASE_ENV[0]]).expanduser().resolve())
    with tempfile.TemporaryDirectory(prefix='mobile-', dir=build_root) as folder:
        staged = Path(folder)
        stage_project(staged, configuration(args, tools, templates))
        command = [executable, '--headless', '--path', str(staged)]
        subprocess.run(command + ['--editor', '--script', 'res://mobile_setup.gd'], env=env, check=True, timeout=120)
        subprocess.run(command + ['--editor', '--import', '--quit'], env=env, check=True)
        mode = '--export-release' if args.release else '--export-debug'
        if args.target == 'android':
            temporary = staged / ('sNOw.' + args.format)
            extra = ['--install-android-build-template'] if args.format == 'aab' else []
            subprocess.run(command + extra + [mode, 'Android', str(temporary)], env=env, check=True)
            manifest = 'AndroidManifest.xml' if args.format == 'apk' else 'base/manifest/AndroidManifest.xml'
            if not temporary.is_file() or not zipfile.is_zipfile(temporary):
                raise RuntimeError('Godot did not produce a valid Android package.')
            with zipfile.ZipFile(temporary) as archive:
                if manifest not in archive.namelist():
                    raise RuntimeError('Android package is missing its manifest.')
            publish_package(temporary, args.output)
            artifact = args.output
        else:
            args.output.mkdir(parents=True, exist_ok=True)
            subprocess.run(command + [mode, 'iOS', str(args.output / 'sNOw.ipa')], env=env, check=True)
            artifact = args.output / 'sNOw.xcodeproj'
            if not (artifact / 'project.pbxproj').is_file():
                raise RuntimeError('Godot did not produce an Xcode project.')
            if args.format == 'ipa':
                artifact = ios_package(args, artifact, env)
    print('Exported: ' + str(artifact), flush=True)
    if args.install:
        adb = Path(tools['android_sdk']) / ('platform-tools/adb.exe' if os.name == 'nt' else 'platform-tools/adb')
        subprocess.run([str(adb)] + (['-s', args.device] if args.device else []) + ['install', '-r', str(artifact)], env=env, check=True)
    return artifact


def main(argv=None):
    args = arguments(argv)
    try:
        tools = preflight(args, os.environ, platform.system())
        executable, env, templates = runtime(args)
        if args.check:
            print('Ready: ' + args.target + ' ' + args.format + '. No files exported or downloaded.')
        else:
            export(args, executable, env, templates, tools)
    except KeyboardInterrupt:
        print('\nExport cancelled.', file=sys.stderr)
        return 130
    except (OSError, RuntimeError, subprocess.SubprocessError, zipfile.BadZipFile, plistlib.InvalidFileException, KeyError) as error:
        print('Error: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
