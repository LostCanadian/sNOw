#!/usr/bin/env python3
"""Download pinned Godot, export headlessly, and serve sNOw. Python 3.9+, stdlib only."""
import argparse
import functools
import hashlib
import http.server
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.request
import webbrowser
import zipfile

if sys.version_info < (3, 9):
    raise SystemExit("This launcher requires Python 3.9 or newer.")

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.snow-tools'
VERSION = (ROOT / '.godot-version').read_text().strip()
RELEASE = VERSION + '-stable'
BASE_URL = 'https://github.com/godotengine/godot-builds/releases/download/' + RELEASE
WEB = ROOT / 'build' / 'web'
WEB_TEMPLATES = ('web_nothreads_debug.zip', 'web_nothreads_release.zip',
                 'web_debug.zip', 'web_release.zip')


def engine_asset(system, machine):
    machine = machine.lower()
    if system == 'Darwin':
        suffix = 'macos.universal'
    elif system == 'Windows' and machine in ('amd64', 'x86_64'):
        suffix = 'win64.exe'
    elif system == 'Windows' and machine in ('arm64', 'aarch64'):
        suffix = 'windows_arm64.exe'
    elif system == 'Linux' and machine in ('amd64', 'x86_64'):
        suffix = 'linux.x86_64'
    elif system == 'Linux' and machine in ('arm64', 'aarch64'):
        suffix = 'linux.arm64'
    else:
        raise RuntimeError(f'Unsupported desktop: {system} {machine}. Use a 64-bit Windows, macOS or Linux machine.')
    return f'Godot_v{RELEASE}_{suffix}.zip'


def checksum(path):
    digest = hashlib.sha512()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(url, target, expected=None):
    """Verify cached archives and publish only complete, checksum-matching downloads."""
    if target.exists() and (expected is None or checksum(target) == expected):
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_name(target.name + '.part')
    try:
        request = urllib.request.Request(url, headers={'User-Agent': 'sNOw-local-launcher'})
        with urllib.request.urlopen(request, timeout=60) as response, partial.open('wb') as output:
            length = int(response.headers.get('Content-Length', '0'))
            size = f' ({length / 1024**2:.0f} MiB)' if length else ''
            print(f'Downloading {target.name}{size}', flush=True)
            written = 0
            reported = time.monotonic()
            digest = hashlib.sha512()
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
                digest.update(chunk)
                written += len(chunk)
                if time.monotonic() - reported >= 5:
                    print(f'  {written / 1024**2:.0f} MiB downloaded', flush=True)
                    reported = time.monotonic()
            if length and written != length:
                raise RuntimeError(f'Incomplete download: {target.name}. Rerun to retry.')
            if expected and digest.hexdigest() != expected:
                raise RuntimeError(f'Checksum mismatch: {target.name}. Rerun to retry.')
        partial.replace(target)
        return target
    finally:
        partial.unlink(missing_ok=True)


def extract_engine(archive, destination):
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            path = PurePosixPath(member.filename)
            mode = member.external_attr >> 16
            if path.is_absolute() or '..' in path.parts or '\\' in member.filename or stat.S_ISLNK(mode):
                raise RuntimeError(f'Unexpected path in Godot archive: {member.filename}')
            extracted = Path(bundle.extract(member, destination))
            if os.name != 'nt' and mode & 0o777:
                extracted.chmod(mode & 0o777)


def template_directory(system, env):
    if system == 'Darwin':
        # Godot on macOS uses Application Support rather than XDG paths.
        data = Path.home() / 'Library' / 'Application Support' / 'Godot'
    elif system == 'Windows':
        data = Path(env['APPDATA']) / 'Godot'
    else:
        data = Path(env['XDG_DATA_HOME']) / 'godot'
    return data / 'export_templates' / (VERSION + '.stable')


def install():
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / '.gdignore').touch()
    system = platform.system()
    asset = engine_asset(system, platform.machine())
    engine_dir = CACHE / RELEASE / asset.removesuffix('.zip')
    if system == 'Darwin':
        executable = engine_dir / 'Godot.app' / 'Contents' / 'MacOS' / 'Godot'
    elif system == 'Windows':
        executable = engine_dir / (asset.removesuffix('.exe.zip') + '_console.exe')
    else:
        executable = engine_dir / asset.removesuffix('.zip')
    env = os.environ.copy()
    if system == 'Windows':
        env['APPDATA'] = str(CACHE / 'appdata')
    elif system != 'Darwin':
        for name, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            env[name] = str(CACHE / folder)
    templates = template_directory(system, env)
    need_templates = not all((templates / name).is_file() for name in WEB_TEMPLATES)
    if not executable.is_file() or need_templates:
        downloads = CACHE / 'downloads' / RELEASE
        manifest = fetch(BASE_URL + '/SHA512-SUMS.txt', downloads / 'SHA512-SUMS.txt')
        hashes = {}
        for line in manifest.read_text().splitlines():
            digest, name = line.split(maxsplit=1)
            hashes[name.lstrip('*')] = digest
        if not executable.is_file():
            archive = fetch(BASE_URL + '/' + asset, downloads / asset, hashes[asset])
            extract_engine(archive, engine_dir)
        if need_templates:
            name = f'Godot_v{RELEASE}_export_templates.tpz'
            archive = fetch(BASE_URL + '/' + name, downloads / name, hashes[name])
            templates.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(archive) as bundle:
                for name in (*WEB_TEMPLATES, 'version.txt'):
                    target = templates / name
                    partial = target.with_name(name + '.part')
                    with bundle.open('templates/' + name) as source, partial.open('wb') as output:
                        shutil.copyfileobj(source, output)
                    partial.replace(target)
            print('Installed matching browser export templates.', flush=True)
    result = subprocess.run([str(executable), '--headless', '--version'], env=env,
                            check=True, capture_output=True, text=True)
    if not result.stdout.strip().startswith(VERSION + '.stable.'):
        raise RuntimeError(f'Unexpected Godot version: {result.stdout.strip()}')
    return executable, env


def build():
    executable, env = install()
    WEB.mkdir(parents=True, exist_ok=True)
    (WEB.parent / '.gdignore').touch()
    command = [str(executable), '--headless', '--path', str(ROOT)]
    print('Importing project without opening the editor…', flush=True)
    subprocess.run(command + ['--editor', '--import', '--quit'], env=env, check=True)
    print('Exporting browser release…', flush=True)
    subprocess.run(command + ['--export-release', 'Web', str(WEB / 'index.html')], env=env, check=True)


def serve(port, open_browser):
    required = ('index.html', 'index.js', 'index.wasm', 'index.pck')
    if not all((WEB / name).is_file() for name in required):
        raise RuntimeError('No complete browser export found. Run without --serve-only to build it first.')
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(WEB))
    with http.server.ThreadingHTTPServer(('127.0.0.1', port), handler) as server:
        url = f'http://localhost:{server.server_port}'
        print(f'\nOpen {url} in your browser. Press Ctrl+C here to stop.', flush=True)
        if open_browser:
            webbrowser.open(url)
        server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--build-only', action='store_true', help='Download/install/export, then exit.')
    mode.add_argument('--serve-only', action='store_true', help='Serve an existing export; skip Godot and downloads.')
    parser.add_argument('--port', type=int, default=8000, help='Local port (default: 8000).')
    parser.add_argument('--open', action='store_true', dest='open_browser', help='Also open your browser automatically.')
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error('--port must be between 0 and 65535')
    try:
        if not args.serve_only:
            build()
        if not args.build_only:
            serve(args.port, args.open_browser)
    except KeyboardInterrupt:
        print('\nStopped.', flush=True)
    except (OSError, RuntimeError, subprocess.CalledProcessError, zipfile.BadZipFile, KeyError) as error:
        print(f'Error: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
