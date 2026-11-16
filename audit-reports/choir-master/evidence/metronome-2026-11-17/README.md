# Metronomivaiheen evidenssi

Päiväys 17.11.2026. Aja komennot työtilan juuresta, jossa `Untitled Project/`
sijaitsee. Tuotantokoodia ei instrumentoitaisi näillä komennoilla. Vertaa ensin
`source-snapshot.json`-tiivisteitä; HEAD yksin ei riitä, koska testattu puu oli
committoimaton. Macin Xcode 27.2 / Swift 6.4.2, arm64. iOS-testit: iOS 18.5.

## Offline-kellon ja postilaatikon tarkistukset

```sh
mkdir -p /tmp/choir-metronome-audit
CH_MET_SOURCE='Untitled Project/Choir Master'
CH_MET_EVIDENCE='audit-reports/choir-master/evidence/metronome-2026-11-17'
xcrun swiftc -O -module-cache-path /tmp/choir-metronome-audit/cache "$CH_MET_SOURCE/AudioRenderer.swift" "$CH_MET_EVIDENCE/clock/main.swift" -o /tmp/choir-metronome-audit/clock-checks
/tmp/choir-metronome-audit/clock-checks
xcrun swiftc -O -module-cache-path /tmp/choir-metronome-audit/cache "$CH_MET_SOURCE/AudioRenderer.swift" "$CH_MET_EVIDENCE/stress/main.swift" -o /tmp/choir-metronome-audit/stress-checks
/tmp/choir-metronome-audit/stress-checks
xcrun swiftc -O -module-cache-path /tmp/choir-metronome-audit/cache "$CH_MET_SOURCE/AudioRenderer.swift" "$CH_MET_SOURCE/PianoSampleMetadata.swift" "$CH_MET_EVIDENCE/mix/main.swift" -o /tmp/choir-metronome-audit/mix-checks
/tmp/choir-metronome-audit/mix-checks "$CH_MET_SOURCE/PianoSamples"
```

`clock/main.swift` kirjoittaa JSON-tuloksen vakioon
`/tmp/choir-metronome-audit/clock-results.json`. Raportin yhteydessä oleva kopio
on toteutunut ajotulos. Assertioiden lukumäärä sisältää PCM:n näytekohtaisia
stereo-/äärellisyystarkistuksia; 41 miljoonaa assertiota ei tarkoita 41 miljoonaa
erillistä ominaisuustestiä. Jitter/drift on tässä vain diskreetin näytekellon
ajoituspoikkeamaa, ei reaaliaikaisen fyysisen ulostulon mittaus.

## Engine ja näytetaajuusmuunnos

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-metronome-audit/cache "$CH_MET_SOURCE/AudioRenderer.swift" "$CH_MET_EVIDENCE/engine/main.swift" -o /tmp/choir-metronome-audit/engine-checks
/tmp/choir-metronome-audit/engine-checks
```

Tämä on todellinen AVAudioEngine-offlineajo, mutta graafi on tarkoituksella
vain metronomin lähdenode ja mainMixer samalla 44,1 kHz -kytkennällä kuin
sovelluksessa. Se ei sisällä koko ChoirAudio-graafin SoundFontia tai erillistä
viritinengineä. Tulos kirjoittuu `/tmp/choir-metronome-audit/engine-results.json`.
Rajattu sandbox-ajo ei löytänyt lähdenoden järjestelmäkomponenttia; sama binaari
ajettiin järjestelmäkomponenttipääsyllä ja onnistui. Mikrofoni/kaiutin eivät olleet
käytössä. `sandbox-attempt.txt` erottaa ympäristövirheen onnistuneesta ajosta.

## Mallitesti tilapäisessä iOS-projektikopiossa

Kopiointi, joka suoritettiin ennen testiä:

```python
from pathlib import Path
import shutil
source = Path('Untitled Project')
target = Path('/tmp/choir-metronome-audit/Project')
target.mkdir(parents=True, exist_ok=True)
for name in ['Choir Master', 'Choir MasterTests', 'Choir Master.xcodeproj']:
    shutil.copytree(source/name, target/name, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('xcuserdata', '.DS_Store'))
shutil.copy2(source/'AdMob-Info.plist', target/'AdMob-Info.plist')
shutil.copy2('audit-reports/choir-master/evidence/metronome-2026-11-17/MetronomeAuditTests.swift',
             target/'Choir MasterTests/MetronomeAuditTests.swift')
```

Todellinen lopullinen ajokomento:

```sh
xcodebuild -project '/tmp/choir-metronome-audit/Project/Choir Master.xcodeproj' -scheme 'Choir Master' -destination 'platform=iOS Simulator,id=66ADE923-337F-4741-BC44-C77EB5E997B1' -derivedDataPath /tmp/choir-metronome-audit/DerivedData -clonedSourcePackagesDirPath /tmp/choir-review-build/SourcePackages -disableAutomaticPackageResolution -only-testing:ChoirMasterTests/MetronomeAuditTests test CODE_SIGNING_ALLOWED=NO
```

Pakettivälimuistin polku oli olemassa tässä ympäristössä. Jos sitä ei ole,
SPM-riippuvuudet on ratkaistava Xcodella ennen uusintaa. Ei fyysistä puhelinta.
Tuotannon alkuperäinen testitiedosto ei muuttunut. Testi käyttää mallin olemassa
olevaa `makeAudio`-riippuvuusinjektiota: audioalustus estetään tarkoituksella,
jotta puhtaat tempo-/asetustestit eivät tarvitse mikrofonia tai laiteääntä.
`UserDefaults` palautetaan kunkin testin lopuksi.

Neljä testimetodia läpäisi. Kaksi on luonnehdintatestejä: niissä väitetään
nimenomaisesti havaittu väärä/rajallinen lopputulos (80 tai 90), jotta löydös on
toistettava. Ne eivät todista virhettä korjatuksi. Prosessin tappamista ei tehty;
uusi malli luki saman pysyvän UserDefaults-tilan.

Täysi paikallinen ajoloki oli `/tmp/choir-metronome-audit/model-tests-final.log`.
Pysyvä `model-tests-summary.log` sisältää testien nimet, tulokset ja ajomäärät.
Xcresult: `/tmp/choir-metronome-audit/DerivedData/Logs/Test/Test-Choir Master-2026.11.17_00-03-46-+0200.xcresult`.
Tilapäispolkujen säilymiseen myöhemmissä keskusteluissa ei pidä luottaa;
olennaiset lähteet, tulokset ja tiivisteet ovat tässä hakemistossa.

## Olemassa oleva tarkistus

```sh
xcrun swiftc -O -module-cache-path /tmp/choir-metronome-audit/cache "$CH_MET_SOURCE/AudioRenderer.swift" "$CH_MET_SOURCE/PianoSampleMetadata.swift" 'Untitled Project/Tests/AudioRenderChecks/main.swift' -o /tmp/choir-metronome-audit/existing-audio-checks
/tmp/choir-metronome-audit/existing-audio-checks "$CH_MET_SOURCE/PianoSamples"
```

Tämä ohjelma kirjoittaa myös kaksi pianotestin WAV-tiedostoa `/tmp`-hakemistoon.
Testi ajettiin uudelleen nykyisestä koodista; tulos `existing-audio.log`.
Se kattaa metronomille kaikki tahdit 240 BPM:llä, mutta muuttaa DSP-kenttiä myös
suoraan. Siksi sen rinnalle tehtiin yllä postilaatikkoa käyttävät testit.

## Muuttumattomuus

Auditin alkuun otettiin SHA-256 kaikista `Untitled Project/`-puun tiedostoista
(pl. `.git`). Lopun vertailu antoi muuttuneiden listaksi `[]`.
`source-snapshot.json` säilyttää oleellisten testattujen lähteiden tiivisteet.
Tuotantokoodiin, projektiasetuksiin tai sovelluksen testitiedostoon ei tehty
muutoksia auditointivaiheen aikana. Commitia ei tehty.
