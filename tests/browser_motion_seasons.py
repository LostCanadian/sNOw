"""Real input checks for detachment, rigid walk review, and leaf-first winter.

The full-canopy week-twelve start is a validated study checkpoint, not a played win.
"""
import argparse
import json
import math
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

options=argparse.ArgumentParser()
options.add_argument("--no-pause",action="store_true",help="Record a continuous ending after the default pause check has passed.")
options=options.parse_args()
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,
        args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    context=browser.new_context(viewport={'width':540,'height':960},has_touch=True,
        record_video_dir='test-results/motion-study',record_video_size={'width':540,'height':960})
    started=time.monotonic()
    page=context.new_page()
    page.on('dialog',lambda dialog:dialog.accept())
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
    page.goto('http://localhost:8000/test/?test=1',wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode==='title'",timeout=90000)

    def click(x,y):
        box=page.locator('canvas').bounding_box()
        page.mouse.click(box['x']+x/360*box['width'],box['y']+y/640*box['height'])

    def mode(value):
        page.wait_for_function('value=>window.snowSnapshot.mode===value',arg=value)

    def snap():
        return page.evaluate('window.snowSnapshot')

    def capture(name):
        page.locator('canvas').screenshot(path=f'test-results/{name}.png')

    click(180,323);mode('slots');click(180,242);mode('name');click(180,342);mode('play')
    page.wait_for_function('window.snowSnapshot.air_details.some(leaf=>leaf[6]<0.4)')
    geometry=json.loads(Path('test-results/canopy-fixture.json').read_text())
    observed=snap()['air_details']
    early=[leaf for leaf in observed if leaf[6]<0.4]
    assert early,observed
    for leaf in early:
        original=geometry[str(leaf[0])]
        assert math.dist(leaf[2:4],original[:2]) < 3 + 8 * leaf[6] + 30 * leaf[6]**2
        assert leaf[5]==original[3]
    print('PASS: browser detachment uses the tree identity, branch position and original green/yellow colour.',flush=True)
    walk_start=time.monotonic()-started
    page.keyboard.down('d');page.wait_for_timeout(420);capture('rig-running-right')
    page.wait_for_timeout(580);page.keyboard.up('d')
    page.keyboard.down('a');page.wait_for_timeout(420);capture('rig-running-left')
    page.wait_for_timeout(680);page.keyboard.up('a')
    page.keyboard.down('Space');page.wait_for_timeout(1000);page.keyboard.up('Space')
    walk_end=time.monotonic()-started
    page.keyboard.press('Escape');mode('paused');capture('smooth-resume-icon')
    click(180,387);page.wait_for_timeout(200);click(180,383);mode('title')
    print('PASS: left/right walking, aiming and the smooth pause/resume control run without errors.',flush=True)
    fixture=json.loads(Path('test-results/ending-fixture.json').read_text())
    page.evaluate('(data)=>localStorage.setItem("snow.campaigns.v1",JSON.stringify(data))',fixture)
    page.reload(wait_until='networkidle')
    page.wait_for_function("window.snowSnapshot?.mode==='title'",timeout=90000)
    click(180,323);mode('slots');click(180,242);mode('continue')
    click(180,338);mode('intro');mode('play')
    page.wait_for_function("window.snowSnapshot.mode==='lost'",timeout=90000)
    loss_start=time.monotonic()-started
    first=snap()
    score=first['score']
    count=first['ending_attached']+first['ending_air']+first['ending_ground']
    assert count==2880 and first['snow_cover']==0
    start_frame=time.monotonic()-started
    page.wait_for_function('window.snowSnapshot.ending_attached<500 && window.snowSnapshot.ending_air>500',timeout=30000)
    falling=snap()
    assert falling['ending_attached']+falling['ending_air']+falling['ending_ground']==count
    assert falling['snow_cover']==0 and falling['score']==score
    falling_frame=time.monotonic()-started
    if not options.no_pause:
        page.keyboard.press('Escape');mode('paused')
        frozen=snap()
        page.wait_for_timeout(500)
        assert snap()['ending_air']==frozen['ending_air'] and snap()['ending_ground']==frozen['ending_ground']
        page.keyboard.press('Escape');mode('lost')
    page.wait_for_function("['snow','done'].includes(window.snowSnapshot.ending_phase)",timeout=30000)
    settled=snap()
    assert settled['ending_attached']==0 and settled['ending_air']==0 and settled['ending_ground']==count
    settled_frame=time.monotonic()-started
    page.wait_for_function('window.snowSnapshot.result_visible',timeout=30000)
    page.wait_for_function('window.snowSnapshot.result_tallied')
    assert snap()['score']==score and snap()['snow_cover']==1
    loss_end=time.monotonic()-started
    capture('winter-leaves-covered')
    print('PASS: every actual leaf lands before snow; frozen scoring holds.' + (' Pause check passed.' if not options.no_pause else ' Continuous art capture.'),flush=True)
    movie=page.video
    context.close()
    Path('test-results/motion-study.json').write_text(json.dumps({'path':str(movie.path()),
        'walk_start':walk_start,'walk_end':walk_end,'loss_start':loss_start,'loss_end':loss_end,
        'start_frame':start_frame,'falling_frame':falling_frame,'settled_frame':settled_frame}))
    browser.close()
assert not errors,errors
print('No browser runtime errors.',flush=True)
