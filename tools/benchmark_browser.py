#!/usr/bin/env python3
"""Read-only frame timing of real menu/game input in release Web builds.

Use identical viewport/browser flags for comparisons. Software WebGL numbers are
comparative evidence, not physical phone frame rates. No timing threshold is used.
"""
import argparse,base64,json,statistics
from pathlib import Path
from playwright.sync_api import sync_playwright
p=argparse.ArgumentParser();p.add_argument('urls',nargs='+');p.add_argument('--frames',type=int,default=120);p.add_argument('--output',default='test-results/browser-performance.json');args=p.parse_args()
results=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
    for url in args.urls:
        context=browser.new_context(viewport={'width':360,'height':640});page=context.new_page();errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
        page.goto(url);page.locator('#status').wait_for(state='hidden',timeout=90000);page.wait_for_timeout(1200)
        session=page.context.new_cdp_session(page);session.send('Performance.enable',{'timeDomain':'threadTicks'})
        def cpu():return next(m['value'] for m in session.send('Performance.getMetrics')['metrics'] if m['name']=='ThreadTime')
        def measure():
            cpu_start=cpu()
            times=page.evaluate('''count=>new Promise(resolve=>{let times=[],last=0;function step(t){if(last)times.push(t-last);last=t;if(times.length>=count)resolve(times);else requestAnimationFrame(step);}requestAnimationFrame(step);})''',args.frames)
            cpu_ms=(cpu()-cpu_start)*1000/len(times)
            times.sort();return {'thread_cpu_ms':round(cpu_ms,2),'mean_ms':round(statistics.mean(times),2),'p95_ms':round(times[int(len(times)*.95)-1],2),'fps':round(1000/statistics.mean(times),1),'frames':len(times)}
        report={'url':url,'canvas':page.locator('canvas').evaluate('(c)=>({width:c.width,height:c.height,dpr:devicePixelRatio})'),'menu':measure()}
        for x,y in [(180,324),(180,242),(180,342)]:page.mouse.click(x,y);page.wait_for_timeout(900)
        page.wait_for_timeout(900);page.keyboard.press('Space');page.wait_for_timeout(1200)
        report['play']=measure();report['errors']=errors
        shot=page.context.new_cdp_session(page).send('Page.captureScreenshot',{'format':'png','captureBeyondViewport':False})
        image_path=Path(args.output).with_name(f'benchmark-{len(results)}.png');image_path.parent.mkdir(parents=True,exist_ok=True);image_path.write_bytes(base64.b64decode(shot['data']))
        assert not errors,errors
        results.append(report);print(json.dumps(report),flush=True);context.close()
    browser.close()
Path(args.output).parent.mkdir(parents=True,exist_ok=True)
Path(args.output).write_text(json.dumps({'renderer':'Chromium SwiftShader, 360x640','results':results},indent=2)+'\n')
