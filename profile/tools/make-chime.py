#!/usr/bin/env python3
"""Original soft startup chord; no Apple audio samples. Deterministic PCM synthesis."""
import math, wave, struct
from pathlib import Path
rate=48000
duration=1.65
notes=[(196.00,0.0,0.42),(293.66,0.035,0.24),(392.00,0.065,0.2),(493.88,0.09,0.14)]
samples=[]
for n in range(int(rate*duration)):
    t=n/rate
    sample=0
    for hz,delay,weight in notes:
        age=t-delay
        if age<0: continue
        envelope=(1-math.exp(-age*28))*math.exp(-age*2.5)*min(1,(duration-t)/0.22)
        sample+=weight*envelope*(math.sin(2*math.pi*hz*age)+0.12*math.sin(4*math.pi*hz*age))
    samples.append(struct.pack('<hh',int(sample*8500),int(sample*8500)))
path=Path(__file__).resolve().parents[1]/'assets/sounds/startup.wav'
path.parent.mkdir(parents=True,exist_ok=True)
with wave.open(str(path),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(samples))
