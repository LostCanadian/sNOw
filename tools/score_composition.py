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
    'menu':Score(104,48,'sun',1,HOOK),
    'workshop':Score(112,50,'workshop',2,(4,2,0,2,5,4,1,2)),
    'results':Score(112,48,'sun',7,(2,4,7,4,5,4,2,0)),
    'victory':Score(124,50,'victory',8,(0,2,4,7,9,7,5,4)),
    'winter':Score(66,45,'winter',9,(7,4,2,0,6,4,3,1)),
    'boss':Score(116,45,'storm',6,(0,4,7,4,2,6,4,1)),
    'week_01':Score(118,48,'sun',21,HOOK),
    'week_02':Score(124,50,'sun',22,(0,4,2,5,7,5,4,2)),
    'week_03':Score(102,53,'cloud',23,(2,4,5,4,7,6,4,2)),
    'week_04':Score(98,48,'dusk',24,(4,5,7,5,4,2,1,0)),
    'week_05':Score(88,50,'rain',25,(0,2,4,6,5,4,2,1)),
    'week_06':Score(74,45,'night',26,(0,4,6,7,4,2,1,0)),
    'week_07':Score(126,48,'sun',27,(0,2,5,4,7,9,7,4)),
    'week_08':Score(82,47,'night_storm',28,(0,1,4,6,7,4,3,1)),
    'week_09':Score(90,48,'mist',29,(4,2,1,0,2,5,4,2)),
    'week_10':Score(100,53,'dusk',30,(2,4,7,6,5,4,2,1)),
    'week_11':Score(86,45,'rain',31,(4,2,0,1,2,4,6,5)),
    'week_12':Score(120,50,'sun',32,(0,2,4,7,5,4,2,0)),
}
MINOR={'rain','night','night_storm','storm','winter'}
QUIET={'night','night_storm','winter'}

def instruments(score):
    """Distinct, low-register timbres; the bridge swaps the foreground voice."""
    palettes={
        'sun':(('pulse25','reed','mallet')[score.seed%3],'strings','bass','mallet','flute'),
        'workshop':('mallet','pad','bass','pulse25','reed'),
        'victory':('pulse25','strings','bass','bell','flute'),
        'cloud':('reed','pad','bass','mallet','flute'),
        'dusk':('flute','strings','bass','mallet','reed'),
        'rain':('reed','pad','bass','mallet','flute'),
        'mist':('flute','pad','bass','bell','reed'),
        'night':('flute','pad','bass','bell','triangle'),
        'night_storm':('triangle','strings','bass','mallet','reed'),
        'storm':('pulse50','strings','bass','pulse25','reed'),
        'winter':('triangle','pad','bass','bell','flute'),
    }
    return palettes[score.mood]

def compose(score):
    minor=score.mood in MINOR
    quiet=score.mood in QUIET
    deliberate=quiet or score.mood in {'rain','mist','cloud','dusk'}
    scale=(0,2,3,5,7,8,10) if minor else (0,2,4,5,7,9,11)
    def degree(n):return score.key+scale[n%7]+12*(n//7)
    roots=([0,5,3,4,0,3,1,4,5,3,0,4,1,3,4,0] if minor else
           [0,3,5,4,0,5,1,4,3,4,2,5,1,3,4,0])
    if score.seed%3==0:roots[2],roots[5]=roots[5],roots[2]
    notes=[]
    def add(t,d,p,v,ch):
        if t<64:notes.append((t,min(d,64-t),max(24,min(84,p)),max(1,min(100,v)),ch))
    last_voicing=[score.key,score.key+7,score.key+12]
    last_lead=score.key+12
    for bar,root in enumerate(roots):
        t=bar*4;section=bar//4
        chord=[degree(root+n) for n in (0,2,4)]
        # Close inversions minimize movement between chords. Warm harmony stays
        # under the melody; no constant high seventh chord or busy top arpeggio.
        candidates=[]
        for inversion in range(3):
            voicing=sorted(chord[inversion:]+[p+12 for p in chord[:inversion]])
            for octave in (-12,0):
                v=[p+octave for p in voicing]
                if min(v)>=42 and max(v)<=69:candidates.append(v)
        voiced=min(candidates,key=lambda v:sum(abs(a-b) for a,b in zip(v,last_voicing))) if candidates else chord
        last_voicing=voiced
        for pitch in voiced[:2 if quiet else 3]:add(t,3.95,pitch,25 if quiet else 28,1)
        bass=degree(root)-12
        rhythm=([(0,1.8,0),(2.5,1.25,7)] if deliberate else
                [(0,.9,0),(1.5,.4,7),(2.25,.8,0),(3.5,.35,12)])
        for onset,dur,offset in rhythm:add(t+onset,dur,bass+offset,66 if quiet else 62,2)
        # Two-bar questions and answers. A repeated hook has space around its
        # held notes; the bridge and last refrain vary its contour and cadence.
        if quiet:rhythm=[.5,2.25] if bar%2==0 else [0,2.5]
        elif deliberate:rhythm=[0,1.25,2.75] if bar%2==0 else [.5,2.0]
        else:rhythm=[0,.75,1.5,2.5] if bar%2==0 else [.25,1.5,2.25]
        phrase=score.motif if section!=2 else tuple(reversed(score.motif[2:]+score.motif[:2]))
        for step,onset in enumerate(rhythm):
            ix=(step+(bar%2)*4+(1 if section==1 else 0))%8
            n=phrase[ix]
            if section==3 and bar%2==0 and step==1:n+=1
            if bar%4==3 and step==len(rhythm)-1:n=0 if section==3 else 1
            pitch=degree(n)+12
            while pitch-last_lead>8:pitch-=12
            while last_lead-pitch>8:pitch+=12
            pitch=max(55 if quiet else 60,min(76 if quiet else 81,pitch))
            last_lead=pitch
            next_onset=rhythm[step+1] if step+1<len(rhythm) else 3.85
            dur=max(.2,next_onset-onset-(.14 if deliberate else .18))
            add(t+onset,dur,pitch,52 if quiet else (69 if step==0 else 60),0)
        # Replies enter in the gaps, rather than running over the melody.
        if bar%2 and section!=2:
            for step,onset in enumerate([1.0,3.5] if not quiet else [1.5]):
                add(t+onset,.35 if not quiet else .7,voiced[(step+score.seed)%3]+12,25 if quiet else 31,3)
        if section in (1,3) and bar%4==2 and not quiet:
            add(t+3.4,.45,degree(2)+12,30,4)
        if score.mood!='winter':
            for onset in ([0,2] if deliberate else [0,1,2,3]):add(t+onset,.065,42,13 if quiet else 20,9)
            for onset in ([0] if quiet else [0,2.5]):add(t+onset,.16,36,39 if deliberate else 52,9)
            for onset in ([3] if deliberate else [1,3]):add(t+onset,.10,37 if deliberate else 38,19 if deliberate else 29,9)
            if bar%4==3 and not deliberate:add(t+3.5,.10,38,26,9)
    return sorted(notes,key=lambda n:(n[0],n[4],n[2]))
