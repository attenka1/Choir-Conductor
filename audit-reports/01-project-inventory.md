# 01 — Projektin kartoitus

Päiväys: 2026-11-16. Työkalut: Xcode 27.2 (build 27B52), Python 3.9.4. Lähdekoodia ei muutettu.

## Juuri ja kaksoiskappaleet

Työtilan juuri on `/Users/attetenkanen/AndroidStudioProjects/Choir Conductor`. Ajettava sovellus on hakemistossa `Untitled Project/`.

| Polku | Rooli |
| --- | --- |
| `Untitled Project/Choir Master.xcodeproj` | Voimassa oleva Xcode-projekti ja jaettu scheme `Choir Master` |
| `Untitled Project/Choir Master/` | Sovelluskohde, 27 Swift-tiedostoa, lokalisoinnit, näytteet, SoundFont |
| `Untitled Project/Choir MasterTests/ReliabilityTests.swift` | XCTest, 24 testimetodia |
| `Untitled Project/Tests/` | Erilliset `swiftc`-tarkistukset |
| `Untitled Project/Tools/` | Lokalisointiskriptit ja lähde-JSON |
| `Untitled Project/AnalysisLab/` | Python-koe, ei sovelluksen ajonaikainen osa |
| `Untitled Project/AdMob-Info.plist` | Google AdMob -sovellustunnus ja SKAdNetwork-lista |
| `Untitled Project/RELIABILITY.md` | Tekijän oma muutosloki |
| `Untitled Project/Choir Conductor.xcodeproj` | Vain `project.xcworkspace`, ei `project.pbxproj`. Ei käännettävä projekti |
| Työtilan juuren `Tests/`, `Tools/`, `README.md` | Kopioita. Osa tiedostoista eroaa `Untitled Project` -puun vastaavista |

`diff -rq` 2026-11-16: juuren ja `Untitled Project`-puun `Tests/*.swift` eivät eronneet. Eroja oli tiedostoissa `README.md`, `Tools/finish_localizations.py`, `Tools/generate_localizations.py` sekä osassa testien Markdown- ja Python-tiedostoja.

## Kieli, kehykset ja riippuvuudet

- Kieli: Swift 5, käyttöliittymä SwiftUI, koskettimisto UIKit (`UIViewRepresentable`).
- Ääni: AVFoundation (`AVAudioEngine`, `AVAudioSourceNode`, `AVAudioUnitSampler`, `AVAudioRecorder`, `AVAudioPlayer`, `AVAudioFile`).
- Signaalinkäsittely: Accelerate (`vDSP`).
- Kaaviot: Swift Charts.
- Tallennus: UserDefaults (asetukset ja soinnut), Documents/Recordings (äänitteet ja analyysivälimuisti), Bundle (näytteet, SoundFont, kielet).
- Ulkoiset paketit, `Package.resolved`: GoogleMobileAds 13.11.0, GoogleUserMessagingPlatform 3.1.0.
- Android-viitteitä: `Tests/RecordingAnalysisChecks/AndroidReference.kt` ja AnalysisLab. Ne eivät käänny iOS-kohteeseen.

Ei CocoaPodsia eikä omaa palvelinosaa.

## Rakennusasetukset

Tiedosto: `Untitled Project/Choir Master.xcodeproj/project.pbxproj`.

| Asetus | Arvo |
| --- | --- |
| Sovelluksen virallinen nimi | Choir Master |
| Target Name | `Choir Master` |
| Product Name | `$(TARGET_NAME)` → `Choir Master.app` |
| Scheme | `Choir Master` |
| Näyttönimi | `INFOPLIST_KEY_CFBundleDisplayName` = Choir Master, Debug ja Release |
| Markkinointiversio | 1.0.1 |
| Build | 2 |
| Bundle ID | `com.atte.tenkanen.ChoirConductor` (pysyvä tunniste, ei näyttönimi) |
| Testien bundle ID | `com.atte.tenkanen.ChoirConductor.Tests` |
| Testikohteen nimi | `ChoirMasterTests` (sisäinen, ei kotinäyttö) |
| Sovellus- ja testikohteen iOS-minimi | 17.0 |
| Projektitason `IPHONEOS_DEPLOYMENT_TARGET` | 27.0 |
| Allekirjoitus | Automatic |
| Kategoria | `public.app-category.music` |
| Mikrofoniselite | `INFOPLIST_KEY_NSMicrophoneUsageDescription` |
| Mainokset | `AdMob-Info.plist` liitetään kohteeseen |

`NSUserTrackingUsageDescription`-avainta ei löytynyt projektista. Erillistä `PrivacyInfo.xcprivacy`-tiedostoa ei ole sovelluskansiossa. Google-SDK:n oma manifesti tulee paketista; sitä ei avattu tässä auditoinnissa.

## Nimi ja pysyvät tunnisteet

Choir Masterin näyttönimi on asetettu build-asetuksissa ja kaikissa 31 `InfoPlist.strings`-tiedostossa (`CFBundleDisplayName`). Sovelluksen otsikko on kovakoodattu: `ContentView.swift` rivi 24, `Text("Choir Master")`. Asetuksissa ei ole erillistä tuotenimeä. Merkkijonoa `Choir Conductor` ei ole Swift-lähteissä eikä kielitauluissa. Se esiintyy kehityskoneen kansiossa, tyhjässä `Untitled Project/Choir Conductor.xcodeproj`-hakemistossa ja dokumentaatiossa vain selityksenä sille, miksi bundle ID jätettiin ennalleen.

Bundle ID `com.atte.tenkanen.ChoirConductor` on tarkoituksella vanha. `Untitled Project/README.md` rivi 7 ja `RELIABILITY.md` rivi 18 sanovat sen vastaavan olemassa olevaa App Store Connect -tietuetta. App Store Connectia ei avattu, joten kaupan tietuetta ei tarkistettu tästä koneesta. Tunnistetta ei pidä muuttaa nimen yhdenmukaistamiseksi: iOS sitoo päivityksen, säiliön ja UserDefaults-alueen bundle ID:hen.

Tallennus ei sisällä tuotenimeä. `UserDefaults.standard` käyttää avaimia `tempo`, `meter`, `denominator`, `compound`, `referenceSound`, `temperament`, `tuningRoot`, `divisions`, `tuning`, `pianoVolume`, `clickVolume`, `international`, `appLanguage` ja `savedChords.v1`. Äänitteet ovat säiliön `Documents/Recordings`-kansiossa (`RecordingManager.swift` rivi 28). Analyysivälimuisti on saman äänitteen vieressä oleva `Analysis`-kansio. Näyttönimen vaihto ei siirrä eikä tyhjennä näitä. Bundle ID:n vaihto tekisi uuden asennuksen ja jättäisi vanhan säiliön orvoksi.

Sisäisiä nimiä, joita ei näytetä: jonon nimi `ChoirMaster.tuner` (`LiveTuner.swift` rivi 23) ja virhealue `ChoirChords` (`SavedChord.swift` rivi 48). Niitä ei tarvitse muuttaa.

## Sovelluksen Swift-moduulit

Kaikki polut alkavat `Untitled Project/Choir Master/`.

| Tiedosto | Tehtävä |
| --- | --- |
| `ChoirMasterApp.swift` | `@main`, yksi `WindowGroup` |
| `ContentView.swift` | Päänäkymä, metronomi, asetukset, sheetit |
| `ConductorModel.swift` | Tila, tallennus, äänen ja session ohjaus |
| `AudioSessionCoordinator.swift` | Ainoa `AVAudioSession`-omistaja |
| `AudioEngine.swift` | Näytteiden lataus ja soittoengine |
| `AudioRenderer.swift` | Piano ja metronomi näytekellossa |
| `ReferenceOscillator.swift` | Tarkka viritysääni |
| `ReferenceTone.swift` | Oskillaattori tai SoundFont |
| `PianoKeyboard.swift` | Kosketukset ja VoiceOver |
| `PianoSampleMetadata.swift` | Näytteiden silmukka- ja taajuustarkistus |
| `NoteNaming.swift` | Sävelnimet |
| `Temperament.swift` | Seitsemän viritysjärjestelmää |
| `SavedChord.swift` | Sointujen JSON |
| `ChordLibraryView.swift` | Sointulista |
| `LiveTuner.swift` | Mikrofonimoottori ja rengaspuskuri |
| `PitchDetector.swift` | YIN ja sinc-alipäästö |
| `TunerView.swift` | Mittarin näkymä |
| `RecordingManager.swift` | Äänitys, toisto, tuonti |
| `RecordingStore.swift` | Indeksi ja tiedostonimet |
| `RecordingView.swift` | Äänityspaneeli |
| `RecordingPitchAnalysis.swift` | Vaihevokooderin analyysi |
| `RecordingAnalysisStore.swift` | SHA-256-välimuisti |
| `RecordingAnalysisView.swift` | Käyrä |
| `Localization.swift` | 31 kielen valinta ja välimuisti |
| `SettingsBanner.swift` | UMP ja AdMob-banneri |

Lisäksi 31 `.lproj`-kansiota (`Localizable.strings`, `InfoPlist.strings`; suomi ja englanti myös `Tuner.strings` ja `Analysis.strings`), 25 WAV-näytettä ja `metadata.json` kansiossa `PianoSamples/`, sekä `SoundFonts/GeneralUser-GS.sf2`.

## Käynnistys

`ChoirMasterApp` luo `ContentView`n. Sen `@StateObject` luo `ConductorModel`in, joka luo `AudioSessionCoordinator`in, `RecordingManager`in ja `LiveTuner`in, lukee UserDefaultsista tempon, tahtilajin, virityksen ja äänenvoimakkuudet, yrittää luoda `ChoirAudio`n ja lataa soinnut. Äänitteiden hakemisto luetaan taustatehtävässä (`RecordingManager.loadLibrary`). Mainosten suostumusta ei kysytä käynnistyksessä vaan asetussivun bannerissa, ja vain kun `audioBusy` on epätosi.

## Analyysin ulkopuolelle jäänyt tai vain pintapuolisesti katsottu

- Kaikkia 31 kielen käännöstekstejä ei luettu ihmislukijana. Rakenne tarkistettiin skriptillä.
- `GeneralUser-GS.sf2`-binääriä ei purettu.
- 25 WAV-tiedoston äänenväriä ei kuunneltu. Metadatan ja tiedostojen vastaavuus meni XCTestissä.
- `AnalysisLab/`-pytestiä ei ajettu.
- Android-vertailuajon JAR-tiedostoa ei ajettu.
- Fyysistä iPhonea ei käytetty. Simulaattori oli iPhone 16 Pro, iOS 18.5.
- Google-SDK:n lähdekoodia ja sen privacy-manifestia ei auditoitu rivi riviltä.
