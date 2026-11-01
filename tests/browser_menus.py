"""Exercise menu notices offline, keyboard/touch navigation and difficulty choice."""
from pathlib import Path
from playwright.sync_api import sync_playwright

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
    context = browser.new_context(viewport={'width':540, 'height':960}, has_touch=True)
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
    page.goto('http://localhost:8000/test/?test=1', wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
    def click(x, y):
        page.mouse.click(x * 1.5, y * 1.5)
    def mode(value):
        page.wait_for_function('mode => window.snowSnapshot.mode === mode', arg=value)
    def snap():
        return page.evaluate('window.snowSnapshot')
    assert page.title().startswith('sNOw') and 'Paper' not in page.title(), page.title()
    page.locator('canvas').screenshot(path='docs/images/prototype-menu.png')
    click(113, 427)
    mode('scores')
    assert snap()['score_rows'] == [0,0,0]
    for x in [78,180,282]:
        click(x,154)
        page.wait_for_timeout(250)
    click(180,554)
    mode('title')
    click(244,427)
    mode('license')
    context.set_offline(True)
    for index, title in enumerate(['About','Godot (MIT)','Engine libraries','DejaVu fonts']):
        click(104 if index % 2 == 0 else 256, 152 if index < 2 else 198)
        page.wait_for_timeout(250)
        try:
            page.wait_for_function('section => window.snowSnapshot.license_section === section', arg=title)
        except Exception:
            page.locator('canvas').screenshot(path='test-results/license-selection-failure.png')
            print('Selection failed:', title, snap(), errors, flush=True)
            raise
        assert snap()['license_characters'] > (1500 if index==3 else 500)
        if index == 1:
            page.locator('canvas').screenshot(path='docs/images/prototype-license.png')
        if index == 3:
            page.locator('canvas').screenshot(path='test-results/browser-font-license.png')
    page.keyboard.press('Escape')
    mode('paused')
    page.keyboard.press('Escape')
    mode('license')
    assert snap()['license_section'] == 'DejaVu fonts'
    context.set_offline(False)
    click(180,541)
    mode('title')
    print('PASS: all difficulty tabs and complete license sections work offline; pause retains the selected notice.',flush=True)
    # New-garden difficulty controls: real UI selection persisted in the campaign.
    for difficulty, slot_y, x, capacity in [(0,242,62,18),(2,322,246,10)]:
        click(180,323)
        mode('slots')
        click(180,slot_y)
        mode('name')
        click(x,235)
        page.wait_for_timeout(300)
        click(180,342)
        mode('play')
        assert snap()['difficulty']==difficulty and snap()['capacity']==capacity
        saved=page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1'))")
        assert saved['slots'][0 if difficulty==0 else 1]['checkpoint']['difficulty']==difficulty
        page.keyboard.press('Escape')
        mode('paused')
        click(180,387)
        page.wait_for_timeout(300)
        click(180,383)
        mode('title')
    print('PASS: Breezy/Gale selections start and save distinct difficulty profiles.',flush=True)
    browser.close()
assert not errors, errors
print('No browser errors.',flush=True)
