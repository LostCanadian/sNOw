"""Capture release art states and motion using real input and validated save fixtures.

Run visual_fixture.gd first and serve build/web on port 8000. Requires Playwright,
Chromium, plus Playwright's ffmpeg and system ffmpeg for optional --video. No production state setters.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path
from playwright.sync_api import sync_playwright


def run(url, video):
    output = Path('docs/images')
    fixture = json.loads(Path('test-results/visual-fixture.json').read_text())
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
        context = browser.new_context(viewport={'width': 540, 'height': 960}, device_scale_factor=1)
        page = context.new_page()
        page.on('dialog', lambda dialog: dialog.accept())
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        page.goto(url, wait_until='networkidle')
        page.wait_for_function("!document.getElementById('loading')", timeout=90000)
        page.evaluate('(data) => localStorage.setItem("snow.campaigns.v1", JSON.stringify(data))', fixture)
        page.reload(wait_until='networkidle')
        page.wait_for_function("!document.getElementById('loading')", timeout=90000)
        def click(x, y):
            page.mouse.click(x * 1.5, y * 1.5)
            page.wait_for_timeout(400)
        def capture(name):
            page.locator('canvas').screenshot(path=str(output / f'prototype-{name}.png'))
            print('Captured', name, flush=True)
        def exit_level():
            page.keyboard.press('Escape')
            page.wait_for_timeout(300)
            click(180, 387)
            click(180, 383)
        click(180, 323)
        capture('save-slots')
        click(180, 242)
        page.keyboard.press('Escape')
        page.wait_for_timeout(3700)
        capture('week-12')
        exit_level()
        click(180, 323)
        click(180, 322)
        page.keyboard.press('Escape')
        page.wait_for_timeout(4700)
        capture('boss')
        exit_level()
        click(180, 323)
        click(180, 402)
        page.wait_for_timeout(500)
        capture('workshop')
        click(180, 362)
        capture('workshop-detail')
        exit_level()
        page.evaluate("localStorage.removeItem('snow.campaigns.v1'); localStorage.removeItem('snow.campaigns.v1.backup')")
        page.reload(wait_until='networkidle')
        page.wait_for_function("!document.getElementById('loading')", timeout=90000)
        click(180, 323)
        click(180, 242)
        click(180, 342)
        page.wait_for_timeout(3700)
        capture('gameplay')
        exit_level()
        click(180, 377)
        for x, name in [(140, 'warning'), (227, 'winter'), (314, 'victory')]:
            click(x, 560)
            page.wait_for_timeout(700)
            capture(name)
        context.close()
        if video:
            context = browser.new_context(viewport={'width': 540, 'height': 960},
                record_video_dir='test-results/video', record_video_size={'width':540, 'height':960})
            started = time.monotonic()
            page = context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
            page.goto(url, wait_until='networkidle')
            page.wait_for_function("!document.getElementById('loading')", timeout=90000)
            click(180, 323)
            click(180, 242)
            click(180, 342)
            page.wait_for_timeout(3400)
            trim = time.monotonic() - started
            page.keyboard.down('Space')
            page.keyboard.down('a')
            page.wait_for_timeout(750)
            page.keyboard.up('a')
            page.keyboard.down('d')
            page.wait_for_timeout(1800)
            page.keyboard.up('d')
            page.keyboard.up('Space')
            page.wait_for_timeout(1000)
            page.keyboard.down('a')
            page.wait_for_timeout(1600)
            page.keyboard.up('a')
            page.keyboard.down('Space')
            page.wait_for_timeout(2500)
            page.keyboard.up('Space')
            page.wait_for_timeout(1500)
            movie = page.video
            context.close()
            Path('test-results/video/clip.json').write_text(json.dumps({'path':str(movie.path()), 'trim':trim}))
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', str(trim), '-i', str(movie.path()),
                '-t', '8.5', '-c:v', 'libx264', '-preset', 'medium', '-crf', '22', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', '-an', str(output / 'prototype-motion.mp4')], check=True)
            print('Recorded motion', movie.path(), 'trim', trim, flush=True)
        browser.close()
    if errors:
        raise RuntimeError(errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://localhost:8000/')
    parser.add_argument('--video', action='store_true')
    args = parser.parse_args()
    run(args.url, args.video)
