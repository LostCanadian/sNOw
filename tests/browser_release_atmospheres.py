"""Release-template render regression: real scene input, packaged music, no debug hooks."""
import argparse,base64
from io import BytesIO
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser();parser.add_argument('--url',default='http://127.0.0.1:8003/web/?test=1');args=parser.parse_args()
errors=[];Path('test-results').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':360,'height':640})
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.goto(args.url);page.locator('#status').wait_for(state='hidden',timeout=90000);page.wait_for_timeout(1200)
    assert page.evaluate('typeof snowSnapshot')=='undefined'
    assert page.evaluate('typeof snowDiagnostics')=='undefined'
    page.mouse.click(180,377)
    def music(name):
        page.wait_for_function('name=>snowMusic.urls[name] && snowMusic.players[snowMusic.current].readyState>=2',arg=name,timeout=20000)
    def capture(name):
        data=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        png=base64.b64decode(data['data']);im=Image.open(BytesIO(png)).convert('RGB');raw=im.tobytes()
        neon=sum(1 for r,g,b in zip(raw[::3],raw[1::3],raw[2::3]) if r<80 and g>230 and (b<80 or b>230))
        assert neon<8,(name,neon)
        if name.startswith('week-'):
            crown=im.crop((60,100,340,340)).tobytes()
            foliage=sum(1 for r,g,b in zip(crown[::3],crown[1::3],crown[2::3]) if 65<r<220 and g>80 and g>b*1.2 and g>r*.85)
            assert foliage>4000,(name,'missing foliage',foliage)
        if name in ['week-6-1','week-5-1','winter','victory']:Path(f'test-results/release-{name}.png').write_bytes(png)
    for week in range(1,14):
        if week>1:page.mouse.click(331,92)
        music('boss' if week==13 else f'week_{week:02d}')
        for frame in range(2):
            page.wait_for_timeout(180);capture(f'week-{week}-{frame}')
    for x,name in [(314,'victory'),(227,'winter')]:
        page.mouse.click(x,561);music(name);page.wait_for_timeout(400);capture(name)
    info=page.evaluate('({state:snowMusic.context.state,playing:!snowMusic.players[snowMusic.current].paused,time:snowMusic.players[snowMusic.current].currentTime})')
    assert info['state']=='running' and info['playing'] and info['time']>0,info
    browser.close()
assert not errors,errors
print('PASS: release rendering stays textured across thirteen atmospheres and both endings; packaged music plays, debug hooks are absent, no browser errors.')
