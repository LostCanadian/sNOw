#!/usr/bin/env python3
"""Original sNOw score and effects. Deterministic offline synthesis; no samples/soundfont.

Regenerate with Python + NumPy + ffmpeg. MIDI files preserve the authored note events;
Ogg Vorbis is the playback rendering because Godot does not ship a MIDI synthesizer.
"""
from pathlib import Path
import math
import struct
import subprocess
import tempfile
import wave
import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
# Name, BPM, root progression, melody rhythm/pitches, instrumentation, deterministic seed.
SCORES = {
 'menu': (92,[48,53,57,55,48,53,50,55],[0,4,7,11,9,7,4,2], 'warm', 1),
 'workshop': (108,[48,55,53,55,48,57,53,55],[7,4,0,4,9,7,2,4], 'pluck', 2),
 'spring': (100,[48,53,48,55,57,53,50,55],[0,4,7,9,12,7,4,2], 'warm', 3),
 'autumn': (106,[50,55,53,57,50,55,53,57],[0,3,7,10,9,7,5,3], 'mellow', 4),
 'frost': (112,[45,50,48,52,45,53,50,52],[0,3,7,12,10,7,5,2], 'glass', 5),
 'boss': (128,[45,45,53,52,45,48,50,52],[0,7,12,7,3,10,7,2], 'storm', 6),
 'results': (104,[48,53,55,48,57,53,55,48],[4,7,12,7,9,7,4,0], 'pluck', 7),
 'victory': (96,[48,53,55,48,57,53,55,48],[0,4,7,12,16,12,9,7], 'warm', 8),
 'winter': (68,[45,50,48,52,45,50,53,52],[12,7,3,0,10,7,5,2], 'glass', 9),
}

def vlq(n):
    data=[n&127];n>>=7
    while n: data.insert(0,(n&127)|128);n>>=7
    return bytes(data)

def midi_file(path, bpm, notes):
    tracks=[]
    tempo=round(60000000/bpm)
    tracks.append(b'\x00\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\x00\xff\x2f\x00')
    for channel,program in [(0,10),(1,88),(2,38),(9,0)]:
        events=[(0,bytes([0xc0|channel,program]))]
        for beat,duration,pitch,velocity,ch in notes:
            if ch==channel:
                events.extend([(round(beat*480),bytes([0x90|ch,pitch,velocity])),(round((beat+duration)*480),bytes([0x80|ch,pitch,0]))])
        events.sort(key=lambda e:e[0]); previous=0; track=b''
        for tick,data in events:
            track+=vlq(tick-previous)+data;previous=tick
        track+=b'\x00\xff\x2f\x00';tracks.append(track)
    path.write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(tracks),480)+b''.join(b'MTrk'+struct.pack('>I',len(t))+t for t in tracks))

def voice(pitch, duration, kind, rng):
    t=np.arange(max(1,round(duration*RATE)))/RATE
    f=440*2**((pitch-69)/12)
    phase=t*f*math.tau
    if kind=='bass':
        signal=np.arcsin(np.sin(phase))*2/math.pi
        envelope=np.minimum(1,t/0.008)*np.minimum(1,(duration-t)/0.045)*np.exp(-t*1.4)
    elif kind=='pad':
        signal=np.sin(phase)*.65+np.sin(phase*2)*.13
        envelope=np.minimum(1,t/0.12)*np.minimum(1,(duration-t)/.16)*.5
    elif kind=='drum':
        signal=rng.uniform(-1,1,len(t)) if pitch!=36 else np.sin(math.tau*(65*t-30*t*t))
        envelope=np.exp(-t*(55 if pitch==42 else 25))*np.minimum(1,t/.002)
    else:
        # A softened pulse, not a full-amplitude square wave, leaves room for effects.
        signal=np.sin(phase)+np.sin(phase*3)*.16+np.sin(phase*5)*.055
        if kind=='glass': signal=np.sin(phase)*.7+np.sin(phase*2)*.3+np.sin(phase*4)*.08
        envelope=np.minimum(1,t/.006)*np.minimum(1,(duration-t)/.035)*np.exp(-t*(4.5 if kind=='pluck' else 2.6))
    return signal*envelope

def encode(name, signal):
    # Fixed headroom: keep layers under 0 dBFS, even during ability playback.
    signal=np.clip(signal,-.95,.95)
    with tempfile.TemporaryDirectory(prefix='snow-audio-') as d:
        wav=Path(d)/'render.wav'
        with wave.open(str(wav),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE)
            w.writeframes((signal*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(ROOT/f'{name}.ogg')],check=True)
        if name in SCORES:
            (ROOT/'streams').mkdir(exist_ok=True)
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libmp3lame','-q:a','4','-f','mp3',str(ROOT/'streams'/f'{name}.mp3data')],check=True)

def score(name, config):
    bpm,roots,motif,kind,seed=config;rng=np.random.default_rng(seed)
    beat_seconds=60/bpm; notes=[]
    for bar,root in enumerate(roots):
        start=bar*4; minor=kind in ('mellow','glass','storm')
        chord=[root,root+(3 if minor else 4),root+7]
        for pitch in chord: notes.append((start,3.9,pitch+12,35,1))
        for step in range(4 if kind!='storm' else 8):
            dur=1 if kind!='storm' else .5
            notes.append((start+step*dur,dur*.78,root+(12 if step%2 else 0),66,2))
        for step in range(8):
            if name=='winter' and step%2: continue
            pitch=root+12+motif[(step+bar%2*2)%8]
            notes.append((start+step*.5,.38 if name!='winter' else .75,pitch,64 if step%2==0 else 49,0))
        if name!='winter':
            for step in range(8): notes.append((start+step*.5,.07,42,25,9))
            for step in [0,2]: notes.append((start+step,.14,36,60,9))
            for step in [1,3]: notes.append((start+step,.12,38,28,9))
    midi_file(ROOT/'midi'/f'{name}.mid',bpm,notes)
    signal=np.zeros(round(32*beat_seconds*RATE))
    for beat,duration,pitch,velocity,ch in notes:
        sound=voice(pitch,duration*beat_seconds,'drum' if ch==9 else ('pad' if ch==1 else ('bass' if ch==2 else kind)),rng)
        volume={0:.115,1:.075,2:.11,9:.045}[ch]*velocity/64
        begin=round(beat*beat_seconds*RATE);count=min(len(sound),len(signal)-begin)
        signal[begin:begin+count]+=sound[:count]*volume
    signal[:110]*=np.linspace(0,1,110);signal[-220:]*=np.linspace(1,0,220)
    encode(name,signal)

def effect(name,duration,base,end,noise=0,seed=0):
    rng=np.random.default_rng(seed);t=np.arange(round(duration*RATE))/RATE
    phase=math.tau*(base*t+(end-base)*t*t/(2*duration))
    signal=np.sin(phase)*.55+np.sin(phase*2)*.12+rng.uniform(-1,1,len(t))*noise
    envelope=np.minimum(1,t/.009)*np.minimum(1,(duration-t)/.035)
    if name!='blower': envelope*=np.exp(-t/max(.03,duration)*2)
    else: envelope=np.ones(len(t));signal*=.55+.05*np.sin(t*math.tau*12)
    if name=='shuffle': signal=np.convolve(rng.uniform(-1,1,len(t)),np.ones(7)/7,mode='same')
    if name=='whirlwind': signal+=np.sin(math.tau*(280*t+180*t*t))*.2
    encode(name,signal*envelope*.33)

def main():
    (ROOT/'midi').mkdir(parents=True,exist_ok=True)
    for name,config in SCORES.items():
        score(name,config)

    for args in [('menu_tap',.09,650,450,.04),('menu_focus',.055,420,520,.02),('upgrade',.35,520,1040,.12),('reset',.23,440,220,.1),('shuffle',.11,100,70,.8),('whirlwind',1.15,170,70,.5),('blower',1.0,110,110,.3),('leaf_saved',.13,830,1100,.02),('leaf_fallen',.12,150,95,.4),('battery_low',.2,330,220,.01),('week_clear',.6,520,1040,.03)]: effect(*args)
    print('Generated nine original MIDI scores, nine Ogg music loops and eleven effects.')

if __name__=='__main__': main()
