"""Beta regression with real browser input and validated campaign fixtures.
Run: export-debug into build/test, serve build/, generate visual_fixture.gd, then run.
No mutation hooks are compiled into release exports. Audio is measured at WebAudio output.
"""
import json
import argparse
from pathlib import Path
from playwright.sync_api import sync_playwright

out=Path('test-results/beta');out.mkdir(parents=True,exist_ok=True)
summary=json.loads(Path('test-results/results-fixture.json').read_text())['slots'][0]
studies=json.loads(Path('test-results/ability-fixture.json').read_text())['slots']
fixture={'version':1,'slots':[summary,studies[0],studies[1]]}
options=argparse.ArgumentParser();options.add_argument('--record',action='store_true');options=options.parse_args()
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    recording={'record_video_dir':str(out/'video'),'record_video_size':{'width':360,'height':640}} if options.record else {}
    context=browser.new_context(viewport={'width':360,'height':640},has_touch=True,**recording)
    page=context.new_page()
    page.on('dialog',lambda d:d.accept())
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
    page.add_init_script('if(!localStorage.getItem("snow.campaigns.v1"))localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(fixture))+');')
    page.goto('http://localhost:8000/test/?test=1',wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode==='title'",timeout=90000)
    def click(x,y):
        page.locator('canvas').focus()
        page.wait_for_timeout(250)
        box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+x/360*box['width'],box['y']+y/640*box['height'],delay=80)
        page.wait_for_timeout(600)
    def mode(value):page.wait_for_function('value=>window.snowSnapshot.mode===value',arg=value,timeout=30000)
    def snap():return page.evaluate('window.snowSnapshot')
    def capture(name):page.screenshot(path=str(out/f'{name}.png'))
    def rms():return page.evaluate('''Math.max(0,...snowAudioAnalysers.map(a=>{let v=new Float32Array(a.fftSize);a.getFloatTimeDomainData(v);return Math.sqrt(v.reduce((s,x)=>s+x*x,0)/v.length)}))''')
    def audible():page.wait_for_function('''()=>snowAudioAnalysers.some(a=>{let v=new Float32Array(a.fftSize);a.getFloatTimeDomainData(v);return v.some(x=>Math.abs(x)>0.0001)})''',timeout=15000)
    def menu_from_play():
        page.keyboard.press('Escape');mode('paused');click(180,387);page.wait_for_timeout(200);click(180,383);mode('title')
    capture('menu')
    page.evaluate("window.dispatchEvent(new Event('blur'))")
    page.wait_for_timeout(250);assert snap()['mode']=='title';page.evaluate("window.dispatchEvent(new Event('focus'))")
    click(180,323);mode('slots');click(180,242);mode('results')
    page.wait_for_function('window.snowSnapshot.result_tallied')
    assert snap()['result_display']==['90','30',str(summary['checkpoint']['score']-summary['checkpoint']['week_start_score'])]
    page.evaluate("window.dispatchEvent(new Event('blur'))");page.wait_for_timeout(250)
    assert snap()['mode']=='results';page.evaluate("window.dispatchEvent(new Event('focus'))")
    capture('results');audible();print('PASS: completed results stay open on blur and scene music is audible.',flush=True)
    click(100,427);mode('initials');click(180,258);page.keyboard.press('Control+A',delay=80);page.keyboard.type('ice',delay=80);click(116,445);mode('scores')
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.highscores.v1')).tables[0][0].initials")=='ICE'
    click(180,554);mode('results');click(230,427);mode('workshop')
    before=snap()['points'];click(60,333)
    page.wait_for_function('window.snowSnapshot.selected_upgrade[1]===3')
    click(100,526);page.wait_for_function('window.snowSnapshot.tiers[0]===4')
    assert snap()['points']==before-1
    capture('boots')
    click(180,172);page.wait_for_timeout(300);page.wait_for_function('window.snowSnapshot.selected_upgrade[0]===1',timeout=10000)
    page.wait_for_timeout(650);click(260,276);page.wait_for_timeout(300);capture('whirlwind')
    click(288,172);page.wait_for_timeout(650);click(300,333);page.wait_for_timeout(250)
    before=snap()['points'];click(100,526);page.wait_for_timeout(250);assert snap()['points']==before
    capture('locked-branch');print('PASS: initials and branching workshop purchases/locks.',flush=True)
    click(260,526);mode('results');click(250,477);mode('intro')
    page.wait_for_timeout(800);page.keyboard.press('Space');mode('play')
    assert snap()['week']==10 and snap()['audio_track']=='week_10'
    page.keyboard.down('d');page.wait_for_timeout(470);capture('walk-right');page.keyboard.up('d')
    page.keyboard.down('a');page.wait_for_timeout(470);capture('walk-left');page.keyboard.up('a')
    assert snap()['audio_cues'].get('shuffle',0)>0
    page.keyboard.down('Space');page.wait_for_function('window.snowSnapshot.blowing');audible();page.keyboard.up('Space')
    page.evaluate("window.dispatchEvent(new Event('blur'))");mode('paused')
    print('CHECK: live pause and audio suspension',flush=True)
    frozen=snap()['time'];page.wait_for_timeout(600);assert snap()['time']==frozen and rms()<0.00001
    for width,height in [(360,640),(390,844),(768,1024),(1280,720)]:
        page.set_viewport_size({'width':width,'height':height});page.wait_for_timeout(200)
        box=page.locator('canvas').bounding_box()
        assert abs(box['width']/box['height']-9/16)<.003 and box['y']>=0 and box['y']+box['height']<=height+1
    page.set_viewport_size({'width':360,'height':640})
    page.evaluate("window.dispatchEvent(new Event('focus'))");page.keyboard.press('Escape');mode('play');menu_from_play()
    click(180,323);mode('slots');click(180,322);mode('continue')
    assert snap()['time']==0
    print('PASS: saved level offers Continue.',flush=True)
    capture('continue');click(180,314);mode('intro');page.wait_for_timeout(800);page.keyboard.press('Space');mode('play')
    assert snap()['surge_unlocked'] and snap()['audio_track']=='week_06'
    page.wait_for_function('window.snowSnapshot.grounded>=20',timeout=60000)
    leaves=snap()['ground_positions'];target=max(29,min(331,sum(l[1] for l in leaves)/len(leaves)))
    if abs(snap()['x']-target)>5:
        key='d' if snap()['x']<target else 'a';page.keyboard.down(key)
        page.wait_for_function('x=>Math.abs(window.snowSnapshot.x-x)<6',arg=target)
        page.keyboard.up(key)
    count=snap()['week_missed'];page.keyboard.press('e')
    page.wait_for_function('window.snowSnapshot.surge_active')
    assert snap()['week_missed']<count and snap()['audio_cues'].get('whirlwind',0)==1
    capture('ability');page.wait_for_timeout(1300);menu_from_play()
    click(180,526);mode('audio_options');capture('audio-options')
    click(120,279);click(220,357)
    settings=page.evaluate("JSON.parse(localStorage.getItem('snow.audio.v1'))")
    assert 0<settings['music_volume']<.6 and settings['effects_volume']>.5
    click(180,390);page.wait_for_function('window.snowSnapshot.audio_muted');page.wait_for_timeout(700);assert rms()<.00001
    click(180,390);page.wait_for_function('!window.snowSnapshot.audio_muted');audible()
    click(180,427);mode('title')
    page.reload(wait_until='networkidle');page.wait_for_function("window.snowSnapshot?.mode==='title'",timeout=90000)
    click(180,323);mode('slots');click(180,242);mode('continue')
    assert snap()['week']==10 and snap()['tiers']==[4,3,2] and snap()['time']==0
    saved=page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1')).slots[0].checkpoint")
    assert saved['earned_points']==18 and 3 in saved['owned']
    video=page.video;context.close()
    if video:Path(out/'recording-path.txt').write_text(str(video.path()))
    browser.close()
assert not errors,errors
print('PASS: results, focus behavior, initials, branching purchases, locked paths, next week, saved Continue, movement, Whirlwind, responsive layout, audible WebAudio, pause, mute and persistent audio settings; no browser errors.',flush=True)
