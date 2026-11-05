"""Real browser regression for the speaker-only main menu and audio panel."""
from pathlib import Path
from playwright.sync_api import sync_playwright

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
    page = browser.new_page(viewport={'width':360, 'height':640})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
    page.goto('http://localhost:8000/test/?test=1', wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode==='title'", timeout=90000)
    def click(x,y):
        page.mouse.click(x,y,delay=80)
        page.wait_for_timeout(500)
    def mode(value):
        page.wait_for_function('value=>snowSnapshot.mode===value',arg=value)
    buttons=page.evaluate('snowSnapshot.ui_buttons')
    assert any(b['name']=='AudioSettings' and b['text']=='' for b in buttons)
    assert not any(b['text'] in ('Soft effects','Mute','Audio') for b in buttons)
    Path('test-results').mkdir(exist_ok=True)
    page.screenshot(path='test-results/menu-speaker.png')
    click(180,521);mode('audio_options')
    click(180,390);page.wait_for_function('snowSnapshot.audio_muted')
    click(180,390);page.wait_for_function('!snowSnapshot.audio_muted')
    click(120,279);click(220,357)
    preferences=page.evaluate("JSON.parse(localStorage.getItem('snow.audio.v1'))")
    assert 0 < preferences['music_volume'] < 0.55 and 0.5 < preferences['effects_volume'] <= 1
    page.screenshot(path='test-results/menu-audio-panel.png')
    click(180,427);mode('title')
    page.reload(wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode==='title'",timeout=90000)
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.audio.v1'))")==preferences
    browser.close()
assert not errors,errors
print('PASS: speaker-only main menu, audio-panel mute/volume and preference reload; no browser errors.')
