"""Real input and read-only observations of the complete wildlife routines."""
import argparse,base64,json
from pathlib import Path
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser();parser.add_argument('--url',default='http://127.0.0.1:8003/test/?test=1');args=parser.parse_args()
fixture=json.loads(Path('test-results/wildlife-fixture.json').read_text());errors=set()
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':540,'height':960})
    page.on('pageerror',lambda e:errors.add(str(e)))
    page.on('console',lambda m:errors.add(m.text) if m.type=='error' else None)
    page.add_init_script('''window.wildlifeSeen={};window.wildlifeObserving=false;
      let latestWildlifeSnapshot;
      Object.defineProperty(window,'snowSnapshot',{configurable:true,
        get(){return latestWildlifeSnapshot;},
        set(value){latestWildlifeSnapshot=value;if(window.wildlifeObserving){
          for(const a of value.world.animals){const key=a.kind+':'+a.action;
            (wildlifeSeen[key]??={})[a.frame]=true;
          }
        }}
      });''')
    page.add_init_script('if(!localStorage.getItem("snow.campaigns.v1"))localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto(args.url);page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def snap():return page.evaluate('snowSnapshot')
    def mode(value):page.wait_for_function('v=>snowSnapshot.mode===v',arg=value,timeout=45000)
    def click(caption):
        page.wait_for_timeout(180)
        b=next(b for b in snap()['ui_buttons'] if b['text'].startswith(caption))
        x,y,w,h=b['rect'];box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+(x+w/2)/360*box['width'],box['y']+(y+h/2)/640*box['height'])
    def capture(name):
        assert not errors,sorted(errors)[:12]
        Path(f'test-results/wildlife-{name}.json').write_text(json.dumps(snap(),indent=2))
        data=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        Path(f'test-results/wildlife-{name}.png').write_bytes(base64.b64decode(data['data']))
    def observe():
        # Observe each published snapshot; timer polling can miss a short wingbeat
        # while the software renderer catches up on physics steps.
        page.evaluate('window.wildlifeSeen={};window.wildlifeObserving=true;')
    click('Explore the seasons');mode('preview');observe()
    page.wait_for_function('snowSnapshot.world.animals.some(a=>a.kind==="squirrel" && a.x>20 && a.x<340)',timeout=45000)
    squirrel_plane=next(a for a in snap()['world']['animals'] if a['kind']=='squirrel')['plane']
    if squirrel_plane=='tree':
        page.wait_for_function('snowSnapshot.world.animals.some(a=>a.kind==="squirrel" && a.action==="climb" && a.y<390)',timeout=45000)
        capture('squirrel-climbing')
    else:
        capture('squirrel-ground-running')
    page.wait_for_function('snowSnapshot.world.animals.some(a=>a.kind==="squirrel" && a.action==="nibble")',timeout=45000)
    squirrel=next(a for a in snap()['world']['animals'] if a['kind']=='squirrel')
    assert squirrel['plane']==squirrel_plane
    capture('squirrel-perched' if squirrel_plane=='tree' else 'squirrel-ground-nibbling')
    page.wait_for_function('snowSnapshot.world.animals.some(a=>a.kind==="rabbit" && a.direction===-1 && a.x<345 && a.x>150)',timeout=45000)
    capture('rabbit-returning')
    page.wait_for_function('Object.keys(wildlifeSeen["rabbit:graze"]||{}).length>=3',timeout=45000)
    seen=page.evaluate('wildlifeSeen')
    if squirrel_plane=='tree':
        assert len(seen.get('squirrel:climb',{}))>=3 and len(seen.get('squirrel:jump',{}))>=2,seen
    else:
        assert len(seen.get('squirrel:run',{}))>=3,seen
    assert len(seen.get('rabbit:graze',{}))>=3,seen
    print(f'PASS: squirrel completes its selected {squirrel_plane} route and nibbles; rabbit grazes and returns facing left.',flush=True)
    click('Back to menu');mode('title');click('Continue');mode('slots');click('Night wildlife');mode('continue');click('Continue');mode('intro')
    page.wait_for_timeout(800);page.keyboard.press('Space');mode('play');observe()
    page.keyboard.down('a');page.wait_for_function('snowSnapshot.x===29',timeout=20000);page.keyboard.up('a');page.wait_for_timeout(400)
    left=next(a for a in snap()['world']['animals'] if a['kind']=='owl');assert left['plane']=='tree' and left['look']<0
    capture('owl-looking-left')
    page.keyboard.down('d');page.wait_for_function('snowSnapshot.x===331',timeout=25000);page.keyboard.up('d');page.wait_for_timeout(400)
    right=next(a for a in snap()['world']['animals'] if a['kind']=='owl');assert right['look']>0 and right['x']==left['x'] and right['y']==left['y']
    page.wait_for_function('snowSnapshot.world.animals.some(a=>a.kind==="owl" && a.action==="watch")',timeout=5000)
    capture('owl-looking-right')
    page.wait_for_function('Object.keys(wildlifeSeen["owl:flap"]||{}).length>=5',timeout=45000)
    page.keyboard.press('Escape');mode('paused');frozen=snap()['world'];page.wait_for_timeout(500);assert snap()['world']==frozen
    print('PASS: owl stays on a main-tree perch, follows real player movement, animates its wings and freezes on pause.',flush=True)
    click('Exit to menu');click('Exit');mode('title');click('Explore the seasons');mode('preview')
    for i in range(5):click('›')
    page.wait_for_function('snowSnapshot.world.time==="night"')
    click('Full moon');observe();page.wait_for_function('snowSnapshot.world.rare && snowSnapshot.world.moon===0')
    assert not any(a['kind']=='rabbit' for a in snap()['world']['animals'])
    page.wait_for_function('Object.keys(wildlifeSeen["bat:fly"]||{}).length>=6 && Object.keys(wildlifeSeen["wolf:trot"]||{}).length>=5',timeout=45000)
    capture('full-moon-visitors')
    print('PASS: the Full moon review shows the wolf trot and bat wingbeat with multiple distinct poses.',flush=True)
    browser.close()
assert not errors,sorted(errors)[:12]
print('No browser runtime errors.')
