"""Original 16-bar paper-valley tunes: shared hook, individual weekly arrangements.
No samples or borrowed melodies. Events are (beat, length, MIDI note, velocity, channel).
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class Score:
    bpm:int
    key:int
    mood:str
    seed:int
    motif:tuple

HOOK=(0,2,4,5,7,4,2,1)
SCORES={
    'menu':Score(112,48,'sun',1,HOOK),
    'workshop':Score(126,50,'workshop',2,(4,2,0,2,5,4,1,2)),
    'results':Score(120,48,'sun',7,(2,4,7,4,5,4,2,0)),
    'victory':Score(132,50,'victory',8,(0,2,4,7,9,7,5,4)),
    'winter':Score(76,45,'winter',9,(7,4,2,0,6,4,3,1)),
    'boss':Score(140,45,'storm',6,(0,4,7,4,2,6,4,1)),
    'week_01':Score(124,48,'sun',21,HOOK),
    'week_02':Score(130,50,'sun',22,(0,4,2,5,7,5,4,2)),
    'week_03':Score(116,53,'cloud',23,(2,4,5,4,7,6,4,2)),
    'week_04':Score(114,48,'dusk',24,(4,5,7,5,4,2,1,0)),
    'week_05':Score(102,50,'rain',25,(0,2,4,6,5,4,2,1)),
    'week_06':Score(88,45,'night',26,(0,4,6,7,4,2,1,0)),
    'week_07':Score(132,48,'sun',27,(0,2,5,4,7,9,7,4)),
    'week_08':Score(108,47,'night_storm',28,(0,1,4,6,7,4,3,1)),
    'week_09':Score(108,48,'mist',29,(4,2,1,0,2,5,4,2)),
    'week_10':Score(118,53,'dusk',30,(2,4,7,6,5,4,2,1)),
    'week_11':Score(106,45,'rain',31,(4,2,0,1,2,4,6,5)),
    'week_12':Score(128,50,'sun',32,(0,2,4,7,5,4,2,0)),
}
MINOR={'rain','night','night_storm','storm','winter'}
QUIET={'night','night_storm','winter'}

def compose(score):
    minor=score.mood in MINOR
    scale=(0,2,3,5,7,8,10) if minor else (0,2,4,5,7,9,11)
    def degree(n):return score.key+scale[n%7]+12*(n//7)
    # A/A'/B/A'' forms a full 16-bar loop. Diatonic seventh chords, a bridge,
    # a dominant turnaround and a recognisable hook replace one repeated pattern.
    roots=([0,5,3,4,0,3,1,4,5,3,0,4,1,3,4,0] if minor else
           [0,3,5,4,0,5,1,4,3,4,2,5,1,3,4,0])
    if score.seed%3==0:roots[2],roots[5]=roots[5],roots[2];roots[10]=6 if minor else 2
    notes=[]
    def add(t,d,p,v,ch):
        if t<64:notes.append((t,min(d,64-t),max(24,min(100,p)),max(1,min(110,v)),ch))
    quiet=score.mood in QUIET
    for bar,root in enumerate(roots):
        t=bar*4;section=bar//4
        chord=[degree(root+n) for n in (0,2,4,6)]
        # Alternating inversions connect the harmony smoothly.
        voiced=[p+12 if p<score.key+5 else p for p in chord]
        for p in voiced:add(t+0.02,3.85,p,30 if quiet else 34,1)
        # Warm off-beat bass with fifths, octave answers, and a step into next bar.
        bass=degree(root)-12
        bass_rhythm=[(0,0.82,0), (1.5,0.35,7), (2,0.75,12), (3.25,0.43,7)]
        if quiet:bass_rhythm=[(0,1.65,0),(2.5,1.1,7)]
        for onset,dur,offset in bass_rhythm:add(t+onset,dur,bass+offset,71 if quiet else 67,2)
        if bar%4==3:add(t+3.75,0.20,degree(roots[(bar+1)%16])-13,48,2)
        # The hook is phrased in two-bar questions and answers, with rests,
        # anticipations and occasional sixteenth pickups. B is a real contrast.
        rhythm=([0,.5,1.25,1.75,2.5,3.0] if bar%2==0 else [0,.75,1.5,2.0,2.75,3.5])
        phrase=score.motif if section!=2 else tuple(reversed(score.motif[2:]+score.motif[:2]))
        if quiet:rhythm=[0,1.25,2.75] if bar%2==0 else [.5,2.0,3.5]
        for step,onset in enumerate(rhythm):
            ix=(step+bar%2*3+(1 if section==1 else 0))%8
            n=phrase[ix]
            if bar%4==3 and step==len(rhythm)-1:n=0 if section==3 else 1
            # Bridge lives lower; the last refrain opens back into the top octave.
            octave=12 if section==2 or quiet else 24
            pitch=degree(n)+octave
            dur=(rhythm[step+1]-onset)*.78 if step+1<len(rhythm) else .34
            add(t+onset,dur,pitch,58 if quiet else (75 if step==0 else 60+step%3*4),0)
            if section==3 and step in (1,4) and not quiet:add(t+onset+.25,.16,degree(n+1)+octave,40,0)
        # Arpeggio and a replying second voice enter and leave between phrases.
        arp_steps=4 if quiet else 8
        if section!=0 or bar%2:
            for step in range(arp_steps):
                index=(step+(score.seed%4))%4
                p=chord[index]+12
                add(t+step*(4/arp_steps)+.25,.18 if not quiet else .5,p,26 if quiet else 32,3)
        if section in (1,3) and bar%2 and not quiet:
            for step,n in enumerate((4,5,2,1)):
                add(t+step*.5+.25,.32,degree(n)+12,37,4)
        # Sparse night hats, bouncy daytime backbeat, and small four-bar fills.
        if score.mood!='winter':
            for step in range(8):
                if quiet and step%2:continue
                add(t+step*.5,.07,42,17 if quiet else (28 if step%2 else 21),9)
            for onset in ([0,2.5] if quiet else [0,1.75,2.5]):add(t+onset,.15,36,43 if quiet else 61,9)
            for onset in [1,3]:add(t+onset,.12,37 if quiet or score.mood=='rain' else 38,22 if quiet else 35,9)
            if bar%4==3 and not quiet:
                for onset in [3.25,3.5,3.75]:add(t+onset,.085,38,25+int(onset*3),9)
    return sorted(notes,key=lambda n:(n[0],n[4],n[2]))
