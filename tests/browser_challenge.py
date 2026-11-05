"""Real browser menu/overwrite/Challenge regression.
Export debug Web to build/test, serve build/ on port 8000, and run
`bash tools/godot.sh --headless --script tests/visual_fixture.gd` first.
"""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--fixture', default='test-results/challenge-fixture.json')
args = parser.parse_args()
fixture = json.loads(Path(args.fixture).read_text())
out = Path('work/challenge-browser')
out.mkdir(parents=True, exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
        args=['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
    context = browser.new_context(viewport={'width':360, 'height':640}, has_touch=True)
    page = context.new_page()
    page.on('dialog', lambda d: d.accept())
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
    page.goto('http://127.0.0.1:8000/test/?test=1', wait_until='networkidle')
    def mode(value):
        print('Waiting for', value, flush=True)
        page.wait_for_function('value => window.snowSnapshot?.mode === value', arg=value, timeout=90000)
    def snap():
        return page.evaluate('window.snowSnapshot')
    def click(text):
        print("Click", text, flush=True)
        page.locator("canvas").focus()
        page.wait_for_timeout(200)
        page.wait_for_function('text => window.snowSnapshot.ui_buttons.some(b => b.text === text)', arg=text)
        b = next(b for b in snap()['ui_buttons'] if b['text'] == text)
        x, y, w, h = b['rect']
        box = page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+(x+w/2)*box['width']/360, box['y']+(y+h/2)*box['height']/640, delay=80)
        page.wait_for_timeout(350)
    def capture(name):
        page.screenshot(path=str(out / f'{name}.png'), timeout=15000)
    def slots():
        return page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1')).slots")
    mode('title')
    capture('locked-menu')
    click('New Game'); mode('slots'); click('Slot 1 · Empty'); mode('name')
    click('Hard'); click('Start week 1'); mode('intro')
    assert slots()[0]['checkpoint']['difficulty'] == 2
    original = slots()
    page.reload(wait_until='networkidle'); mode('title')
    click('Continue'); mode('slots'); click('Save 1\nWeek 1 · Hard'); mode('continue')
    assert snap()['difficulty'] == 2 and snap()['time'] == 0
    click('Save Slots'); mode('slots'); click('Back to menu'); mode('title')
    click('New Game'); mode('slots'); click('Save 1\nWeek 1 · Hard'); mode('name')
    click('Medium'); click('Review fresh start')
    capture('overwrite-review')
    assert slots() == original
    click('Keep my save'); mode('slots'); assert slots() == original
    click('Save 1\nWeek 1 · Hard'); mode('name'); click('Medium'); click('Review fresh start')
    click('Start fresh · Medium'); mode('intro')
    assert slots()[0]['checkpoint']['run_id'] != original[0]['checkpoint']['run_id']
    assert slots()[1:] == original[1:]
    print('PASS: separate Continue/New Game routes and confirmed slot replacement.', flush=True)
    # Validated completed campaign fixture tests migration from pre-unlock saves.
    page.evaluate('(data) => localStorage.setItem("snow.campaigns.v1", JSON.stringify(data))', fixture)
    page.reload(wait_until='networkidle'); mode('title')
    assert snap()['challenge_unlocked']
    capture('unlocked-menu')
    before = slots()
    click('Challenge'); mode('challenge_setup'); capture('challenge-setup')
    click('Hard'); mode('play')
    assert snap()['challenge'] and snap()['tiers'] == [10,10,10]
    assert snap()['active_slot'] == -1 and snap()['level_quota'] == 0 and snap()['surge_unlocked']
    first_interval = snap()['shedding_interval']
    page.keyboard.down('Space')
    page.wait_for_function('window.snowSnapshot.rescued > 0', timeout=60000)
    page.keyboard.up('Space')
    capture('challenge-play')
    assert snap()['shedding_interval'] < first_interval
    page.evaluate("window.dispatchEvent(new Event('blur'))"); mode('paused')
    frozen = snap()['time']; page.wait_for_timeout(400); assert snap()['time'] == frozen
    page.evaluate("window.dispatchEvent(new Event('focus'))"); click('Resume'); mode('play')
    page.wait_for_function('window.snowSnapshot.phase === "lost"', timeout=90000)
    page.wait_for_function('window.snowSnapshot.ending_continue', timeout=60000)
    click('Continue'); mode('lost')
    page.wait_for_function('window.snowSnapshot.result_tallied')
    capture('challenge-results')
    click('Enter initials'); mode('initials'); click('Save score'); mode('lost')
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.challenge_scores.v1')).tables[2][0].score") > 0
    assert page.evaluate("localStorage.getItem('snow.highscores.v1')") is None
    assert slots() == before
    click('Play again'); mode('play')
    assert snap()['score'] == 0 and snap()['tiers'] == [10,10,10]
    page.reload(wait_until='networkidle'); mode('title')
    click('High Scores'); mode('scores'); click('Challenge'); mode('scores')
    capture('challenge-scores')
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.challenge_scores.v1')).tables[2][0].score") > 0
    assert slots() == before
    print('PASS: migrated unlock, all-upgrade Challenge, focus pause, loss, separate persistent scores and fresh retry.', flush=True)
    browser.close()
assert not errors, errors
print('No browser errors.', flush=True)
