# Viritysdumpin vertailu 2026-11-17

Tuotantokoodia ei muutettu. Komennot ajettiin hakemistosta `Untitled Project`:

```text
xcrun swiftc -O -module-cache-path /tmp/choir-tuning-cache -framework Accelerate \
  "Choir Master/Temperament.swift" "Choir Master/Localization.swift" \
  "Choir Master/NoteNaming.swift" "Choir Master/PitchDetector.swift" \
  audit-reports/choir-master/evidence/tuning-2026-11-17/main.swift \
  -o /tmp/choir-tuning-dump
/tmp/choir-tuning-dump > audit-reports/choir-master/evidence/tuning-2026-11-17/dump.tsv

xcrun swiftc -module-cache-path /tmp/choir-tuning-cache \
  "Choir Master/Temperament.swift" "Choir Master/Localization.swift" \
  Tests/TemperamentChecks/main.swift -o /tmp/choir-temperament-checks
/tmp/choir-temperament-checks
```

Olemassa oleva tarkistus tulosti:

`PASS: A4 anchor, octaves, pure fifths, meantone thirds, 24-EDO across all roots`

`python3 audit-reports/choir-master/evidence/tuning-2026-11-17/compare.py` tulosti:

```text
wolf pythagorean 678.494990
wolf quarterComma 737.637287
failures 0
float cents 0.000030284435 replay cents 0.000030284435
duplicate name sets 0
finnish equal words True
finnish historical unicode systems 3
pythagorean comma 23.460010
syntonic comma 21.506290
meantone fifth 696.578428
```

`dump.tsv` on tuotantofunktioiden tuloste, 11147 riviä. Vertailumalli on `compare.py`.
