# Tuner checks

Run from the repository root (macOS with Xcode):

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-pitch-cache 'Choir Master/PitchDetector.swift' 'Choir Master/Temperament.swift' 'Choir Master/Localization.swift' Tests/PitchDetectorChecks/main.swift -o /tmp/choir-pitch-checks
/tmp/choir-pitch-checks
```

Covers pitch range, harmonics, silence, noise, clipping, A4 calibration, all
historical tuning/root combinations, quarter tones, and filtered streaming input
at 44.1/48/96 kHz. Physical microphone and Bluetooth testing remains separate.
