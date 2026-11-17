#!/usr/bin/env python3
"""Independent interval model compared with the production frequency dump."""
import math
from collections import defaultdict
from pathlib import Path

root = Path(__file__).resolve().parent
rows = root.joinpath("dump.tsv").read_text().splitlines()
freq = {}
anchors = []
names = {}
labels = []
tuner = []
half = []
quant = None
for line in rows:
    parts = line.split("\t")
    kind = parts[0]
    if kind == "F":
        freq[(parts[1], int(parts[2]), float(parts[3]))] = float(parts[4])
    elif kind == "A":
        anchors.append((parts[1], int(parts[2]), float(parts[3]), float(parts[4])))
    elif kind == "N":
        names[(parts[1] == "true", parts[2], int(parts[3]), int(parts[4]))] = parts[5]
    elif kind == "L":
        labels.append((parts[1], parts[2]))
    elif kind == "Q":
        quant = (float(parts[1]), float(parts[2]))
    elif kind == "T":
        tuner.append((parts[1], int(parts[2]), float(parts[3]), float(parts[4]), float(parts[5])))
    elif kind == "H":
        half.append((float(parts[1]), float(parts[2]), float(parts[3])))

def log2(value):
    return math.log(value, 2)

pure_fifth = 1200 * log2(1.5)
pyth_comma = 12 * pure_fifth - 8400
syntonic = 1200 * log2(81 / 80)
meantone_fifth = 300 * log2(5)
just_ratios = [1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8]

def cents(a, b):
    return 1200 * log2(a / b)

def production(system, root, note, a4=442.0):
    base = freq[(system, root, note)]
    if a4 == 442:
        return base
    return base * (a4 / 442.0)

failures = []

def check(name, ok, detail):
    if not ok:
        failures.append(f"{name}: {detail}")

for system, root_pc, a4, actual in anchors:
    check("A4", abs(actual - a4) < 1e-9, f"{system} root {root_pc} {actual} != {a4}")

for system in ["equal", "just", "pythagorean", "quarterComma", "werckmeisterIII", "kirnbergerIII", "vallotti"]:
    for root_pc in range(12):
        for note in range(36, 73):
            ratio = production(system, root_pc, note + 12) / production(system, root_pc, note)
            check("octave", abs(ratio - 2) < 1e-9, f"{system} {root_pc} {note} {ratio}")

for note in [n / 2 for n in range(72, 169)]:
    ratio = production("equal", 0, note) / 442
    expected = 2 ** ((note - 69) / 12)
    check("equal", abs(ratio - expected) < 1e-9, f"{note} {ratio} {expected}")

for root_pc in range(12):
    tonic = 48 + root_pc
    for degree, ratio in enumerate(just_ratios):
        actual = production("just", root_pc, tonic + degree) / production("just", root_pc, tonic)
        check("just", abs(actual - ratio) < 1e-9, f"root {root_pc} degree {degree} {actual} != {ratio}")
    for system, fifth in (("pythagorean", pure_fifth), ("quarterComma", meantone_fifth)):
        for degree in range(-3, 8):
            low = tonic + ((degree * 7) % 12)
            high = tonic + (((degree + 1) * 7) % 12)
            if high < low:
                high += 12
            measured = cents(production(system, root_pc, high), production(system, root_pc, low))
            check(system, abs(measured - fifth) < 1e-6, f"root {root_pc} step {degree} {measured}")
        third = cents(production("quarterComma", root_pc, tonic + 4), production("quarterComma", root_pc, tonic))
        check("meantone third", abs(third - 1200 * log2(1.25)) < 1e-6, f"{third}")
    pure_third = cents(production("kirnbergerIII", root_pc, tonic + 4), production("kirnbergerIII", root_pc, tonic))
    check("kirnberger third", abs(pure_third - 1200 * log2(1.25)) < 1e-6, f"{pure_third}")
    werck = cents(production("werckmeisterIII", root_pc, tonic + 4), production("werckmeisterIII", root_pc, tonic))
    vall = cents(production("vallotti", root_pc, tonic + 4), production("vallotti", root_pc, tonic))
    check("werck third", abs(werck - (4 * pure_fifth - 2400 - 0.75 * pyth_comma)) < 1e-6, f"{werck}")
    check("vallotti third", abs(vall - (4 * pure_fifth - 2400 - 4 * pyth_comma / 6)) < 1e-6, f"{vall}")

def circle_offsets(narrow):
    pos = {0: 0.0}
    pc = 0
    walked = []
    for _ in range(11):
        nxt = (pc + 7) % 12
        pos[nxt] = pos[pc] + pure_fifth - narrow.get(pc, 0.0)
        walked.append(pc)
        pc = nxt
    closing = 8400 - pos[pc]
    expected_closing = pure_fifth - narrow.get(pc, 0.0)
    unfolded = [pos[i] for i in range(12)]
    octave = [value % 1200 for value in unfolded]
    offset = []
    for pitch, value in enumerate(octave):
        delta = value - 100 * pitch
        while delta > 600:
            delta -= 1200
        while delta < -600:
            delta += 1200
        offset.append(delta)
    return offset, closing, expected_closing

models = {
    "werckmeisterIII": {0: pyth_comma / 4, 7: pyth_comma / 4, 2: pyth_comma / 4, 11: pyth_comma / 4},
    "kirnbergerIII": {0: syntonic / 4, 7: syntonic / 4, 2: syntonic / 4, 9: syntonic / 4, 6: pyth_comma - syntonic},
    "vallotti": {5: pyth_comma / 6, 0: pyth_comma / 6, 7: pyth_comma / 6, 2: pyth_comma / 6, 9: pyth_comma / 6, 4: pyth_comma / 6},
}
for system, narrow in models.items():
    offset, closing, expected = circle_offsets(narrow)
    check("circle", abs(closing - expected) < 1e-6, f"{system} closing {closing} != {expected}")
    for root_pc in range(12):
        for pitch in range(12):
            relative = (pitch - root_pc) % 12
            anchor = (9 - root_pc) % 12
            correction = offset[relative] - offset[anchor]
            note = 60 + pitch
            actual = cents(production(system, root_pc, note), 442 * 2 ** ((note - 69) / 12))
            check("offset", abs(actual - correction) < 1e-6, f"{system} root {root_pc} pc {pitch} {actual} != {correction}")

# Distinct names and the C-rooted spellings chosen by the ratio/fifth definitions.
expected_just = ["C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
expected_pyth = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"]
for pc, name in enumerate(expected_just):
    check("just spelling", names[(True, "just", 0, pc)] == name, f"{pc} {names[(True, 'just', 0, pc)]}")
for pc, name in enumerate(expected_pyth):
    check("pyth spelling", names[(True, "pythagorean", 0, pc)] == name, f"{pc} {names[(True, 'pythagorean', 0, pc)]}")
    check("meantone spelling", names[(True, "quarterComma", 0, pc)] == name, f"{pc} {names[(True, 'quarterComma', 0, pc)]}")

duplicate_sets = 0
for key_root in range(12):
    for system in ["equal", "just", "pythagorean", "quarterComma", "werckmeisterIII", "kirnbergerIII", "vallotti"]:
        for international in (False, True):
            values = [names[(international, system, key_root, pc)] for pc in range(12)]
            if len(set(values)) != 12:
                duplicate_sets += 1
                failures.append(f"duplicate names {system} root {key_root} intl {international}: {values}")

finnish_historical_unicode = 0
finnish_equal_words = names[(False, "equal", 0, 3)] == "Es" and names[(False, "equal", 0, 6)] == "Fis"
for system in ["just", "pythagorean", "quarterComma"]:
    if "♭" in names[(False, system, 0, 3)] or "♯" in names[(False, system, 0, 6)]:
        finnish_historical_unicode += 1

for system, root_pc, note, found, error in tuner:
    check("tuner", found == note and abs(error) < 1e-6, f"{system} {root_pc} {note} -> {found} {error}")
for note, found, error in half:
    check("quarter", found == note and abs(error) < 1e-6, f"{note} -> {found} {error}")

check("labels", labels == [("36", "C2"), ("36.5", "C2↑"), ("60", "C4"), ("60.5", "C4↑"), ("69", "A4"), ("69.5", "A4↑"), ("84", "C6"), ("84.5", "C6↑")], str(labels))

# Wolf sizes at C root, pitch classes 8 -> 3.
for system, low, high in (("pythagorean", 68, 75), ("quarterComma", 68, 75)):
    wolf = cents(production(system, 0, high), production(system, 0, low)) % 1200
    print(f"wolf {system} {wolf:.6f}")

print(f"failures {len(failures)}")
print(f"float cents {quant[0]:.12f} replay cents {quant[1]:.12f}")
print(f"duplicate name sets {duplicate_sets}")
print(f"finnish equal words {finnish_equal_words}")
print(f"finnish historical unicode systems {finnish_historical_unicode}")
print(f"pythagorean comma {pyth_comma:.6f}")
print(f"syntonic comma {syntonic:.6f}")
print(f"meantone fifth {meantone_fifth:.6f}")
for item in failures[:30]:
    print(item)
raise SystemExit(1 if failures else 0)
