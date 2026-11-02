"""Real browser input over validated loadout/story fixtures, without runtime state setters."""
import json
import os
from pathlib import Path
import subprocess
import time
from playwright.sync_api import sync_playwright

errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,
        args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    context=browser.new_context(viewport={'width':360,'height':640},has_touch=True,
        record_video_dir='test-results/surge-video',record_video_size={'width':360,'height':640})
    started=time.monotonic()
    page=context.new_page()
    page.on('dialog',lambda dialog:dialog.accept())
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
    page.goto('http://localhost:8000/test/?test=1',wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'",timeout=90000)
    document=json.loads(Path('test-results/ability-fixture.json').read_text())
    page.evaluate('(data)=>localStorage.setItem("snow.campaigns.v1",JSON.stringify(data))',document)
    page.reload(wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode === 'title'",timeout=90000)
    def click(x,y):
        box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+x/360*box['width'],box['y']+y/640*box['height'])
    def mode(value):page.wait_for_function('value=>window.snowSnapshot.mode === value',arg=value)
    def snap():return page.evaluate('window.snowSnapshot')
    click(180,323);mode('slots');click(180,242);mode('paused')
    page.keyboard.press('Escape');mode('intro')
    page.wait_for_function("window.snowSnapshot.mode === 'intro' && window.snowSnapshot.story_time > 0.5")
    intro_frame=time.monotonic()-started-0.12
    assert snap()['time']==0
    page.keyboard.press('Escape');mode('paused')
    frozen=snap()['story_time']
    page.wait_for_timeout(500)
    assert snap()['story_time']==frozen
    page.keyboard.press('Escape');mode('intro')
    page.wait_for_function('window.snowSnapshot.story_time > 0.7')
    page.keyboard.press('Space');mode('play')
    assert not snap()['blowing'] and snap()['surge_unlocked']
    print('PASS: the scene opens with readable story text; pause freezes it and Space skips without blowing.',flush=True)
    page.wait_for_function('window.snowSnapshot.grounded >= 60',timeout=60000)
    video_trim=time.monotonic()-started
    before=snap()
    nearest=max(before['ground_positions'],key=lambda leaf:sum(abs(other[1]-(leaf[1]+16))<85 for other in before['ground_positions']))
    target=max(29,min(331,nearest[1]+16))
    if abs(before['x']-target)>4:
        key='d' if before['x']<target else 'a'
        page.keyboard.down(key)
        page.wait_for_function('([x,key])=>key==="d" ? window.snowSnapshot.x>=x-3 : window.snowSnapshot.x<=x+3',arg=[target,key])
        page.keyboard.up(key)
    page.wait_for_timeout(150)
    ground_frame=time.monotonic()-started-0.05
    grounded=snap()
    assert grounded['grounded']==grounded['week_missed']
    assert grounded['attached']+grounded['air']+grounded['missed']-grounded['regrown']==2880
    charge_before=grounded['week_missed']
    page.keyboard.press('e')
    page.wait_for_function('window.snowSnapshot.surge_charge < 0.05 && window.snowSnapshot.surge_active')
    lifted=snap()
    assert lifted['week_missed']<charge_before and lifted['grounded']<grounded['grounded']
    assert lifted['attached']+lifted['air']+lifted['missed']-lifted['regrown']==2880
    page.wait_for_function('window.snowSnapshot.surge_active && window.snowSnapshot.surge_offset[1] < -25 && Math.abs(window.snowSnapshot.surge_spin)>1')
    page.keyboard.down('Space')
    page.wait_for_timeout(4000)
    page.keyboard.up('Space')
    video_duration=time.monotonic()-started-video_trim
    page.keyboard.press('Escape');mode('paused')
    ability=snap()['surge_charge']
    page.wait_for_timeout(400)
    assert snap()['surge_charge']==ability
    print('PASS: real ground leaves conserve identity; E lifts them, restores frost headroom and starts a slow cooldown.',flush=True)
    click(180,387);page.wait_for_timeout(300);click(180,383);mode('title')
    click(180,323);mode('slots');click(180,322);mode('paused')
    page.keyboard.press('Escape');mode('intro')
    mode('play')
    mode('outro')
    page.wait_for_function("window.snowSnapshot.mode === 'outro' && window.snowSnapshot.story_time > 0.5")
    outro_frame=time.monotonic()-started-0.12
    assert page.evaluate("JSON.parse(localStorage.getItem('snow.campaigns.v1')).slots[1].checkpoint.phase")=='workshop'
    mode('results')
    page.wait_for_function('window.snowSnapshot.result_tallied')
    click(180,456);mode('workshop')
    assert snap()['points']==7
    print('PASS: the shortened story fixture completes through real physics, autosaves and shows a unique closing panel before the workshop.',flush=True)
    movie=page.video
    context.close()
    output=Path(movie.path())
    subprocess.run(['ffmpeg','-v','error','-y','-ss',str(video_trim),'-i',str(output),'-t',str(video_duration),
        '-c:v','libx264','-preset','medium','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart','-an',
        'test-results/surge-preview.mp4'],check=True)
    for timestamp,name in [(intro_frame,'story-intro'),(ground_frame,'ground-leaves'),(outro_frame,'story-outro')]:
        subprocess.run(['ffmpeg','-v','error','-y','-ss',str(timestamp),'-i',str(output),'-frames:v','1',
            f'test-results/{name}-candidate.png'],check=True)
    Path('test-results/surge-clip.json').write_text(json.dumps({'path':str(output),'trim':video_trim,'duration':video_duration,
        'intro_frame':intro_frame,'ground_frame':ground_frame,'outro_frame':outro_frame}))
    browser.close()
assert not errors,errors
print('No browser runtime errors.',flush=True)
