"""Real-input loss study: leaf coating, bank accumulation and settled snow.

The starting checkpoint is validated by visual_fixture.gd; no gameplay mutation.
"""
import argparse,base64,json
from pathlib import Path
from playwright.sync_api import sync_playwright
p=argparse.ArgumentParser();p.add_argument('--url',default='http://127.0.0.1:8004/test/?test=1');args=p.parse_args()
fixture=json.loads(Path('test-results/continuity-fixture.json').read_text());errors=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':360,'height':640})
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.add_init_script('localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto(args.url);page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def snap():return page.evaluate('snowSnapshot')
    def mode(name):page.wait_for_function('name=>snowSnapshot.mode===name',arg=name,timeout=45000)
    def click(caption):
        page.wait_for_timeout(200)
        b=next(b for b in snap()['ui_buttons'] if b['text'].startswith(caption))
        x,y,w,h=b['rect'];page.mouse.click(x+w/2,y+h/2)
    def capture(name):
        s=snap();Path(f'test-results/{name}.json').write_text(json.dumps({k:s[k] for k in ['snow_cover','ending_phase','ending_attached','ending_air','ending_ground','outfit_index','score']},indent=2))
        shot=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        Path(f'test-results/{name}.png').write_bytes(base64.b64decode(shot['data']))
    click('Continue');mode('slots');click('Mid outfit');mode('continue');click('Continue');mode('intro')
    page.wait_for_timeout(900);page.keyboard.press('Space');mode('play')
    page.keyboard.down('d');page.wait_for_function('snowSnapshot.x===331',timeout=20000);page.keyboard.up('d')
    page.wait_for_function('snowSnapshot.mode==="lost" && snowSnapshot.ending_time>.75',timeout=120000)
    capture('snow-leaves-falling')
    page.wait_for_function('snowSnapshot.snow_cover>=.05 && snowSnapshot.snow_cover<.30',timeout=60000)
    assert snap()['ending_air']==0 and snap()['ending_attached']==0
    capture('snow-first-coating')
    page.wait_for_function('snowSnapshot.snow_cover>=.45 && snowSnapshot.snow_cover<.85',timeout=30000)
    capture('snow-building-banks')
    page.wait_for_function('snowSnapshot.ending_phase==="done"',timeout=30000)
    assert not snap()['result_visible'] and snap()['outfit_index']==6
    capture('snow-settled-banks');score=snap()['score']
    page.wait_for_function('snowSnapshot.ending_continue',timeout=20000)
    page.wait_for_timeout(1200);assert not snap()['result_visible'];click('Continue')
    page.wait_for_function('snowSnapshot.result_visible',timeout=20000)
    assert snap()['score']==score and snap()['defeat_hold_time']>=3
    browser.close()
assert not errors,errors
print('PASS: real leaves land before a thin snow coat builds into banks; outfit, score and final hold survive; no browser errors.')
