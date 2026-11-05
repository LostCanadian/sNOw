"""Web rendering/input smoke for Challenge's live calendar.
Export debug Web into build/test; serve build/ on port 8000 and generate the
validated challenge-fixture.json with tests/visual_fixture.gd first.
"""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:8000/test/?test=1')
args=parser.parse_args()
fixture=json.loads(Path('test-results/challenge-fixture.json').read_text())
out=Path('work/cycle-browser');out.mkdir(parents=True,exist_ok=True)
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,
        args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':360,'height':640},has_touch=True)
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.add_init_script('localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto(args.url,wait_until='networkidle')
    def mode(value):
        page.wait_for_function('value=>window.snowSnapshot?.mode===value',arg=value,timeout=90000)
    def snap():return page.evaluate('window.snowSnapshot')
    def click(text):
        page.wait_for_function('text=>window.snowSnapshot.ui_buttons.some(b=>b.text===text)',arg=text)
        b=next(b for b in snap()['ui_buttons'] if b['text']==text)
        x,y,w,h=b['rect'];box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+(x+w/2)*box['width']/360,box['y']+(y+h/2)*box['height']/640,delay=80)
        page.wait_for_timeout(350)
    mode('title')
    before=page.evaluate("localStorage.getItem('snow.campaigns.v1')")
    click('Challenge');mode('challenge_setup');click('Easy');mode('play')
    assert snap()['challenge'] and snap()['world']['stage']==0 and snap()['world']['moon']==7
    page.screenshot(path=str(out/'sunny.png'),timeout=15000)
    page.wait_for_function('window.snowSnapshot.mode==="play" && window.snowSnapshot.world.stage===1',timeout=90000)
    assert snap()['world']['weather']=='partly' and snap()['world']['night_amount']==0
    page.keyboard.press('Escape');mode('paused')
    frozen=snap()['time'];profile=snap()['world']['stage']
    page.wait_for_timeout(600)
    assert snap()['time']==frozen and snap()['world']['stage']==profile
    page.screenshot(path=str(out/'partly-paused.png'),timeout=15000)
    assert page.evaluate("localStorage.getItem('snow.campaigns.v1')")==before
    print('PASS: Web shader/atlas rendering, sunny→partly-cloudy Challenge, ordered first moon, pause and untouched saves.',flush=True)
    browser.close()
assert not errors,errors
print('No browser errors.',flush=True)
