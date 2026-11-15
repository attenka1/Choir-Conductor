# iOS recording pitch analysis checks

The production Swift core is based on Android `android-lab-10`. iOS v2 resets
the previous cents value when a new segment begins after a long gap; the Android
reference retains it. Old iOS v1 caches are invalidated. The file entry point
decodes existing AAC/M4A recordings as well as WAV fixtures. No audio session or
microphone is needed.

From the workspace root, compile and run on macOS:

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-analysis-cache 'Choir Master/RecordingPitchAnalysis.swift' 'Choir Master/RecordingAnalysisStore.swift' Tests/RecordingAnalysisChecks/main.swift -o /tmp/choir-recording-analysis-checks
/tmp/choir-recording-analysis-checks /tmp/choir-analysis-fixtures
```

AAC encoding requires access to the system codec service. A sandbox may prevent
the M4A fixture from being created. The tests cover stable and descending chords,
100-cent continuation, gaps, A4 calibration, opposite-phase stereo, clipping,
block boundaries, production settings, bounded chart projection, WAV/M4A decoding,
cache reopening, source/A4 invalidation, corrupt-cache recovery and cancellation.

For an independent comparison with the sibling Android source tree, compile the
Kotlin runner using a local Kotlin compiler and JDK:

```sh
kotlinc '../../Choir Master Android/app/src/main/java/com/attetenkanen/choirmaster/analysis/'{Fourier,TuningLevel,PitchAnalysis}.kt Tests/RecordingAnalysisChecks/AndroidReference.kt -include-runtime -d /tmp/choir-analysis-reference.jar
java -jar /tmp/choir-analysis-reference.jar /tmp/choir-analysis-fixtures
python3 Tests/RecordingAnalysisChecks/compare_android.py /tmp/choir-analysis-fixtures
```

The three comparison fixtures use the same quantized PCM and a shortened
3-second block / 0.5-second step / 0.1-second hop. Frame grids, gaps, reasons,
segments and reliability must agree; pitch tolerance is 0.000001 cents before a segment reset. After the gap,
the comparison checks the corrected iOS level against the fixture’s 48 cents
instead of requiring the old Android smoothing behavior.
A separate Swift check exercises the production 15-second block and 0.02-second
hop. Equivalence tests establish implementation agreement, not real-choir accuracy.

The hosted Xcode suite also exercises file decoding and A4 cache invalidation
through the production repository.
