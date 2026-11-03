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
from score_composition import SCORES, compose, QUIET

def vlq(n):
    data=[n&127];n>>=7
    while n: data.insert(0,(n&127)|128);n>>=7
    return bytes(data)

def midi_file(path, bpm, notes):
    tracks=[]
    tempo=round(60000000/bpm)
    tracks.append(b'\x00\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\x00\xff\x2f\x00')
    for channel,program in [(0,10),(1,88),(2,38),(3,98),(4,80),(9,0)]:
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
    rng=np.random.default_rng(config.seed)
    beat_seconds=60/config.bpm; notes=compose(config)
    midi_file(ROOT/'midi'/f'{name}.mid',config.bpm,notes)
    signal=np.zeros(round(64*beat_seconds*RATE))
    for beat,duration,pitch,velocity,ch in notes:
        kind={0:'glass' if config.mood in QUIET or config.mood=='rain' else 'warm',1:'pad',2:'bass',3:'pluck',4:'glass',9:'drum'}[ch]
        sound=voice(pitch,duration*beat_seconds,kind,rng)
        volume={0:.105,1:.060,2:.14 if config.mood in QUIET else .115,3:.065,4:.065,9:.045}[ch]*velocity/64
        begin=round(beat*beat_seconds*RATE);count=min(len(sound),len(signal)-begin)
        signal[begin:begin+count]+=sound[:count]*volume
    # Two quiet circular echoes add depth while preserving an exact loop boundary.
    dry=signal.copy()
    signal+=np.roll(dry,round(beat_seconds*.75*RATE))*.12
    signal+=np.roll(dry,round(beat_seconds*1.5*RATE))*.045
    signal=np.tanh(signal*1.15)/1.15
    if config.mood in QUIET:signal*=.80
    # No hard limiter is reached; these measurements are recorded for review.
    return_info={'bpm':config.bpm,'mood':config.mood,'bars':16,'events':len(notes),
                 'seconds':len(signal)/RATE,'peak':float(abs(signal).max()),'rms':float(np.sqrt(np.mean(signal**2)))}
    encode(name,signal)
    return return_info

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
    catalog={name:score(name,config) for name,config in SCORES.items()}
    import json
    (ROOT/'score_catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')

    for args in [('menu_tap',.09,650,450,.04),('menu_focus',.055,420,520,.02),('upgrade',.35,520,1040,.12),('reset',.23,440,220,.1),('shuffle',.11,100,70,.8),('whirlwind',1.15,170,70,.5),('blower',1.0,110,110,.3),('leaf_saved',.13,830,1100,.02),('leaf_fallen',.12,150,95,.4),('battery_low',.2,330,220,.01),('week_clear',.6,520,1040,.03)]: effect(*args)
    print(f'Generated {len(SCORES)} original sixteen-bar MIDI/Ogg/MP3 scores and eleven effects.')

if __name__=='__main__': main()
