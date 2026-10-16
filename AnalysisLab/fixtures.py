"""Deterministic synthetic fixtures, not real choir recordings."""
import numpy as np

RATE = 22050


def choir(seconds=8, drift=0, harmonics=5, wrong_note=False, changing=False):
    t = np.arange(int(RATE * seconds)) / RATE
    cents = drift * t / seconds
    signal = np.zeros_like(t)
    for voice, note in enumerate([48, 52, 55, 59]):
        midi = np.full_like(t, note, dtype=float)
        if changing:
            for section, shift in enumerate([0, 2, -3, 5]):
                midi[(t >= section * seconds / 4) & (t < (section+1) * seconds / 4)] += shift
        frequency = 440 * 2**((midi - 69) / 12 + cents / 1200)
        phase = np.cumsum(frequency) * (2 * np.pi / RATE)
        gain = (0.7 + 0.25 * np.sin(t * (voice+1))) if changing else 1
        for harmonic in range(1, harmonics+1):
            signal += gain * np.sin(harmonic * phase + voice * 0.2) / harmonic**1.4 / 12
    if wrong_note:
        mask = (t > 3) & (t < 3.4)
        signal[mask] += 0.15 * np.sin(2*np.pi * 440 * 2**(35/1200) * t[mask])
    return signal



def natural_chords(seconds=12):
    t = np.arange(int(RATE * seconds)) / RATE
    signal = np.zeros_like(t)
    # All chords share a fixed frequency reference; thirds are 5:4, fifths 3:2.
    for section, root in enumerate([48, 50, 45, 53]):
        mask = (t >= section*seconds/4) & (t < (section+1)*seconds/4)
        for voice, ratio in enumerate([1, 1.25, 1.5, 2]):
            phase = 2*np.pi*440*2**((root-69)/12)*ratio*t[mask]
            for h in range(1, 6):
                signal[mask] += np.sin(h*phase+voice*.2)/h**1.4/12
    return signal


def dominant_detuned_voice():
    signal = choir()
    t = np.arange(len(signal))/RATE
    envelope = np.minimum(1, np.maximum(0, (t-3)*10)) * np.minimum(1, np.maximum(0, (6-t)*10))
    for h in range(1, 7):
        signal += envelope * .25 * np.sin(2*np.pi*440*2**(35/1200)*h*t)/h**1.4
    return signal
