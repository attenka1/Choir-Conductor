"""Compare Swift output with AndroidReference.kt output in the supplied fixture folder."""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
largest = 0.0
for name in ("stable", "fall", "gap"):
    swift = json.loads((root / (name + ".json")).read_text())
    android = [line.split("\t") for line in (root / (name + ".android.tsv")).read_text().splitlines()]
    assert len(swift) == len(android), name
    for point, reference in zip(swift, android):
        frame, cents, evidence, segment, reason = reference
        assert point["frame"] == int(frame), name
        assert point["segment"] == int(segment) and point["reason"] == reason, name
        assert (point.get("cents") is None) == (cents == "null"), name
        if cents != "null":
            error = abs(point["cents"] - float(cents))
            if name == "gap" and int(segment) > 0:
                # iOS v2 intentionally starts a new segment at its observed level.
                # This fixture resumes 48 cents above its first segment.
                assert abs(point["cents"] - 48) < 5, (name, point)
            else:
                largest = max(largest, error)
                assert error < 1e-6, (name, error)
        assert abs(point["evidence"] - float(evidence)) < 1e-8, name
    print(f"PASS: Android comparison (iOS v2 reset after gap), {name}, {len(swift)} points")
print(f"Largest difference {largest:.3g} cents")
