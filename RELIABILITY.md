# Choir Master: reliability changes, 2026-10-11

## Implemented

- Local Git baseline `6ea15b7` preserves the app, renamed project and bundled sounds before these changes.
- Chord reads preserve corrupt data and a recovery copy in `savedChords.v1.unreadableBackup`. Saves refuse to replace an unreadable store. Restoring a validated payload is required before saving again.
- Recording renames persist the proposed list before publishing the new name. Stale recorder/player delegate callbacks are ignored. A failed recording start cleans its incomplete file and releases its session claim.
- AudioSessionCoordinator owns the session for sound, recording and recorded playback. Starting another key does not reactivate an existing session. Stopping recording restores playback routing; stopping one client keeps the session active for remaining clients. A real interruption stops everything and requires explicit restart.
- Temporary inactive scenes no longer stop practice. Background scenes still stop all audio. Recording and continuous reference tone prevent automatic screen lock, as does the metronome.
- Piano and reference DSP state belongs to their audio callbacks. A short control mailbox uses try-lock on the callback: if publication is busy, the callback renders its previous state without waiting or inserting silence. Pitch tables are computed before publication. No UI callbacks execute while the mailbox is locked.
- Beat polling starts only for a running metronome and only publishes changed values. Recording elapsed-time polling starts only while recording. Engine/session release waits 300 ms after the last live sound, allowing release envelopes to finish; new sound cancels that release.
- Chord playback prepares the audio engine before changing the stored profile, then commits the profile together.
- Shared note spelling follows the transposed open fifth chain for Pythagorean and quarter-comma tuning and the chosen scale intervals for just intonation; the keyboard and chord labels use the same labels.
- Missing or invalid SoundFont does not prevent piano/metronome/precise reference playback. The settings fall back to the precise tone with an error message when the unavailable font is selected.
- Keyboard geometry/accessibility elements are rebuilt only when necessary. VoiceOver activation plays a short note, with sustain/reference behavior preserved. The 24-note black halves are at least 44 points wide; the keyboard scrolls to cover the larger range. Deliberate swipe threshold is 24 points. VoiceOver horizontal scrolling is supported.
- Sample fundamentals moved unchanged from the existing measurement CSV into bundled metadata. Format, frame count and loop bounds are validated before playback. Existing loop points and timbre are retained. Safe loop wrapping supports large playback steps.
- Two identified Arabic terminology errors were corrected. Other translations remain drafts requiring human musical-language review.
- App minimum iOS is explicitly 17.0, the same value previously resolved by the SDK setting. The app is now named Choir Master. Its bundle identifier is `com.atte.tenkanen.ChoirConductor`, matching the existing App Store Connect record, with test ID `com.atte.tenkanen.ChoirConductor.Tests`. Development team and automatic signing remain unchanged.

## Verification

The shared Xcode scheme contains a hosted XCTest target. Tests cover session policy transitions, repeated activation, failed activation, interruption, corrupt chord preservation, stale recorder callback, transposed spelling, concurrent control updates, chord release, packaged sample format and missing SoundFont fallback. Use Cmd–U in Xcode. All 12 tests passed on the iPhone 11 Pro Max simulator running iOS 26.5. The Finnish portrait main screen was also inspected from a simulator screenshot.

Additional existing standalone checks exercise sample-clock metronome timing, all 97 notes, bounded output, release tails, chord persistence, reference-tone sustain/stop and localization key/format coverage. Their sources remain in the workspace-level `Tests` directory. These checks passed. The spectral check measured precise reference tones at their expected frequencies for the tested A4 values, quarter tone and E4 temperament cases; piano A4/quarter tone retained approximately −1.9/+2.0 cent differences, as before. No full-range pitch sweep was repeated in this change.

## Device validation still required

1. Start metronome and a held chord, start/stop microphone recording, and verify neither activity is lost during session format changes.
2. Repeat with Bluetooth headphones and wired/USB audio. Verify output routing and sound quality return after recording, and confirm the microphone indicator turns off.
3. Open/close Control Center and Notification Center. Verify temporary inactive scenes preserve playback; backgrounding, interruptions and headphone removal stop audio and leave no stuck notes.
4. Record without metronome and play a reference tone without metronome. Verify automatic screen lock remains disabled, then returns when the activity ends. Manual lock still stops audio by design.
5. Play chords with real multitouch; test sustain toggling, deliberate keyboard swipes and 24-note halves on a small iPhone.
6. Test VoiceOver activation and scrolling, larger text, landscape, long translations and RTL layouts.
7. Listen to C2–C6, especially C2–F3. Current samples span G3–G5; lower notes still use substantial downward transposition. Bass timbre needs listening and potentially additional original bass samples, not an unverified pitch-shift replacement.

No claim is made of real microphone, Bluetooth, speaker listening, device pitch, VoiceOver user testing or physical multitouch verification. Background recording has not been added. Full translation review and per-sample loop optimization remain follow-up work.
