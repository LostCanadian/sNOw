"""Exercise results, initials, upgrades and reload using real browser input.

The validated week-nine summary is a UI fixture, not a played campaign win.
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
    context = browser.new_context(viewport={'width': 540, 'height': 960}, has_touch=True)
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
    page.goto('http://localhost:8000/test/?test=1', wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
    fixture = json.loads(Path('test-results/results-fixture.json').read_text())
    expected = fixture['slots'][0]['checkpoint']
    page.evaluate('(data)=>localStorage.setItem("snow.campaigns.v1",JSON.stringify(data))', fixture)
    page.reload(wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)

    def click(x, y):
        box = page.locator('canvas').bounding_box()
        page.mouse.click(box['x'] + x / 360 * box['width'], box['y'] + y / 640 * box['height'])

    def mode(value):
        page.wait_for_function('value=>window.snowSnapshot.mode===value', arg=value)

    def snap():
        return page.evaluate('window.snowSnapshot')

    def capture(name):
        page.locator('canvas').screenshot(path=f'docs/images/prototype-{name}.png')

    click(180, 323); mode('slots')
    click(180, 242); mode('results')
    page.wait_for_function('window.snowSnapshot.result_time > 0.4')
    assert not snap()['result_tallied'] and snap()['score_rows'] == [0, 0, 0]
    page.evaluate("window.dispatchEvent(new Event('blur'))")
    page.wait_for_timeout(250)
    assert snap()['mode'] == 'results'
    page.evaluate("window.dispatchEvent(new Event('focus'))")
    page.wait_for_function('window.snowSnapshot.result_tallied')
    assert snap()['result_new_high']
    assert snap()['result_display'] == ['90', '30', str(expected['score'] - expected['week_start_score'])]
    capture('results')
    print('PASS: completed-week results tally the saved counts, stay open across focus changes, and reveal the high-score alert.', flush=True)

    click(100, 427); mode('initials')
    capture('initials')
    click(180, 258)
    page.keyboard.press('Control+A')
    page.keyboard.type('ice', delay=40)
    # Touch-friendly letter buttons also work without a software keyboard.
    click(109, 313); click(109, 358)
    click(116, 445); mode('scores')
    table = page.evaluate("JSON.parse(localStorage.getItem('snow.highscores.v1')).tables[0]")
    assert len(table) == 1 and table[0]['initials'] == 'ICE' and table[0]['score'] == expected['score']
    assert table[0]['outcome'] == 'workshop' and table[0]['week'] == 9
    capture('high-scores')
    click(180, 554); mode('results')
    assert snap()['result_tallied']
    print('PASS: weekly initials can be entered before campaign end, stored in the right table, and viewed without losing results.', flush=True)

    click(230, 427); mode('workshop')
    click(60, 333)
    page.wait_for_function('window.snowSnapshot.selected_upgrade[0]===0 && window.snowSnapshot.selected_upgrade[1]===3')
    click(100, 526)
    page.wait_for_function('window.snowSnapshot.tiers[0]===4 && window.snowSnapshot.points===7')
    click(260, 526); mode('results')
    assert snap()['score'] == expected['score'] and snap()['result_tallied']
    click(100, 477); mode('title')
    page.reload(wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'", timeout=90000)
    click(180, 323); mode('slots')
    click(180, 242); mode('results')
    page.wait_for_function('window.snowSnapshot.result_tallied')
    assert snap()['tiers'] == [4, 3, 2] and snap()['points'] == 7
    assert snap()['result_display'] == ['90', '30', str(expected['score'] - expected['week_start_score'])]
    assert not snap()['result_new_high'] and snap()['score_rows'] == [1, 0, 0]
    click(100, 427); mode('scores')
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.highscores.v1')).tables[0][0].initials") == 'ICE'
    click(180, 554); mode('results')
    click(250, 477); mode('intro')
    mode('play')
    assert snap()['week'] == 10 and snap()['week_rescued'] == 0 and snap()['week_missed'] == 0
    saved = page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1')).slots[0].checkpoint")
    assert saved['phase'] == 'playing' and saved['week_start_score'] == expected['score']
    print('PASS: upgrade purchases return to results; counts, initials and kit survive reload; Next starts a fresh weekly checkpoint.', flush=True)
    capture('compact-hud')
    page.keyboard.down('Space')
    page.wait_for_function('window.snowSnapshot.charge < 0.45')
    page.locator('canvas').screenshot(path='test-results/battery-yellow.png')
    page.wait_for_function('window.snowSnapshot.charge < 0.15')
    page.locator('canvas').screenshot(path='test-results/battery-red.png')
    page.keyboard.up('Space')
    page.wait_for_function('window.snowSnapshot.weather > 0.7', timeout=60000)
    capture('frost-hud')
    print('PASS: real battery discharge and missed leaves drive the compact battery and growing-frost visuals.', flush=True)
    browser.close()
assert not errors, errors
print('No browser runtime errors.', flush=True)
