# Pianon ja äänen auditointievidenssi

17.11.2026. Tuotannon lähtöcommit e523a5b. Kaikki testatut tiedostot olivat
muuttumattomia, SHA-256:t `source-snapshot.json`. Koodia ei instrumentoitu.
Komennot ajettiin työtilan juuresta (jossa `Untitled Project/` on).
Kloonatun repon juuressa poista tämä historiallinen etuliite lähdepoluista.

Xcode 27.2 / Swift 6.4.2 / arm64 macOS; NumPy 2.0.2. iOS-testit: iPhone 16 Pro
App Store / iOS 18.5 -simulaattori. Ei fyysistä iPhonea. Offline-engine ei käytä
mikrofonia tai kaiutinta; järjestelmän audiokomponenttipääsy sallittiin ajoille.

## DSP, taajuus ja WAV-tarkistus

```sh
mkdir -p /tmp/choir-piano-audit
CH_AUDIO_SOURCE='Untitled Project/Choir Master'
CH_AUDIO_EVIDENCE='Untitled Project/audit-reports/choir-master/evidence/piano-2026-11-17'
xcrun swiftc -O -module-cache-path /tmp/choir-piano-audit/cache "$CH_AUDIO_SOURCE/AudioRenderer.swift" "$CH_AUDIO_SOURCE/PianoSampleMetadata.swift" "$CH_AUDIO_EVIDENCE/dsp/main.swift" -o /tmp/choir-piano-audit/dsp-checks
/tmp/choir-piano-audit/dsp-checks "$CH_AUDIO_SOURCE/PianoSamples"
python3 "$CH_AUDIO_EVIDENCE/spectral.py"
xcrun swiftc -O -module-cache-path /tmp/choir-piano-audit/cache "$CH_AUDIO_SOURCE/ReferenceOscillator.swift" "$CH_AUDIO_EVIDENCE/oscillator/main.swift" -o /tmp/choir-piano-audit/oscillator-checks
/tmp/choir-piano-audit/oscillator-checks
```

Testiohjelmat kirjoittavat tuloksensa `/tmp/choir-piano-audit`-kansioon. DSP-ajo
kirjoittaa sinne 97 Float32-PCM-tallennetta (442 Hz:n A4) spektrianalyysiä varten;
niitä ei kopioitu repoon. Tulokset ja luonnehdinnan CSV on säilytetty tässä.
`spectral.py` vastaa ajettua FFT-/WAV-mittausta. Pianon senttipoikkeamille ei
asetettu jälkikäteen testin läpäisyrajaa. Suoran oskillaattorin raja oli 0,01 senttiä.

`dsp-summary.json` sisältää myös vakionäytteen volume-askelluksen kaksi
peräkkäistä PCM-arvoa. Tämä osoittaa rampin puuttumisen, ei kuulokokeen tulosta.
291 äänen release-testit olivat jokaisessa tapauksessa soittotilan jälkeisiä.

## ReferenceTone-peruutus

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-piano-audit/cache "$CH_AUDIO_SOURCE/Temperament.swift" "$CH_AUDIO_SOURCE/Localization.swift" "$CH_AUDIO_SOURCE/ReferenceOscillator.swift" "$CH_AUDIO_SOURCE/ReferenceTone.swift" "$CH_AUDIO_EVIDENCE/reference/main.swift" -o /tmp/choir-piano-audit/reference-checks
/tmp/choir-piano-audit/reference-checks "$CH_AUDIO_SOURCE/SoundFonts/GeneralUser-GS.sf2"
```

Tämä on luonnehdintatesti, jonka ohjelman exit 0 ei tarkoita peruutuksen
onnistumista. Tarkista `reference-cancel.json`: precise/immediate tuottaa
stopin jälkeen RMS 0,0141083 ja soundFont/immediate myöhemmän configure-kutsun
jälkeen RMS 0,0109874. Tämä on AUD-001:n toistotodiste.
Taskien ajoituksen annettiin edetä 80 ms ennen renderöintiä; Playn ja Stopin
välissä ei ollut awaitia. Ulostuloa renderöitiin sen jälkeen noin 2 s, ja
myöhemmän configure-kutsun vaikutusta noin 1 s. Tavallista stopia kontrolloitiin
samoilla asetuksilla. Fyysistä UI-tapahtumaketjua tai pausen jälkeistä restartia
ei ajettu tässä testissä.

Nykyisen regressio-ohjelman uusinta:

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-piano-audit/cache "$CH_AUDIO_SOURCE/Temperament.swift" "$CH_AUDIO_SOURCE/Localization.swift" "$CH_AUDIO_SOURCE/ReferenceOscillator.swift" "$CH_AUDIO_SOURCE/ReferenceTone.swift" 'Untitled Project/Tests/ReferenceToneChecks/main.swift' -o /tmp/choir-piano-audit/existing-reference-checks
/tmp/choir-piano-audit/existing-reference-checks "$CH_AUDIO_SOURCE/SoundFonts/GeneralUser-GS.sf2"
```

Ohjelma käyttää `configure`-oletusääntä precise. Tämän vuoksi SoundFontin normaali
soitto tarkistettiin erillisellä `soundfont/main.swift`-kopiolla, jossa ainoa
soittovalinnan muutos on eksplisiittinen `sound: .soundFont`. WAV-tulosten
nimet ohjattiin `/tmp/choir-piano-audit/soundfont-reference-*`-polkuun.
Käännä ja aja se samalla komennolla korvaamalla viimeinen Swift-lähde tällä
kopiolla. `soundfont-run.log` sisältää 11 normaalin soiton ja lopun peruutusparin
läpäisyt. Kahden Playn peruutusparin läpäisy ei kumoa yhden Playn luonnehdintaa.

`soundfont.json` sisältää tiedoston koon ja RIFF/pdta/phdr-headerista parsitut
preset 19:n pankit ja nimet. Pankin 0 nimi on Pipe Organ. Koko SF2:n generaattori-
matriisia ei parsittu tai validoitu tällä yksittäisellä header-tarkistuksella.

## Malli ja UIKit-geometria

Kopioi nykyiset `Choir Master/`, `Choir MasterTests/`, `Choir Master.xcodeproj/`
ja `AdMob-Info.plist` hakemistoon `/tmp/choir-piano-audit/Project`. Lisää vain
siihen kopioon tämän hakemiston `PianoAuditTests.swift` testikansion alle.

Toteutunut ajokomento:

```sh
xcodebuild -project '/tmp/choir-piano-audit/Project/Choir Master.xcodeproj' -scheme 'Choir Master' -destination 'platform=iOS Simulator,id=66ADE923-337F-4741-BC44-C77EB5E997B1' -derivedDataPath /tmp/choir-piano-audit/DerivedData -clonedSourcePackagesDirPath /tmp/choir-review-build/SourcePackages -disableAutomaticPackageResolution -only-testing:ChoirMasterTests/PianoAuditTests test CODE_SIGNING_ALLOWED=NO
```

Käytetty SPM-välimuisti oli valmiina. Sen puuttuessa ratkaise paketit ennen ajoa.
2 testimetodia läpäisi. Mallitesti soittaa äänettömällä volumella. Geometriatesti
kutsuu accessibilityActivatea ohjelmallisesti ja tarkistaa lähetetyt sävelet sekä
kehykset; se ei ole VoiceOver-käyttäjätesti eikä generoi UITouch-sormitapahtumia.
UserDefaults palautetaan mallikokeen jälkeen. Sovelluksen oma testitiedosto säilyi.

Lokiyhteenveto: `model-tests-summary.log`. Täysi paikallinen loki oli
`/tmp/choir-piano-audit/model-tests.log`. Xcresult oli
`/tmp/choir-piano-audit/DerivedData/Logs/Test/Test-Choir Master-2026.11.17_00-48-18-+0200.xcresult`.
Älä luota tilapäispolkujen säilymiseen; olennaiset lähteet ja tulokset ovat tässä.
