"""Real-input weather transition, central crown and matching defeat-outfit review."""
import argparse,base64,json
from pathlib import Path
from playwright.sync_api import sync_playwright
options=argparse.ArgumentParser();options.add_argument('--url',default='http://localhost:8000/test/?test=1');options=options.parse_args()
fixture=json.loads(Path('test-results/continuity-fixture.json').read_text());errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':540,'height':960})
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.add_init_script('if(!localStorage.getItem("snow.campaigns.v1"))localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto(options.url);page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def snap():return page.evaluate('snowSnapshot')
    def mode(value):page.wait_for_function('v=>snowSnapshot.mode===v',arg=value,timeout=45000)
    def click(caption):
        page.wait_for_timeout(180)
        button=next(b for b in snap()['ui_buttons'] if b['text'].startswith(caption))
        x,y,w,h=button['rect'];box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+(x+w/2)/360*box['width'],box['y']+(y+h/2)/640*box['height'])
    def capture(name):
        Path(f'test-results/{name}.json').write_text(json.dumps(snap(),indent=2))
        data=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        Path(f'test-results/{name}.png').write_bytes(base64.b64decode(data['data']))
    def start_slot(name):
        click('Continue / New game');mode('slots');click(name);mode('continue');click('Continue');mode('intro')
        page.wait_for_timeout(1000);page.keyboard.press('Space');mode('play')
    click('Continue / New game');mode('slots');click('Next level study');mode('results')
    page.wait_for_function('snowSnapshot.result_tallied && snowSnapshot.snow_active>0')
    assert snap()['weather']>.55
    click('Week 2');mode('intro');assert snap()['snow_active']==0
    mode('play');page.wait_for_timeout(1400);assert snap()['weather']==0 and snap()['snow_active']==0
    capture('clean-next-level-sky')
    page.keyboard.press('Escape');mode('paused');click('Exit to menu');click('Exit');mode('title')
    print('PASS: warning flakes are present before Next Week and absent through the next intro and safe gameplay.',flush=True)
    for name,outfit in [('Early outfit',0),('Mid outfit',6)]:
        start_slot(name)
        if outfit==0:capture('central-fork-filled')
        assert snap()['outfit_index']==outfit and snap()['snow_active']==0
        page.keyboard.down('d');page.wait_for_function('snowSnapshot.x===331',timeout=15000);page.keyboard.up('d')
        page.wait_for_function('snowSnapshot.mode==="lost" && snowSnapshot.ending_time>.75',timeout=120000)
        assert snap()['outfit_index']==outfit
        capture('defeat-outfit-'+str(outfit))
        page.wait_for_function('snowSnapshot.ending_phase==="done"',timeout=45000)
        assert not snap()['result_visible']
        capture('defeat-settled-snow-'+str(outfit))
        frozen_score=snap()['score'];page.wait_for_function('snowSnapshot.ending_continue',timeout=20000)
        page.wait_for_timeout(1000);assert not snap()['result_visible'];click('Continue')
        page.wait_for_function('snowSnapshot.result_visible',timeout=20000)
        assert snap()['defeat_hold_time']>=3 and snap()['score']==frozen_score
        page.wait_for_function('snowSnapshot.result_tallied');click('Main menu');mode('title')
        print(f'PASS: outfit {outfit} remains selected during defeat, and the finished scene holds before Results.',flush=True)
    click('Explore the seasons');mode('preview')
    outfit=snap()['outfit_index']
    for caption in ['Warning','Winter','Autumn']:
        click(caption)
        page.wait_for_timeout(250)
        assert snap()['outfit_index']==outfit
        if caption=='Winter':capture('preview-matching-defeat')
    click('Back to menu');mode('title')
    print('PASS: warning and winter in Explore the seasons retain the current outfit.',flush=True)
    browser.close()
assert not errors,errors
print('No browser runtime errors.')
