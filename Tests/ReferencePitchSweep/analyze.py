"""Measure production sampler output; numpy is a development dependency only.
Raw mono Float32 is 44,100 Hz. FFT interpolation uses a Hann window.
For each voice measure both one-second windows, and the complete capture.
"""
import argparse
import csv
import math
from pathlib import Path
import numpy as np


def pitch(signal, expected, rate):
    size = 1048576
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(len(signal)), size))
    lo = int(expected * .97 * size / rate)
    hi = int(expected * 1.03 * size / rate) + 1
    index = lo + int(np.argmax(spectrum[lo:hi]))
    if index in (lo, hi - 1):
        raise ValueError('Pitch peak at search boundary')
    logs = np.log(np.maximum(spectrum[index - 1:index + 2], 1e-30))
    shift = .5 * (logs[0] - logs[2]) / (logs[0] - 2 * logs[1] + logs[2])
    # Peak must stand clearly above the surrounding spectrum.
    assert spectrum[index] > 10 * np.median(spectrum[int(expected * .7 * size / rate):int(expected * 1.3 * size / rate)]), 'Ambiguous pitch peak'
    return (index + shift) * rate / size


parser = argparse.ArgumentParser()
parser.add_argument('folder', type=Path)
parser.add_argument('--characterize', action='store_true', help='Report sample behavior without requiring precise-tone limits')
parser.add_argument('--report', type=Path, required=True)
parser.add_argument('--limit', type=float, default=.5)
args = parser.parse_args()
rows = list(csv.DictReader((args.folder / 'manifest.csv').open()))
results = []
for row in rows:
    signal = np.fromfile(args.folder / row['file'], dtype='<f4')
    assert np.all(np.isfinite(signal)) and np.max(np.abs(signal)) < 1
    target = float(row['target_hz'])
    rate = int(float(row.get("sample_rate", 44100)))
    hz = pitch(signal, target, rate)
    early = pitch(signal[:rate], target, rate)
    late = pitch(signal[-rate:], target, rate)
    cents = 1200 * math.log2(hz / target)
    drift = 1200 * math.log2(late / early)
    results.append(dict(row, measured_hz=hz, cents=cents, early_hz=early, late_hz=late, drift_cents=drift))
with args.report.open('w') as output:
    writer = csv.DictWriter(output, fieldnames=list(results[0]))
    writer.writeheader()
    writer.writerows(results)
worst = max(results, key=lambda r: abs(r['cents']))
print(f"Measured {len(results)} voices; max error {worst['cents']:+.5f} cents ({worst['system']}, root={worst['root']}, A4={worst['a4']}, note={worst['note']})")
print(f"Max early/late drift {max(abs(r['drift_cents']) for r in results):.5f} cents")
if not args.characterize:
    failures = [r for r in results if abs(r['cents']) > args.limit or abs(r['drift_cents']) > .1]
    if failures:
        for r in failures[:10]:
            print(f"FAIL {r['system']} root={r['root']} A4={r['a4']} note={r['note']}: {r['cents']:+.5f} cents, drift={r['drift_cents']:.5f}")
        raise SystemExit(f'{len(failures)} voices exceeded accuracy/stability limits')
    print(f'PASS: every measured voice within {args.limit} cents and <0.1-cent drift')
