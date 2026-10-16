"""Reproduce numeric lab report; includes deliberately difficult counterexamples."""
import json
from pathlib import Path
import time

import numpy as np

from fixtures import choir, natural_chords, dominant_detuned_voice, RATE
from pitch_drift import Config, analyze_blocks



def main():
    cases = [
        ("stable_changing_harmony", choir(changing=True), 0, 8),
        ("fall_30c", choir(drift=-30), -30, 8),
        ("fall_120c", choir(seconds=12, drift=-120), -120, 12),
        ("short_wrong_note", choir(wrong_note=True), 0, 8),
        ("opposite_phase_stereo", np.column_stack((choir(), -choir())), 0, 8),
        ("natural_chords_fixed_reference", natural_chords(), 0, 12),
        ("dominant_detuned_voice", dominant_detuned_voice(), 0, 8),
    ]
    results = []
    for name, signal, drift, seconds in cases:
        for harmonic_filter in [False, True]:
            cfg = Config(harmonic_filter=harmonic_filter)
            start = time.monotonic()
            result = list(analyze_blocks((signal[i:i+32768] for i in range(0, len(signal), 32768)), RATE, cfg))
            elapsed = time.monotonic() - start
            good = [p for p in result if p.drift_cents is not None]
            errors = [abs(p.drift_cents - drift*(p.time_seconds-result[0].time_seconds)/seconds) for p in good]
            coverage = len(good)/len(result)
            p95 = float(np.percentile(errors, 95)) if errors else None
            results.append(dict(case=name, harmonic_filter=harmonic_filter,
                                coverage=coverage, median_error_cents=float(np.median(errors)) if errors else None,
                                p95_error_cents=p95, maximum_error_cents=max(errors) if errors else None,
                                runtime_seconds=elapsed,
                                synthetic_gate=coverage >= .65 and p95 is not None and p95 <= 5))
    path = Path(__file__).with_name("RESULTS.json")
    path.write_text(json.dumps({"sample_rate": RATE, "experimental": True,
                                "real_choir_validated": False, "results": results}, indent=2), encoding="utf-8")
    for item in results:
        error = "no result" if item["p95_error_cents"] is None else f'{item["p95_error_cents"]:.2f} c'
        print(f'{item["case"]:36} harmonic={item["harmonic_filter"]!s:5} coverage={item["coverage"]:.0%} p95={error} gate={item["synthetic_gate"]}')


if __name__ == "__main__":
    main()
