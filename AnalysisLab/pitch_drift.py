"""Experimental offline drift estimator. Not validated for real choir recordings.

NumPy is a lab dependency only. No inference is made about individual singers.
Quality is a heuristic score, not a probability. Equal-tempered synthetic
fixtures cannot establish accuracy for natural/historical choir intonation.
"""
from dataclasses import asdict, dataclass
from math import log2
from typing import Optional
import argparse
import json
from pathlib import Path
import wave

import numpy as np

VERSION = "lab-1"


@dataclass(frozen=True)
class Config:
    window: int = 16384
    hop_seconds: float = 0.2
    min_rms: float = 0.002
    min_frequency: float = 65.0
    max_frequency: float = 1100.0
    gap_seconds: float = 2.0
    kernel_cents: float = 5.0
    harmonic_filter: bool = True

    def __post_init__(self):
        if self.window < 1024 or self.window & (self.window - 1):
            raise ValueError("window must be a power of two >= 1024")
        if not (0 < self.hop_seconds <= 1 and self.gap_seconds > self.hop_seconds):
            raise ValueError("invalid hop or gap")
        if not (0 < self.min_frequency < self.max_frequency and self.min_rms > 0):
            raise ValueError("invalid frequency range or silence threshold")
        if not 0 < self.kernel_cents < 25:
            raise ValueError("invalid histogram kernel")


@dataclass(frozen=True)
class Point:
    time_seconds: float
    drift_cents: Optional[float]
    quality: float
    segment: int


def circular_distance(a, b):
    return (np.asarray(a) - b + 50.0) % 100.0 - 50.0


def spectral_observation(samples, sample_rate, cfg):
    """Return periodic cents and evidence quality, separately for each channel."""
    x = np.asarray(samples, dtype=float)
    if not np.all(np.isfinite(x)):
        return None, 0.0
    rms = float(np.sqrt(np.mean(x * x)))
    if rms < cfg.min_rms or np.mean(np.abs(x) >= 0.999) > 0.01:
        return None, 0.0
    # Zero padding interpolates the spectrum, it does not add signal information.
    spectrum = np.abs(np.fft.rfft((x - np.mean(x)) * np.hanning(len(x)), n=cfg.window * 4))
    bins = np.arange(1, len(spectrum) - 1)
    peaks = bins[(spectrum[1:-1] > spectrum[:-2]) & (spectrum[1:-1] >= spectrum[2:])]
    peaks = peaks[(peaks * sample_rate / (cfg.window * 4) >= cfg.min_frequency)
                  & (peaks * sample_rate / (cfg.window * 4) <= cfg.max_frequency)]
    if not len(peaks):
        return None, 0.0
    peaks = peaks[spectrum[peaks] >= max(float(np.max(spectrum)) * 0.07,
                                        float(np.median(spectrum)) * 12)]
    if len(peaks) < 3:
        return None, 0.0
    frequencies, amplitudes = [], []
    for k in peaks:
        y0, y1, y2 = np.log(np.maximum(spectrum[k-1:k+2], 1e-20))
        denominator = y0 - 2 * y1 + y2
        adjustment = float(np.clip(0.5 * (y0-y2) / denominator, -0.5, 0.5)) if denominator else 0
        frequencies.append((k + adjustment) * sample_rate / (cfg.window * 4))
        amplitudes.append(spectrum[k])
    frequencies, amplitudes = np.array(frequencies), np.array(amplitudes)
    if cfg.harmonic_filter:
        keep = []
        for i, f in enumerate(frequencies):
            # Do not count resolved upper harmonics as independent voices.
            # This also removes true octave-doubled singers: a known limitation.
            harmonic = False
            for j in keep:
                n = int(round(f / frequencies[j]))
                if 2 <= n <= 12 and abs(1200 * log2(f / (n * frequencies[j]))) < 12:
                    harmonic = True
                    break
            if not harmonic:
                keep.append(i)
        frequencies, amplitudes = frequencies[keep], amplitudes[keep]
    if len(frequencies) < 2:
        return None, 0.0
    offsets = (1200 * np.log2(frequencies / 440.0) + 50) % 100 - 50
    # Cap amplitude influence. A huge peak must not have unbounded weight.
    weights = np.minimum(np.sqrt(amplitudes / np.median(amplitudes)), 1.5)
    grid = np.arange(-50.0, 50.0)
    distances = circular_distance(offsets[:, None], grid[None, :])
    density = np.sum(weights[:, None] * np.exp(-0.5 * (distances / cfg.kernel_cents)**2), axis=0)
    best = int(np.argmax(density))
    support = np.abs(circular_distance(offsets, grid[best])) < 10
    fraction = float(np.sum(weights[support]) / np.sum(weights))
    if np.count_nonzero(support) < 2 or fraction < 0.6:
        return None, 0.0
    # Refine around the modal neighbourhood, respecting the circular seam.
    delta = circular_distance(offsets[support], grid[best])
    estimate = float(grid[best] + np.average(delta, weights=weights[support]))
    estimate = (estimate + 50) % 100 - 50
    quality = min(1.0, fraction * min(1.0, np.count_nonzero(support) / 4))
    return estimate, quality


class Tracker:
    """Soft continuity with explicit loss of continuity across long gaps."""
    def __init__(self, cfg):
        self.cfg = cfg
        self.previous = None
        self.baseline = None
        self.last_time = None
        self.segment = -1
        self.pending = []

    def step(self, time, offset, quality):
        if self.last_time is not None and time - self.last_time > self.cfg.gap_seconds:
            self.previous = self.baseline = self.last_time = None
            self.pending = []
        if offset is None:
            self.pending = []
            return Point(time, None, 0.0, self.segment)
        if self.previous is None:
            # Require several supporting windows before establishing a baseline.
            self.pending.append((time, offset, quality))
            self.pending = self.pending[-3:]
            if len(self.pending) < 3:
                return Point(time, None, 0.0, self.segment)
            anchor = self.pending[0][1]
            values = [anchor + float(circular_distance(p[1], anchor)) for p in self.pending]
            if max(values) - min(values) > 10:
                return Point(time, None, 0.0, self.segment)
            self.previous = values[-1]
            self.baseline = values[0]
            self.segment += 1
            self.pending = []
        else:
            candidate = self.previous + float(circular_distance(offset, self.previous))
            # Reject unsupported abrupt motion; do not clamp it into a fake curve.
            max_motion = 8.0 + 25.0 * (time - self.last_time)
            if abs(candidate - self.previous) > max_motion:
                return Point(time, None, 0.0, self.segment)
            self.previous = candidate
        self.last_time = time
        return Point(time, float(self.previous - self.baseline), float(quality), self.segment)


def analyze_blocks(blocks, sample_rate, cfg=Config()):
    """Streaming API: blocks are frames x channels; memory bounded by block/window.

    Select the channel with the strongest evidence, never sum stereo waveforms.
    Channel disagreement rejects the observation instead of averaging it away.
    """
    if not 8000 <= sample_rate <= 192000 or cfg.max_frequency >= sample_rate / 2:
        raise ValueError("unsupported sample rate")
    tracker = Tracker(cfg)
    pending = None
    start = 0
    skip = 0
    hop = max(1, int(sample_rate * cfg.hop_seconds))
    for block in blocks:
        block = np.asarray(block, dtype=float)
        if block.ndim == 1:
            block = block[:, None]
        if block.ndim != 2 or not 1 <= block.shape[1] <= 2:
            raise ValueError("expected mono or stereo PCM")
        if len(block) == 0:
            continue
        if pending is not None and block.shape[1] != pending.shape[1]:
            raise ValueError("channel count changed")
        if skip:
            consumed = min(skip, len(block))
            skip -= consumed
            block = block[consumed:]
        pending = block.copy() if pending is None else np.concatenate((pending, block))
        while len(pending) >= cfg.window:
            observations = [spectral_observation(pending[:cfg.window, c], sample_rate, cfg)
                            for c in range(pending.shape[1])]
            valid = [o for o in observations if o[0] is not None]
            if len(valid) == 2 and abs(float(circular_distance(valid[0][0], valid[1][0]))) > 10:
                offset, quality = None, 0.0
            else:
                offset, quality = max(valid, key=lambda o: o[1]) if valid else (None, 0.0)
            time = (start + cfg.window / 2) / sample_rate
            yield tracker.step(time, offset, quality)
            available = len(pending)
            pending = pending[min(hop, available):]
            skip = max(0, hop - available)
            start += hop


def wav_blocks(path, frames=32768):
    with wave.open(str(path), "rb") as source:
        if source.getsampwidth() != 2 or source.getnchannels() not in (1, 2):
            raise ValueError("lab WAV reader supports PCM16 mono/stereo only")
        while True:
            raw = source.readframes(frames)
            if not raw:
                return
            yield np.frombuffer(raw, dtype="<i2").reshape(-1, source.getnchannels()) / 32768.0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.wav.resolve() == args.output.resolve():
        parser.error("output must differ from source WAV")
    with wave.open(str(args.wav), "rb") as source:
        sample_rate, channels = source.getframerate(), source.getnchannels()
    cfg = Config()
    payload = {"version": VERSION, "experimental": True, "sample_rate": sample_rate,
               "channels": channels, "config": asdict(cfg),
               "points": [asdict(p) for p in analyze_blocks(wav_blocks(args.wav), sample_rate, cfg)]}
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, allow_nan=False), encoding="utf-8")
    temporary.replace(args.output)


if __name__ == "__main__":
    main()
