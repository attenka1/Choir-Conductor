"""Development-only spectrum analysis; requires numpy, never used by the app."""
import csv
import math
import pathlib
import sys
import wave
import numpy as np

folder = pathlib.Path(sys.argv[1])
writer = csv.writer(sys.stdout)
writer.writerow(["file", "channels", "sample_rate", "bits", "duration_s", "fundamental_hz", "midi_estimate", "a4_equivalent_hz"])
for path in sorted(folder.glob("note_*.wav"), key=lambda p: int(p.stem.split("_")[1])):
    number = int(path.stem.split("_")[1])
    with wave.open(str(path)) as recording:
        channels, width, rate, frames, _, _ = recording.getparams()
        if width != 2 or rate != 44100:
            raise ValueError(f"Unexpected format: {path}")
        signal = np.frombuffer(recording.readframes(frames), dtype="<i2").reshape(-1, channels).mean(axis=1)
    signal = signal[5000:40000]
    size = 262144
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(len(signal)), size))
    frequencies = np.fft.rfftfreq(size, 1 / rate)
    expected = 440 * 2 ** ((number - 69) / 12)
    candidates = np.where((frequencies > expected * 0.94) & (frequencies < expected * 1.06))[0]
    index = candidates[np.argmax(spectrum[candidates])]
    logs = np.log(spectrum[index-1:index+2])
    offset = 0.5 * (logs[0] - logs[2]) / (logs[0] - 2 * logs[1] + logs[2])
    fundamental = (index + offset) * rate / size
    midi = 69 + 12 * math.log2(fundamental / 440)
    if round(midi) != number:
        raise ValueError(f"Pitch does not match filename: {path}, MIDI={midi}")
    writer.writerow([path.name, channels, rate, width * 8, round(frames/rate, 6), round(fundamental, 3), round(midi, 3), round(fundamental / 2 ** ((number-69)/12), 3)])
