"""Verify the WAVs produced by both Swift audio check executables. Requires NumPy."""
import math
import pathlib
import struct
import numpy as np

def fundamental(path, target, piano=False):
    data = pathlib.Path(path).read_bytes()
    chunks = {}
    cursor = 12
    while cursor + 8 <= len(data):
        size = struct.unpack_from('<I', data, cursor + 4)[0]
        chunks[data[cursor:cursor + 4]] = data[cursor + 8:cursor + 8 + size]
        cursor += 8 + size + (size & 1)
    kind, channels, rate, _, _, bits = struct.unpack_from('<HHIIHH', chunks[b'fmt '])
    assert kind == 3 and bits == 32, 'Expected floating-point PCM'
    signal = np.frombuffer(chunks[b'data'], dtype='<f4').reshape(-1, channels).mean(axis=1)
    signal = signal[5000:20000] if piano else signal[-rate:]
    size = 524288
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(len(signal)), size))
    frequencies = np.fft.rfftfreq(size, 1 / rate)
    candidates = np.where((frequencies > target * .95) & (frequencies < target * 1.05))[0]
    index = candidates[np.argmax(spectrum[candidates])]
    logs = np.log(spectrum[index - 1:index + 2])
    offset = .5 * (logs[0] - logs[2]) / (logs[0] - 2 * logs[1] + logs[2])
    return (index + offset) * rate / size

for tuning, note in [(415.,69.),(440.,69.),(442.,69.),(443.5,69.),(442.,69.5)]:
    target = tuning * 2 ** ((note - 69) / 12)
    hz = fundamental(f'/tmp/choir-reference-{tuning}-{note}.wav', target)
    cents = 1200 * math.log2(hz / target)
    assert abs(cents) < 1, (tuning, note, cents)
    print(f'PASS reference A4={tuning}, MIDI={note}: {hz:.4f} Hz ({cents:+.3f} cents)')
for note in [69.,69.5]:
    target = 442 * 2 ** ((note - 69) / 12)
    hz = fundamental(f'/tmp/choir-piano-442.0-{note}.wav', target, piano=True)
    cents = 1200 * math.log2(hz / target)
    assert abs(cents) < 5, (note, cents)
    print(f'PASS piano MIDI={note}: {hz:.4f} Hz ({cents:+.3f} cents)')

# E4 targets from characteristic A–E fifths, independently of the Swift implementation.
for system, target in {
    'just': 442 * 3/4,
    'pythagorean': 442 * 3/4,
    'quarterComma': 442 * 5 ** .25 / 2,
    'werckmeisterIII': 442 * 3/4,
    'kirnbergerIII': 442 * 5 ** .25 / 2,
    'vallotti': 442 * 1.5 / 2 / (531441/524288) ** (1/6),
}.items():
    hz = fundamental(f'/tmp/choir-reference-442.0-64.0-{system}.wav', target)
    cents = 1200 * math.log2(hz / target)
    assert abs(cents) < 2, (system, cents)
    print(f'PASS {system} E4: {hz:.4f} Hz ({cents:+.3f} cents)')
