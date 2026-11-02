"""Real input review of paper workshop, checkpoint navigation and reset cancellation."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
errors=[]
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
 page=b.new_page(viewport={'width':540,'height':960})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.goto('http://localhost:8000/test/?test=1');page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
 fixture=json.loads(Path('test-results/ending-fixture.json').read_text())
 page.evaluate('(data)=>localStorage.setItem("snow.campaigns.v1",JSON.stringify(data))',fixture)
 page.reload();page.wait_for_function('window.snowSnapshot?.mode==="title"',timeout=90000)
 def mode(value):page.wait_for_function('v=>window.snowSnapshot.mode===v',arg=value)
 def snap():return page.evaluate('window.snowSnapshot')
 def click(label=None,name=None):
  page.wait_for_timeout(150)
  button=next(x for x in snap()['ui_buttons'] if (x['text']==label if label else x['name']==name))
  x,y,w,h=button['rect'];canvas=page.locator('canvas').bounding_box()
  page.mouse.click(canvas['x']+(x+w/2)/360*canvas['width'],canvas['y']+(y+h/2)/640*canvas['height'])
 def capture(name):page.locator('canvas').screenshot(path=f'test-results/{name}.png')
 click('Continue / New game');mode('slots');click('Full canopy ending\nWeek 12 · Gale');mode('continue')
 click('Upgrades');mode('workshop');page.wait_for_timeout(600);capture('paper-workshop-boots')
 for branch in [1,2,0]:
  click(name=f'Equipment{branch}')
  page.wait_for_function('v=>window.snowSnapshot.selected_upgrade[0]===v',arg=branch)
  page.wait_for_timeout(450)
  capture(f'paper-workshop-{branch}')
 before=snap()['owned'];points=snap()['points']
 click(name='ResetUpgrades');mode('reset_upgrades');capture('paper-reset-confirmation')
 click('Cancel');mode('workshop');assert snap()['owned']==before and snap()['points']==points
 click('Done');mode('continue');capture('continue-with-upgrades')
 click('Continue');mode('intro');mode('play')
 page.keyboard.press('Escape');mode('paused');click('Restart current level')
 click('Upgrades');mode('workshop');click('Done');mode('paused')
 click('Cancel');mode('play')
 assert snap()['owned']==before
 page.keyboard.press('Escape');mode('paused');click('Exit to menu');click('Exit');mode('title')
 click('Continue / New game');mode('slots');click('Slot 2 · New save');mode('name');click('Start week 1');mode('intro')
 page.wait_for_timeout(800);page.keyboard.press('Space');mode('play')
 page.keyboard.down('Space');page.wait_for_function('window.snowSnapshot.low_power',timeout=60000)
 assert snap()['blowing']
 page.wait_for_function('window.snowSnapshot.low_power && window.snowSnapshot.charge>.25',timeout=30000)
 capture('held-blower-low-power')
 page.keyboard.up('Space');page.wait_for_timeout(250);page.keyboard.down('Space')
 page.wait_for_function('window.snowSnapshot.blowing && !window.snowSnapshot.low_power')
 page.wait_for_function('window.snowSnapshot.low_power',timeout=30000)
 page.wait_for_function('window.snowSnapshot.blowing && !window.snowSnapshot.low_power && window.snowSnapshot.charge>.95',timeout=60000)
 page.keyboard.up('Space')
 print('PASS: held depletion keeps a recharging draft; release/press and full charge both restore full power.')
 b.close()
assert not errors,errors
print('PASS: paper tabs, all three branches, reset cancellation, Continue and live restart review; no browser errors.')
