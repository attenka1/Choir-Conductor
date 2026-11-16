# 01 — Projektin kartoitus

Alkuperäinen kartoitus: 2026-11-16. Kopioitu ja olennaiset viitteet tarkistettu 2026-11-17 käyttäjän luvalla `choir-conductor/`-pohjasta. Vaiheen 1 aikana ei ajettu sovellusta tai testejä. Vaiheen 2 uudet ajot ja löydökset ovat `03-METRONOME.md`-raportissa. Auditointi ei muuttanut tuotantokoodia. Alla olevat muiden osa-alueiden luokitukset ovat alustavaa kartoitusta, eivät ajamalla todistettua laatua.

Choir Master on iOS-sovellus kuoroharjoitukseen. Virallinen näyttönimi on Choir Master. Kehityskoneen työtilakansio ja bundle ID sisältävät vanhan nimen Choir Conductor. Ne eivät ole kotinäytön nimeä.

## Puu

Voimassa oleva koodi on `Untitled Project/`. Työtilan juuren kopioita ei käytetä lähteenä.

| Polku | Rooli |
| --- | --- |
| `Untitled Project/Choir Master.xcodeproj` | Ainoa käännettävä projekti. Scheme `Choir Master`. |
| `Untitled Project/Choir Master/` | 25 Swift-tiedostoa, kielet, 25 WAV-näytettä, SoundFont, kuvakkeet |
| `Untitled Project/Choir MasterTests/ReliabilityTests.swift` | Yksi XCTest-tiedosto, 30 testimetodia (kuusi lisätty ennen metronomiauditointia) |
| `Untitled Project/Tests/` | Kahdeksan erillistä `swiftc`-tarkistusta, eivät Xcode-testikohteessa |
| `Untitled Project/AdMob-Info.plist` | Mainosten sovellustunnus ja SKAdNetwork-lista |
| `Untitled Project/Choir Conductor.xcodeproj` | Ei `project.pbxproj`-tiedostoa. Ei käänny. |
| `Untitled Project/SPEC.md` | Android-suunnitelma, ei iOS-toteutuksen kuvaus |

Swift-tiedostot sovelluksessa:

`ChoirMasterApp.swift`, `ContentView.swift`, `ConductorModel.swift`, `AudioSessionCoordinator.swift`, `AudioEngine.swift`, `AudioRenderer.swift`, `ReferenceOscillator.swift`, `ReferenceTone.swift`, `PianoKeyboard.swift`, `PianoSampleMetadata.swift`, `Temperament.swift`, `NoteNaming.swift`, `Localization.swift`, `SavedChord.swift`, `ChordLibraryView.swift`, `TunerView.swift`, `LiveTuner.swift`, `PitchDetector.swift`, `RecordingManager.swift`, `RecordingStore.swift`, `RecordingView.swift`, `RecordingPitchAnalysis.swift`, `RecordingAnalysisStore.swift`, `RecordingAnalysisView.swift`, `SettingsBanner.swift`.

## Alusta ja riippuvuudet

Tiedosto `Choir Master.xcodeproj/project.pbxproj`.

| Asetus | Arvo | Huomio |
| --- | --- | --- |
| Kieli | Swift 5.0 | |
| Käyttöliittymä | SwiftUI, koskettimisto UIKit | `PianoKeyboard` on `UIViewRepresentable` |
| Ääni | AVFoundation | Yksi session-omistaja |
| Laskenta | Accelerate | Virittimen ja analyysin FFT |
| Kaaviot | Swift Charts | Analyysinäkymä |
| iOS-minimi, kohde | 17.0 | |
| iOS-minimi, projektin oletus | 17.0 | Molemmat projektikonfiguraatiot ja sovellus-/testikohteet tarkistettu nykyisestä pbxproj:sta |
| Versio | 1.0.1 (2) | |
| Bundle ID | `com.atte.tenkanen.ChoirConductor` | Pysyvä. Ei muuteta nimen vuoksi. |
| Testien bundle ID | `com.atte.tenkanen.ChoirConductor.Tests` | |
| Näyttönimi | Choir Master | Build-asetus ja `InfoPlist.strings` |
| Suunta | iPhone pysty ja vaaka, ei ylösalaisin. iPad kaikki neljä. | |
| SPM | GoogleMobileAds 13.11.0, GoogleUserMessagingPlatform 3.1.0 | `Package.resolved` |

Ei CocoaPodsia. Ei omaa palvelinta. Ei `UIBackgroundModes`-avainta. Ainoa käyttöoikeusselite on mikrofoni. Kameraa, sijaintia, kuvia, seurantaa ja Bluetooth-käyttökuvausta ei ole projektissa.

## Käynnistys ja tietovirta

`ChoirMasterApp` avaa yhden `WindowGroup`in ja `ContentView`n. Näkymä luo `ConductorModel`in. Malli luo `AudioSessionCoordinator`in, `RecordingManager`in ja `LiveTuner`in, lukee `UserDefaults.standard`-avaimet ja yrittää käynnistää `ChoirAudio`n.

Sessionin asiakkaat ovat `sound`, `recording`, `playback` ja `tuner`. Metronomi ja piano käyttävät samaa soittoengineä. Mittarilla on toinen `AVAudioEngine`. Tallennus käyttää `AVAudioRecorder`ia.

Taustalle meno kutsuu `flushSettings` ja `stopAll` (`ContentView.swift` rivi 65). Inactive-tilaa ei käsitellä. Näytön lukitusajastin sammutetaan, kun metronomi käy, äänitys tai mittari on asiakkaana tai jokin ääni on päällä (`ConductorModel.refreshIdleTimer`, nykyiset rivit 273–274).

Tallennus:

- Asetukset ja soinnut: `UserDefaults.standard`. Avaimet eivät sisällä tuotenimeä. Sointuavain on `savedChords.v1`.
- Äänitteet: säiliön `Documents/Recordings`, indeksi `index.json`.
- Analyysivälimuisti: äänitteen vieressä oleva `Analysis`-kansio.
- Näytteet ja SoundFont: sovelluspaketti.

## Ominaisuudet

Luokka kuvaa koodipolun, ei mitattua oikeellisuutta. Vaiheen 1 aikana yhtään kohtaa ei ajettu; metronomirivin myöhempi ajokattavuus on päivitetty alle ja raporttiin 03. Siksi mikään ei ole luokkaa A merkityksessä ”todettu toimivaksi ajamalla”. Taulukko käyttää A-polkua: ominaisuus on kytketty käyttöliittymään ja koodi näyttää vievän sen loppuun. Toimivuus siirtyy luokkaan E, kunnes myöhempi vaihe ajaa sen.

| Ominaisuus | Luokka | Koodi | Mitä ei vielä tiedetä |
| --- | --- | --- | --- |
| Metronomi 30–240, nuolet, numerokenttä, tahtilaji 1–16 ja nimittäjä 1/2/4/8/16 | A-polku, offline-ajoitus todennettu vaiheessa 2 | `ConductorModel` 151–190 ja 264–288; `AudioRenderer.render` 101–125 | Fyysinen jitter, drift ja realtime-kuorma avoinna. UI-ajastin ei ole äänen kello. |
| 6/8: kaksi tai kuusi iskua, rajattu muunnos ja lähtötempon palautusmuisti | A-polku, vaiheessa 2 testattu | `setCompound` 312–327 | Saman mallin 422 suoraa edestakaista tapausta läpäisi. MET-001 rajanuoli ja MET-002 uudelleenalustus avoinna. |
| Piano C2–C6, monikosketus, pito, hiljennä | A-polku, ääni E | `PianoKeyboard`, `AudioRenderer` | Särö, jumittuvat äänet ja eri näytöt laitteella |
| 24-tasavire, koskettimen puolikkaat | A-polku | `divisions`, koskettimiston jako | Osumatarkkuus sormella |
| A4 415, 440, 442 ja oma 300–500 Hz | A-polku | Asetusten valitsin | 415 on korkeus, ei oma viritysjärjestelmä |
| Seitsemän viritystä: tasavire, luonnonvire, Pythagoralainen, ¼-komman keskisävel, Werckmeister III, Kirnberger III, Vallotti | A-polku, kaavat E | `Temperament.swift` | Riippumaton senttitaulu ja ulostulotaajuus |
| Jatkuva viritysääni, tarkka oskillaattori tai SoundFont | A-polku | `ReferenceTone`, `ReferenceOscillator` | SoundFontin sävelpuhtaus |
| Viritysmittari, YIN, valittu viritys | A-polku, kuuntelu E | `LiveTuner`, `PitchDetector` | Kahden enginen ja kaiutinvuodon vaikutus |
| Sointumuisti | A-polku | `ChordStore`, `ChordLibraryView` | |
| Äänitys, AAC 44,1 kHz mono, enintään 2 h, tuonti, toisto, jako, nimeäminen, poisto | A-polku, tiedosto E | `RecordingManager.start`, `ShareLink` | Levy täynnä, puhelu, USB-mikrofoni |
| Äänitteen säveltasokäyrä | B | `RecordingPitchAnalysis` | Yksi yhteinen käyrä, ei stemmoja. Tarkkuutta ei ole mitattu kuorolla. |
| 31 kieltä, suunta vasemmalta oikealle tai päinvastoin | A-polku, laatu E | `Localization.swift` | Käännöksiä ei luettu ihmissilmin |
| VoiceOver-nimiä ja koskettimen aktivointi | A-polku | `PianoKeyboard` | Ruudunlukijaa ei ajettu |
| Dynamic Type | D tässä tuotteessa | Ei `@ScaledMetric`- tai `dynamicTypeSize`-käyttöä | Kiinteät fontit |
| Mainos asetuksissa, kun ääni on vapaa | A-polku, verkko E | `SettingsBanner` | Lomakkeen näkyminen |
| Taustalle meno pysäyttää äänen ja äänityksen | A-polku | `scenePhase == .background` | Puhelua ja Control Centeria ei ajettu |
| USB-mikrofonin valinta, AKG Lyra, PCM-tallenne, tason mittari | D vain Android-suunnitelmassa | Ei iOS-koodipolussa. `SPEC.md` sanoo olevansa Android-vaatimus. | Ei iOS-puute, ellei tuote sitä erikseen vaadi |
| Reaaliaikainen kuoroanalyysi, stemmojen erottelu, nuottivirheet, pilvi | D, rajattu pois | `SPEC.md` sanoo, ettei näitä tehdä tässä vaiheessa | |
| `Mikrofonin käyttölupa` Localizable-avaimessa | C | Avain on tauluissa. Swift ei kutsu sitä. Järjestelmä käyttää `InfoPlist.strings`. | |

## Testit, joita ei ajettu

Vaiheen 1 luettelo (ei silloin ajettu): Xcode-kohde `ChoirMasterTests`, scheme `Choir Master`, yksi tiedosto. Metronomivaiheen neljä lisätestiä olivat vain tilapäiskopiossa; niiden ajotiedot raportissa 03. Metodit: tuonti ja analyysi, keskeytykset, mittarin kohdesävelet, 6/8 ja näytön hereilläpito, mainosten session, sointujen vioittuminen, näytteiden metadata, SoundFontin puute, 24-sävelinen kosketin.

Erilliset ohjelmat hakemistossa `Untitled Project/Tests/`: temperamentti, pitch, audio render, recording store, chord store, reference tone, reference pitch sweep, recording analysis. AnalysisLab on Python-koe, ei sovelluksen osa.

Käyttöliittymätestejä ei ole. Fysikaalista mittauslaitteistoa ei ole projektissa.

## Alustava arkkitehtuuri

Tämä ei ole vaiheen 8 arvio.

```
ChoirMasterApp
  ContentView
    ConductorModel
      AudioSessionCoordinator
      ChoirAudio (AudioEngine.swift)
        AudioRenderer      näytekello: piano ja metronomi
        ReferenceTone      oskillaattori tai SoundFont
      RecordingManager     AVAudioRecorder / AVAudioPlayer
      LiveTuner            toinen AVAudioEngine, YIN
    PianoKeyboard
    TunerView, RecordingView, ChordLibraryView, SettingsBanner
```

Audiosäie lukee komennot `NSLock.try()`-postilaatikosta (`AudioRenderer.consumeControls`). Se ei odota käyttöliittymää. Tämä on rakenteellinen havainto, ei vielä kuormitusmittaus.

## Päivitettyjen viitteiden tarkistus 17.11.2026

Varmistettu nykyisistä tiedostoista: 25 Swift-lähdettä; 30 tuotanto-XCTest-metodia;
`ChoirMasterApp` → `ContentView` → `ConductorModel`; sheettien ja metronomin
kytkennät; `AudioEngine`-tiedoston luokka on `ChoirAudio`; scheme TestAction;
SPM-pinien versiot 13.11.0/3.1.0; näyttönimi, bundle ID ja kaikkien kuuden
deployment target -asetuksen arvo 17.0. Aiemman kartoituksen 27.0 ja 24 testiä
eivät enää kuvaa tätä työpuuta. Android-SPEC ei ole iOS-vaatimus.

Muiden osa-alueiden yksityiskohtaisia toimivuusväitteitä ei hyväksytä valmiiksi
auditoiduiksi tämän kopioinnin vuoksi. Dynaamisen tekstin ja mainosten
luokitukset tarkennetaan vasta niitä koskevissa vaiheissa.
