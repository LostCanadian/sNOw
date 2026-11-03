#!/usr/bin/env python3
"""Run native regression scripts and reject engine errors even when Godot exits zero."""
import argparse,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('tests',nargs='*');parser.add_argument('--logs',default='work/godot-tests');args=parser.parse_args()
    output=ROOT/args.logs;output.mkdir(parents=True,exist_ok=True)
    tests=[ROOT/t for t in args.tests] if args.tests else sorted((ROOT/'tests').glob('test_*.gd'))
    failures=[];total=0
    for test in tests:
        result=subprocess.run(['bash',str(ROOT/'tools/godot.sh'),'--headless','--script',str(test.relative_to(ROOT))],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        (output/(test.name+'.log')).write_text(result.stdout)
        reports=re.findall(r'(\d+) checks, (\d+) failures',result.stdout)
        engine_error=re.search(r'^(?:SCRIPT ERROR|ERROR):',result.stdout,re.M)
        bad=result.returncode or not reports or int(reports[-1][1]) or engine_error
        if reports:total+=int(reports[-1][0])
        if bad:
            failures.append(test.name)
            reason=engine_error.group(0) if engine_error else 'failed/incomplete checks'
            print(f'FAIL: {test.name}: {reason}; see {output/test.name}.log',flush=True)
        else:print(f'PASS: {test.name}: {reports[-1][0]} checks',flush=True)
    print(f'{len(tests)} scripts; {total} checks; {len(failures)} failures',flush=True)
    return bool(failures)
if __name__=='__main__':sys.exit(main())
