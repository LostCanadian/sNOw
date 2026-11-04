"""Real-input capture and visual review using a validated one-leaf study checkpoint."""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

options=argparse.ArgumentParser()
options.add_argument('--url',default='http://localhost:8000/test/?test=1')
options=options.parse_args()
study=json.loads(Path('test-results/attachment-fixture.json').read_text())
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,
        args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    page=browser.new_page(viewport={'width':540,'height':960})
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
    page.add_init_script('localStorage.setItem("snow.campaigns.v1",'+json.dumps(json.dumps(study['saves']))+');')
    page.goto(options.url)
    page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
    def mode(value):page.wait_for_function('v=>snowSnapshot.mode===v',arg=value)
    def snap():return page.evaluate('snowSnapshot')
    def click(caption):
        page.wait_for_timeout(150)
        button=next(b for b in snap()['ui_buttons'] if b['text']==caption)
        x,y,w,h=button['rect'];canvas=page.locator('canvas').bounding_box()
        page.mouse.click(canvas['x']+(x+w/2)/360*canvas['width'],canvas['y']+(y+h/2)/640*canvas['height'])
    def capture(name):page.locator('canvas').screenshot(path=f'test-results/{name}.png')
    click('Continue / New game');mode('slots');click('Attachment study\nWeek 2 · Blustery');mode('continue')
    click('Continue');mode('intro');mode('play')
    page.evaluate('''window.settleSamples=[];window.lastSettleAge=-1;
      function observeSettle(){for(const record of window.snowSnapshot?.attachments??[]){
        if(record[1]!==window.lastSettleAge){window.settleSamples.push([...record]);window.lastSettleAge=record[1];}}
        requestAnimationFrame(observeSettle);}observeSettle();''')
    target_x=max(29,min(331,study['target'][0]-11.7))
    if abs(snap()['x']-target_x)>3:
        page.keyboard.down('d' if snap()['x']<target_x else 'a')
        page.wait_for_function('target=>Math.abs(snowSnapshot.x-target)<12',arg=target_x)
        page.keyboard.up('d');page.keyboard.up('a')
    page.wait_for_function('Math.abs(snowSnapshot.aim)<0.01')
    page.wait_for_function('target=>snowSnapshot.airborne.some(leaf=>leaf[1]>target[1]+0.5)',arg=study['target'])
    page.wait_for_function('snowSnapshot.time>=2.6')
    page.keyboard.down('Space')
    try:
        page.wait_for_function('window.settleSamples.length>=2',timeout=30000)
    except Exception:
        print('CAPTURE DIAGNOSTIC',snap(),page.evaluate('window.settleSamples'),errors,flush=True)
        capture('attachment-study-failure')
        raise
    page.keyboard.up('Space')
    mode('outro')
    page.wait_for_function('snowSnapshot.attachments.length===0')
    samples=page.evaluate('window.settleSamples')
    assert len({tuple(record[4:6]) for record in samples})>=2,samples
    assert any(abs(record[4]-record[6])+abs(record[5]-record[7])>1 for record in samples),samples
    assert snap()['rescued']==1 and snap()['missed']==0
    print('PASS: a real blower capture travels through multiple intermediate poses before resting, including on the final leaf.',flush=True)
    mode('results');page.wait_for_function('snowSnapshot.result_tallied')
    button=next(b for b in snap()['ui_buttons'] if b['text']=='Upgrades')
    x,y,w,h=button['rect'];canvas=page.locator('canvas').bounding_box()
    page.mouse.move(canvas['x']+(x+w/2)/360*canvas['width'],canvas['y']+(y+h/2)/640*canvas['height'])
    page.wait_for_timeout(1200);capture('results-upgrades-no-tooltip')
    click('Main menu');mode('title');click('Explore the seasons');mode('preview')
    click('Warning');page.wait_for_function('snowSnapshot.weather>.8');capture('paper-cloud-warning')
    click('Winter');page.wait_for_function('snowSnapshot.snow_cover===1');capture('paper-cloud-winter')
    Path('test-results/attachment-samples.json').write_text(json.dumps(samples,indent=2))
    browser.close()
assert not errors,errors
print('PASS: warning/winter paper-cloud rendering and Upgrades hover review; no browser errors.')
