from pathlib import Path
import numpy as np,json,csv,wave
root=Path('Untitled Project/Choir Master/PianoSamples');meta=json.loads((root/'metadata.json').read_text());rows=[]
for m in meta:
 with wave.open(str(root/m['filename'])) as f:
  assert (f.getnchannels(),f.getsampwidth(),f.getframerate(),f.getnframes())==(m['channels'],2,m['sampleRate'],m['frames'])
  d=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32768
  assert np.isfinite(d).all()
  rows.append({'midi':m['midi'],'frames':len(d),'peak':float(np.max(np.abs(d))),'dc':float(np.mean(d)),'stereo_correlation':float(np.corrcoef(d.T)[0,1])})
Path('/tmp/choir-piano-audit/samples.json').write_text(json.dumps(rows,indent=2))
results=[]
for i in range(97):
 data=np.fromfile(f'/tmp/choir-piano-audit/pcm/{i}.f32',dtype='<f4');target=442*2**((36+i/2-69)/12)
 def measure(a):
  n=1048576;spec=np.abs(np.fft.rfft(a*np.hanning(len(a)),n));freq=np.fft.rfftfreq(n,1/44100)
  candidates=np.flatnonzero((freq>target*.96)&(freq<target*1.04));k=candidates[np.argmax(spec[candidates])]
  y=np.log(spec[k-1:k+2]+1e-30);shift=.5*(y[0]-y[2])/(y[0]-2*y[1]+y[2]);return (k+shift)*44100/n
 early=measure(data[22050:66150]);late=measure(data[88200:132300]);whole=measure(data[44100:132300])
 results.append({'note':36+i/2,'target_hz':target,'measured_hz':whole,'cents':float(1200*np.log2(whole/target)),
                 'early_hz':early,'late_hz':late,'window_difference_cents':float(1200*np.log2(late/early))})
with Path('/tmp/choir-piano-audit/piano-pitch.csv').open('w') as f:
 w=csv.DictWriter(f,results[0].keys(),lineterminator='\n');w.writeheader();w.writerows(results)
print('PASS: 25 WAV headers and 97-note spectral characterization (not a pass/fail pitch-accuracy claim)')
