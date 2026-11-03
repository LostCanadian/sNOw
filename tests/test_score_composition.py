"""Musical form, mood contrast and encoded-loop checks for the original scores."""
import importlib.util,json,subprocess,unittest
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('score_composition',ROOT/'tools/score_composition.py')
import sys
score=importlib.util.module_from_spec(spec);sys.modules[spec.name]=score;spec.loader.exec_module(score)
class CompositionTests(unittest.TestCase):
    def test_individual_weekly_scores(self):
        weekly=[score.SCORES[f'week_{w:02d}'] for w in range(1,13)]
        self.assertEqual(len({tuple(score.compose(s)) for s in weekly}),12)
    def test_form_and_headroom(self):
        catalog=json.loads((ROOT/'assets/audio/score_catalog.json').read_text())
        self.assertEqual(set(catalog),set(score.SCORES))
        for name,config in score.SCORES.items():
            with self.subTest(name=name):
                notes=score.compose(config)
                self.assertTrue(all(0<=t<64 and 0<d<=64-t and 24<=pitch<=100 and 0<v<=110 for t,d,pitch,v,ch in notes))
                self.assertTrue({0,1,2,3}<=set(n[4] for n in notes))
                # The bridge must bring different melodic content, not a copy of A.
                sections=[[(round(t-bar*16,3),p) for t,d,p,v,ch in notes if ch==0 and bar*16<=t<(bar+1)*16] for bar in range(4)]
                self.assertNotEqual(sections[0],sections[2]);self.assertNotEqual(sections[0],sections[3])
                info=catalog[name]
                self.assertEqual(info['bars'],16);self.assertEqual(info['events'],len(notes))
                self.assertAlmostEqual(info['seconds'],64*60/config.bpm,places=3)
                self.assertLess(info['peak'],.8);self.assertGreater(info['rms'],.015)
                self.assertEqual((ROOT/f'assets/audio/midi/{name}.mid').read_bytes()[:4],b'MThd')
                for filename in [f'{name}.ogg',f'streams/{name}.mp3data']:
                    path=ROOT/'assets/audio'/filename
                    data=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar','22050','-']),dtype='<f4')
                    self.assertAlmostEqual(len(data)/22050,info['seconds'],delta=.12)
                    self.assertLess(float(abs(data).max()),.9)
                    self.assertGreater(float(np.sqrt(np.mean(data**2))),.01)
    def test_mood_contrast(self):
        sun=score.SCORES['week_01'];night=score.SCORES['week_06'];rain=score.SCORES['week_05']
        self.assertGreater(sun.bpm,rain.bpm);self.assertGreater(rain.bpm,night.bpm)
        lead=lambda cfg:[n for n in score.compose(cfg) if n[4]==0]
        self.assertLess(len(lead(night)),len(lead(sun)))
        self.assertLess(np.mean([n[2] for n in lead(night)]),np.mean([n[2] for n in lead(sun)]))
        night_bass=[n[2] for n in score.compose(night) if n[4]==2]
        self.assertLess(min(night_bass),36)
        self.assertIn(rain.mood,score.MINOR)
if __name__=='__main__':unittest.main()
