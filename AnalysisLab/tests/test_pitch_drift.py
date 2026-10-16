import unittest
import numpy as np
from pitch_drift import Config, Tracker, analyze_blocks, circular_distance

from fixtures import RATE, choir, natural_chords



def points(signal, size=32768):
    return list(analyze_blocks((signal[i:i+size] for i in range(0, len(signal), size)), RATE))


def valid(points):
    return [p for p in points if p.drift_cents is not None]


class AnalysisTests(unittest.TestCase):
    def test_stable_changing_chords_and_timbre(self):
        result = points(choir(changing=True))
        good = valid(result)
        self.assertGreater(len(good)/len(result), 0.65)
        self.assertLess(np.percentile([abs(p.drift_cents) for p in good], 95), 5)

    def test_known_falling_pitch(self):
        result = points(choir(drift=-30))
        good = valid(result)
        self.assertGreater(len(good)/len(result), 0.8)
        # Baseline is the first supported frame, not time zero.
        first_time = result[0].time_seconds
        errors = [abs(p.drift_cents - (-30 * (p.time_seconds-first_time)/8)) for p in good]
        self.assertLess(np.median(errors), 5)

    def test_seam_and_multiple_semitones(self):
        result = points(choir(seconds=12, drift=-120))
        good = valid(result)
        self.assertGreater(len(good)/len(result), 0.8)
        self.assertLess(good[-1].drift_cents, -100)
        self.assertLess(max(abs(b.drift_cents-a.drift_cents) for a, b in zip(good, good[1:])), 10)

    def test_short_wrong_note(self):
        clean = points(choir())
        affected = points(choir(wrong_note=True))
        errors = [abs(a.drift_cents-b.drift_cents) for a, b in zip(clean, affected)
                  if a.drift_cents is not None and b.drift_cents is not None]
        self.assertGreater(len(errors)/len(clean), 0.65)
        self.assertLess(max(errors), 5)

    def test_silence_noise_and_clipping(self):
        rng = np.random.default_rng(19)
        for signal in [np.zeros(RATE*3), rng.normal(0, 0.01, RATE*3), np.ones(RATE*3)]:
            self.assertEqual(valid(points(signal)), [])

    def test_stereo_opposite_phase_does_not_cancel(self):
        mono = choir()
        stereo = np.column_stack((mono, -mono))
        a, b = points(mono), points(stereo)
        self.assertEqual(a, b)
        self.assertGreater(len(valid(b)), 20)

    def test_disagreeing_stereo_rejected(self):
        mono = choir(seconds=3)
        t = np.arange(len(mono))/RATE
        detuned = sum(np.sin(2*np.pi*440*2**((n-69)/12+30/1200)*t)/12 for n in [48,52,55,59])
        self.assertEqual(valid(points(np.column_stack((mono, detuned)))), [])

    def test_natural_chords_keep_useful_coverage(self):
        result = points(natural_chords())
        good = valid(result)
        self.assertGreater(len(good)/len(result), .65)
        self.assertLess(np.percentile([abs(p.drift_cents) for p in good], 95), 5)

    def test_single_harmonic_voice_is_not_a_choir_consensus(self):
        t = np.arange(RATE*3)/RATE
        solo = sum(np.sin(2*np.pi*150*h*t)/h**1.4/4 for h in range(1, 7))
        self.assertEqual(valid(points(solo)), [])

    def test_block_boundaries_do_not_change_results(self):
        signal = choir(seconds=3)
        self.assertEqual(points(signal), points(signal, size=997))

    def test_long_gap_starts_new_segment(self):
        tracker = Tracker(Config())
        result = [tracker.step(t, offset, 0.9) for t, offset in
                  [(0, 0), (.2, 0), (.4, 0), (.6, -4), (1, None),
                   (4, 30), (4.2, 30), (4.4, 30)]]
        self.assertEqual(result[3].drift_cents, -4)
        self.assertEqual(result[-1].segment, 1)
        self.assertEqual(result[-1].drift_cents, 0)

    def test_circular_seam(self):
        self.assertEqual(float(circular_distance(-49, 49)), 2)

    def test_android_capture_rates(self):
        for rate in [44100, 48000, 96000]:
            t = np.arange(rate*4)/rate
            signal = sum(np.sin(2*np.pi*440*2**((n-69)/12)*t)/10 for n in [48,52,55,59])
            result = list(analyze_blocks((signal[i:i+8192] for i in range(0, len(signal), 8192)), rate))
            good = valid(result)
            self.assertGreater(len(good)/len(result), .7)
            self.assertLess(max(abs(p.drift_cents) for p in good), 5)

    def test_streaming_memory_does_not_grow_with_duration(self):
        import tracemalloc
        rate, seconds, block_frames = 48000, 600, 8192
        def silence():
            for start in range(0, rate*seconds, block_frames):
                yield np.zeros((min(block_frames, rate*seconds-start), 2))
        tracemalloc.start()
        count = 0
        try:
            for point in analyze_blocks(silence(), rate):
                count += 1
                self.assertIsNone(point.drift_cents)
            _, peak = tracemalloc.get_traced_memory()
        finally:
            tracemalloc.stop()
        self.assertGreater(count, 2900)
        self.assertLess(peak, 8*1024*1024)

    def test_pcm16_stereo_wav_roundtrip(self):
        import tempfile
        import wave
        from pathlib import Path
        from pitch_drift import wav_blocks
        mono = choir(seconds=3)
        stereo = np.column_stack((mono, -mono))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"lyra-format-fixture.wav"
            with wave.open(str(path), "wb") as output:
                output.setnchannels(2)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes((stereo*32767).astype("<i2").tobytes())
            good = valid(list(analyze_blocks(wav_blocks(path, frames=997), RATE)))
            self.assertGreater(len(good), 8)
            self.assertLess(max(abs(p.drift_cents) for p in good), 1)

    def test_invalid_configuration(self):
        for kwargs in [{"window": 123}, {"hop_seconds": 0}, {"kernel_cents": 0}]:
            with self.assertRaises(ValueError):
                Config(**kwargs)


if __name__ == "__main__":
    unittest.main()
