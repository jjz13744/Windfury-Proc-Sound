#!/usr/bin/env python3
"""Reproducible Windfury audio preparation. No movie/game samples are used.
Original Energy Blade waveform is generated from oscillators and filtered noise.
This build script and the original waveform may be used, modified, and distributed
without restriction. Existing third-party source assets retain their original licensing status.
"""
from pathlib import Path
import subprocess, json, hashlib, shutil
import numpy as np
from scipy import signal
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT/'sources'; OUT = ROOT/'sounds'; OUT.mkdir(exist_ok=True)
SR=44100

def decode(path):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar',str(SR),'-ac','1','-']),dtype='<f4').astype(float)

def finish(x):
    # Trim only near-silence. Retain 15 ms padding, then smooth edges.
    a=np.flatnonzero(np.abs(x)>max(np.max(np.abs(x))*.005,.0001))
    if len(a): x=x[max(0,a[0]-662):min(len(x),a[-1]+662)]
    x=x-np.mean(x)
    n=min(441,len(x)//10)
    x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)
    rms=np.sqrt(np.mean(x*x)); peak=np.max(np.abs(x))
    x*=min(10**(-21/20)/max(rms,1e-8),10**(-5/20)/max(peak,1e-8))
    return x

def save(id,x):
    x=finish(x); path=OUT/(id+'.ogg')
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','1','-i','pipe:0','-c:a','libvorbis','-q:a','4','-map_metadata','-1',str(path)],input=x.astype('<f4').tobytes(),check=True)
    y=decode(path)
    return {'filename':path.name,'duration':round(len(y)/SR,3),'sample_rate':SR,'channels':1,'codec':'Vorbis','peak_dbfs':round(20*np.log10(np.max(np.abs(y))),2),'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(y*y))),2),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

manifest=[]
def add(id,name,x,source):
    manifest.append({'id':id,'name':name,**save(id,x),**source})

# U.S. Fish and Wildlife Service recording, specifically identified as an
# official-duty public-domain federal work on its archival source page.
w=decode(SOURCES/'wolf-fws.ogg')[:int(2.8*SR)]
w[:int(.03*SR)]*=np.linspace(0,1,int(.03*SR))
w[-int(.25*SR):]*=np.linspace(1,0,int(.25*SR))
add('wolf_howl','Wolf Howl',w,{'author':'U.S. Fish and Wildlife Service','original_title':'Wolf howls','source_url':'https://commons.wikimedia.org/wiki/File:Wolf_howls.ogg','download_url':'https://upload.wikimedia.org/wikipedia/commons/8/87/Wolf_howls.ogg','source_filename':'wolf-fws.ogg','license':'Public domain: U.S. federal government official-duty work (PD-USGov-FWS)','license_url':'https://commons.wikimedia.org/wiki/File:Wolf_howls.ogg','changes':'First 2.8 seconds excerpted; mono conversion, 44.1 kHz resampling, level adjustment, edge fades, Vorbis encoding. Original file SHA1 verified against source metadata: 44ce16c609c16ce8ae05b4da61179bf6c9c4ce09.'})
add('chicken','Chicken',decode(SOURCES/'chicken.mp3'),{'author':'Rudmer_Rotteveel','original_title':'Chicken Single Alarm Call','source_url':'https://freesound.org/people/Rudmer_Rotteveel/sounds/316920/','download_url':'https://cdn.freesound.org/previews/316/316920_4921277-hq.mp3','source_filename':'chicken.mp3','license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','changes':'Mono conversion, near-silence trimming, level adjustment, edge fades, Vorbis encoding.'})
# A fresh, original energy-blade swish: buzzing oscillators, Doppler pitch sweep,
# filtered deterministic noise, and a short attack/tail. No reference audio used.
t=np.arange(int(SR*1.18))/SR; rng=np.random.default_rng(59201)
sweep=np.exp(-((t-.38)/.18)**2)
f=95+110*sweep+45*np.exp(-t/0.055)
phase=2*np.pi*np.cumsum(f)/SR
hum=sum(np.sin(k*phase + .4*np.sin(2*np.pi*(2.8+k*.1)*t))/(k**1.15) for k in range(1,12))
hum+=.24*np.sin(2*np.pi*54*t)+.12*np.sin(2*np.pi*218*t)
noise=signal.sosfilt(signal.butter(3,[420,4200],btype='band',fs=SR,output='sos'),rng.standard_normal(len(t)))
env=(1-np.exp(-t/.012))*np.minimum(1,np.maximum(0,(1.18-t)/.27))
x=(.38*hum*(.25+.75*sweep)+noise*(.025+.60*sweep))*env
# A brief ignition transient, not a blast or copyrighted character/movie cue.
x+=.12*np.sin(2*np.pi*np.cumsum(520*np.exp(-t/.045)+130)/SR)*np.exp(-t/0.05)
add('lightsaber','Sci-fi blade',x,{'author':'Original procedural audio created for this addon','original_title':'Energy Blade','source_url':None,'source_filename':'tools/prepare_audio.py','license':'Original; unrestricted permission to use, modify and redistribute','license_url':None,'changes':'Original deterministic synthesis from oscillators and filtered noise; no external audio samples. Level adjustment, fades, Vorbis encoding.'})
choices=[
('laser_pulse','Laser Pulse','laser1.mp3'),
('laser_burst','Laser Burst','laser4.mp3'),
('laser_zing','Laser Zing','laser9.mp3'),
('phaser_drop','Phaser Drop','phaserDown1.mp3'),
('phaser_rise','Phaser Rise','phaserUp3.mp3'),
('power_up','Power-Up','powerUp4.mp3'),
('arcade_bonus','Arcade Bonus','powerUp8.mp3'),
('victory_ping','Victory Ping','powerUp12.mp3'),
('high_swoop','High Swoop','highUp.mp3'),
('bass_drop','Bass Drop','lowDown.mp3'),
('triple_boop','Triple Boop','lowThreeTone.mp3'),
('happy_blip','Happy Blip','pepSound3.mp3'),
('phase_jump','Phase Jump','phaseJump4.mp3'),
('space_crackle','Space Crackle','spaceTrash1.mp3'),
('three_tone','Three-Tone Chime','threeTone1.mp3'),
('electric_zap','Electric Zap','zap1.mp3'),
('double_zap','Double Zap','zapTwoTone.mp3'),
]
for id,name,file in choices:
 add(id,name,decode(SOURCES/'kenney_digital'/file),{'author':'Kenney Vleugels (Kenney.nl)','original_title':'63 Digital sound effects (lasers, phasers, space etc.)','source_url':'https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc','download_url':'https://opengameart.org/sites/default/files/Digital_SFX_Set.zip','source_filename':file,'license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','changes':'Mono conversion, near-silence trimming, level adjustment, edge fades, Vorbis encoding.'})
assert len(manifest)==20 and len({x['sha256'] for x in manifest})==20
(ROOT/'sounds-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ROOT/'SoundCatalog.lua').write_text('-- 20 bundled sound choices. Paths are relative to the addon folder.\nreturn {\n'+''.join('  { id = "'+m['id']+'", name = "'+m['name']+'", file = "Sounds\\\\'+m['filename']+'" },\n' for m in manifest)+'}\n')
print(json.dumps([{'id':m['id'],'duration':m['duration'],'peak_dbfs':m['peak_dbfs'],'bytes':m['bytes']} for m in manifest],indent=2))
