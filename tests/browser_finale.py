"""Real-input finale art/flow study from validated checkpoints, not a human campaign win."""
import argparse,json
from pathlib import Path
from playwright.sync_api import sync_playwright
options=argparse.ArgumentParser();options.add_argument('--url',default='http://localhost:8000/test/?test=1');options=options.parse_args()
fixture=json.loads(Path('test-results/finale-fixture.json').read_text())
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':540,'height':960})
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.add_init_script('if(!localStorage.getItem("snow.campaigns.v1"))localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto(options.url);page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def mode(value):page.wait_for_function('v=>snowSnapshot.mode===v',arg=value,timeout=45000)
    def snap():return page.evaluate('snowSnapshot')
    def click(caption):
        page.wait_for_timeout(180)
        button=next(b for b in snap()['ui_buttons'] if b['text'].startswith(caption))
        x,y,w,h=button['rect'];canvas=page.locator('canvas').bounding_box()
        page.mouse.click(canvas['x']+(x+w/2)/360*canvas['width'],canvas['y']+(y+h/2)/640*canvas['height'])
    def capture(name):
        Path(f'test-results/{name}.json').write_text(json.dumps(snap(),indent=2))
        screenshot=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        import base64
        Path(f'test-results/{name}.png').write_bytes(base64.b64decode(screenshot['data']))
    def skip_intro():
        mode('intro');page.wait_for_timeout(1000);page.keyboard.press('Space');mode('play')
    click('Continue / New game');mode('slots');click('Victory study');mode('continue');click('Continue');skip_intro()
    page.keyboard.down('Space');page.wait_for_function('snowSnapshot.mode==="won" && !snowSnapshot.result_visible',timeout=30000);page.keyboard.up('Space')
    page.wait_for_function('snowSnapshot.flower_progress===1 && snowSnapshot.ending_time<6',timeout=30000)
    assert not snap()['result_visible'];capture('finale-flowers-complete')
    mode('victory_outro');assert not snap()['result_visible']
    page.keyboard.press('Escape');mode('paused');frozen=snap()['story_time'];page.wait_for_timeout(400);assert snap()['story_time']==frozen
    page.keyboard.press('Escape');mode('victory_outro');capture('finale-closing-card');page.keyboard.press('Space')
    page.wait_for_function('snowSnapshot.result_visible');page.wait_for_function('snowSnapshot.result_tallied');capture('finale-clean-results')
    print('PASS: flowers finish and hold before a separate victory card, pause freezes it, and Results follow.',flush=True)
    click('Main menu');mode('title');click('Continue / New game');mode('slots');click('North Wind study');mode('continue');click('Continue');skip_intro()
    assert snap()['attached']==960 and snap()['seasonal_fallen']==1200
    page.wait_for_function('snowSnapshot.boss_phase==="blast" && snowSnapshot.wind_center[0]>95 && snowSnapshot.wind_center[0]<280 && snowSnapshot.wind_released>0',timeout=30000)
    capture('north-wind-sweep')
    page.wait_for_function('snowSnapshot.time>5.7 && snowSnapshot.boss_phase==="blast" && snowSnapshot.wind_released>0',timeout=30000)
    capture('north-wind-return')
    assert snap()['air']>0 and snap()['attached']<960
    page.keyboard.press('Escape');mode('paused');frozen=snap()['time'];page.wait_for_timeout(350);assert snap()['time']==frozen
    click('Exit to menu');click('Exit');mode('title')
    click('Continue / New game');mode('slots');click('Slot 3');mode('name');click('Start week 1');skip_intro()
    capture('filled-middle-right-crown')
    assert snap()['seasonal_fallen']==0 and snap()['attached']>2100 and snap()['week']==1
    page.wait_for_function('snowSnapshot.air>0');capture('brighter-attachment-twinkles')
    browser.close()
assert not errors,errors
print('PASS: visible stripping gusts in both directions, boss pause, healthy late crown, filled initial branches and attachment cues; no browser errors.')
