# 06 — Suoritetut testit ja tulokset

Mikään kohtaa ei ole merkitty suoritetuksi, ellei komento todella ajettu 2026-11-16.

Ympäristö: Xcode 27.2, macOS, Python 3.9.4. Simulaattori `iPhone 16 Pro App Store`, id `66ADE923-337F-4741-BC44-C77EB5E997B1`, iOS 18.5. Fyysistä puhelinta ei käytetty, vaikka Xcode näki laitteen `iPhone (Atte)`.

## XCTest — PASS

Komento:

```sh
xcodebuild -project "Untitled Project/Choir Master.xcodeproj" -scheme "Choir Master" \
  -destination 'platform=iOS Simulator,id=66ADE923-337F-4741-BC44-C77EB5E997B1' \
  -only-testing:ChoirMasterTests test CODE_SIGNING_ALLOWED=NO
```

Tulos: **TEST SUCCEEDED**. 24 testiä, 0 epäonnistumista, 11,639 s testiaikaa. Ensimmäinen yritys nimellä `iPhone 16` epäonnistui ennen käännöstä: sellaista simulaattoria ei ole (exit 70).

Läpäisseet testit:

- testAdsCannotManageSessionOrPlayAudio
- testAudioRenderingDuringConcurrentControlUpdates
- testCompoundConversionAndHeldChordKeepScreenAwake
- testCorruptChordsCannotBeOverwritten
- testExplicitPlaybackCanRecoverFromUnpairedInterruption
- testExplicitPlaybackStillHonorsSystemActivationFailure
- testFailedActivationRestoresSessionPolicy
- testHistoricalPitchSpellingFollowsFifthChain
- testImportedM4APreservesOriginalEncoding
- testImportedRecordingPlaysAfterDocumentPreviewInterruption
- testImportedWavIsPreservedAnalyzedAndReopened
- testInterruptionRequiresExplicitRestart
- testInvalidImportAndFailedIndexSaveLeaveNoCopiedFiles
- testLegacyRecordingIndexDefaultsToM4A
- testMailboxRetainsChordAndReleaseAcrossVolumeUpdates
- testMissingSoundFontStillProducesPreciseTone
- testOldRecorderErrorIsIgnored
- testPackagedSampleMetadataMatchesFiles
- testQuarterToneKeyTargetsAndAccessibilityActivation
- testRecordingAnalysisDecodesFileAndInvalidatesA4Cache
- testRecordingRestoresPlaybackWithoutRepeatedActivation
- testTunerSharesOnlyReferenceOutputAndRestoresPlaybackCategory
- testTunerTargetsAllTemperamentsAndQuarterTones
- testWrongTypeChordStoreIsAlsoPreserved

`testCompoundConversionAndHeldChordKeepScreenAwake` tarkistaa vain tempon 60 → 180 → 60. Se ei kata F-001:n raja-arvoja.

## Erilliset tarkistukset — PASS

Työkansio: työtilan juuri. Käännös `xcrun swiftc -module-cache-path /tmp/ChoirAuditCache`.

| Komento | Tulos |
| --- | --- |
| `Temperament.swift` + `Localization.swift` + `Tests/TemperamentChecks/main.swift` | PASS: A4, oktaavit, kvintit, terssit, 24-EDO |
| `PitchDetector.swift` + `Temperament.swift` + `Localization.swift` + `Tests/PitchDetectorChecks/main.swift`, `-framework Accelerate` | PASS: sävelalue, yläsävelet, hiljaisuus, DC, kohina, leikkautuminen, kaikki temperoinnit, suodatettu virta 44,1/48/96 kHz |
| `AudioRenderer.swift` + `PianoSampleMetadata.swift` + `Tests/AudioRenderChecks/main.swift`, syöte `PianoSamples` | PASS. Huippu 0,15863453. Lokissa varoitus ei-limittäisestä WAV-asetuksesta, testi silti läpäisi |
| `RecordingStore.swift` + `Localization.swift` + `Tests/RecordingStoreChecks/main.swift` | PASS |
| `SavedChord.swift` + `Temperament.swift` + `Localization.swift` + `Tests/ChordStoreChecks/main.swift` | PASS |
| `python3 "Untitled Project/Tests/LocalizationChecks/check.py"` | PASS: 31 kieltä × 123 merkkijonoa, paikkamerkit, plutil, Tuner- ja Analysis-taulut |
| `python3 Tests/LocalizationChecks/check.py` | PASS. Juuren skripti osoittaa polkuun `Untitled Project/Choir Master` |

## Kaavan toisto — ei sovellusprosessi

`setCompound`-funktion aritmetiikka ajettiin Pythonilla, koska sama kaava on kolme riviä ilman sivuvaikutuksia. Tämä ei ole XCTest.

- Pistetahti, tempo 80: 240, takaisin 80. Oletuspolku säilyy.
- Pistetahti, tempo 96: 240, takaisin 80. Ei säily.
- Kahdeksasosat, tempo 80: 30, takaisin 90. Ei säily.
- Pistetahdista kahdeksasosiin ja takaisin: 160 tempoa väliltä 30–240 ei palaa.
- Kahdeksasosista pistetahtiin: 160 tempoa ei palaa.

## Epäonnistunut tai ajamatta jätetty

| Kohde | Tulos |
| --- | --- |
| `RecordingPitchAnalysis` + `RecordingAnalysisStore` + `Tests/RecordingAnalysisChecks/main.swift` | Käännös onnistui. Ajo hiekkalaatikossa kaatui: `Swift/ErrorType.swift:254`, AVFoundation-virhe 1718449215. Uusintaa hiekkalaatikon ulkopuolella ei tehty, koska `/tmp`-binäärin ajo estettiin. Sama analyysi läpäisi simulaattorin XCTestissä. Ei tulkittu sovelluksen viaksi |
| `xcodebuild` kohteella `iPhone 16` | Exit 70, laitetta ei ole. Uusittu oikealla simulaattorilla, PASS |
| AnalysisLab pytest | Ei ajettu. `requirements.txt` pyytää numpy 2.0.2:ta. Ympäristöä ei asennettu |
| Android-vertailu JAR | Ei ajettu |
| Lint / Swift-analysaattori erillisenä | Ei ajettu. Xcode-käännös testin yhteydessä ei raportoinut käännösvirhettä |
| Fyysinen iPhone, Bluetooth, mikrofoni, kaiutin, VoiceOver käyttäjänä, mainoslomake | Ei suoritettu |

## Testien katve

Ei ole testiä, joka:

- vaihtaa 6/8-tulkintaa tempolla 81–240 tai 30–89 kahdeksasosatilassa
- tarkistaa, että virittimen sulkeminen palauttaa `soundMode`-arvon pianoksi
- soittaa vertailuääntä ja mikrofonia yhtä aikaa
- avaa suostumuslomakkeen
- mittaa katkoksia 5 ms puskurilla
