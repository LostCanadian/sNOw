"""Real-input review of all weekly atmospheres, wildlife motion and pause."""
import argparse,base64,json
from pathlib import Path
from playwright.sync_api import sync_playwright
args=argparse.ArgumentParser();args.add_argument('--url',default='http://127.0.0.1:8003/test/?test=1');options=args.parse_args()
errors=[];Path('test-results').mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':540,'height':960})
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    page.add_init_script('''window.snowAudioAnalysers=[];
      const snowConnect=AudioNode.prototype.connect;
      AudioNode.prototype.connect=function(...args){
        if(args[0]===this.context.destination){
          const analyser=this.context.createAnalyser();analyser.fftSize=2048;
          window.snowAudioAnalysers.push(analyser);
          snowConnect.call(analyser,args[0]);args[0]=analyser;
        }
        return snowConnect.apply(this,args);
      };''')
    page.goto(options.url);page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def snap():return page.evaluate('snowSnapshot')
    def mode(value):page.wait_for_function('v=>snowSnapshot.mode===v',arg=value)
    def click(caption):
        page.wait_for_timeout(170)
        button=next(b for b in snap()['ui_buttons'] if b['text'].startswith(caption))
        x,y,w,h=button['rect'];box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+(x+w/2)/360*box['width'],box['y']+(y+h/2)/640*box['height'])
    def capture(name):
        Path(f'test-results/ambient-{name}.json').write_text(json.dumps(snap(),indent=2))
        data=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        Path(f'test-results/ambient-{name}.png').write_bytes(base64.b64decode(data['data']))
        from PIL import Image
        pixels=Image.open(f'test-results/ambient-{name}.png').convert('RGB')
        # The authored canopy has no neon cyan/green. Catch canvas material state
        # leaking into the instanced leaf pass, including after pause/resume.
        raw=pixels.crop((70,120,520,550)).tobytes()
        neon=sum(1 for r,g,b in zip(raw[::3],raw[1::3],raw[2::3]) if r<80 and g>230 and (b<80 or b>230))
        assert neon<8,(name,neon)
    click('Explore the seasons');mode('preview')
    names=[]
    for week in range(1,14):
        if week>1:click('›')
        page.wait_for_function('([last])=>snowSnapshot.world.name!==last',arg=[names[-1] if names else ''])
        world=snap()['world'];names.append(world['name'])
        expected='boss' if week==13 else f'week_{week:02d}'
        page.wait_for_function('track=>snowSnapshot.audio_track===track',arg=expected)
        assert len(set(a['kind'] for a in world['animals']))<=3
        if week in [1,2,12,13]:assert world['time']=='day'
        if week in [1,4,5,6,8,9,13]:
            page.wait_for_timeout(650);capture(str(week))
    assert len(set(names))==13
    page.wait_for_function('''()=>snowAudioAnalysers.some(a=>{let v=new Float32Array(a.fftSize);a.getFloatTimeDomainData(v);return v.some(x=>Math.abs(x)>0.0001)})''',timeout=15000)
    click('Victory');page.wait_for_timeout(600);capture('victory')
    click('Back to menu');mode('title')
    click('Continue / New game');mode('slots');click('Slot 1');mode('name');click('Start week 1');mode('intro')
    page.wait_for_timeout(700);page.keyboard.press('Space');mode('play')
    page.wait_for_timeout(500);before=snap()['world']
    page.keyboard.press('Escape');mode('paused');frozen=snap()['world'];page.wait_for_timeout(500)
    assert snap()['world']==frozen
    assert page.evaluate('''Math.max(0,...snowAudioAnalysers.map(a=>{let v=new Float32Array(a.fftSize);a.getFloatTimeDomainData(v);return Math.max(...v.map(Math.abs))}))''')<0.00001
    page.keyboard.press('Escape');mode('play');page.wait_for_timeout(500)
    assert snap()['world']['clock']>frozen['clock']
    assert snap()['world']['name']==before['name']
    capture('playing')
    browser.close()
assert not errors,errors
print('PASS: all thirteen scenes and scores, paper wildlife, textured leaf colors, audible music, victory and real pause/resume; no browser errors.')
