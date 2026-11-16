# 09 — Kattavuus ja oman analyysin tarkastus

## Mitä luettiin

Sovelluksen kaikki 27 Swift-tiedostoa avattiin. Täysin tässä ajossa luettiin ainakin: `AudioSessionCoordinator`, `ConductorModel`, `PitchDetector`, `LiveTuner`, `RecordingManager`, `RecordingStore`, `AudioRenderer`, `AudioEngine`, `ReferenceOscillator`, `SettingsBanner`, `TunerView`, `ChoirMasterApp`, `Localization`, `PianoSampleMetadata` (rakenne ja tarkistusehdot), `NoteNaming` (koko tiedosto aiemmin, kutsupolku nyt), `Temperament` (testin kautta ja aiempi luku).

`RecordingPitchAnalysis.swift`: jakson nollaus (`estimate`, rivit 242–245) luettiin nykyisestä tiedostosta. FFT- ja `observe`-runko on luettu saman työketjun aiemmassa läpikäynnissä. Tiedosto on muuttunut sen jälkeen ainakin `previous = nil` -rivin verran. Koko FFT-silmukkaa ei luettu uudelleen rivi riviltä tämän raportin kirjoitushetkellä. XCTest kattoi synteettisen analyysin.

`ContentView`, `PianoKeyboard`, `RecordingView`, `RecordingAnalysisView`, `ChordLibraryView`, `SavedChord` ja `ReferenceTone` luettiin joko kokonaan tai oleellisten polkujen osalta (rivinumerot havainnoissa).

31 kielen sanastoa ei luettu ihmissilmin. Skripti tarkisti avaimet, tyhjät arvot ja `%@`-määrät.

WAV- ja SF2-binäärejä ei kuunneltu eikä purettu. Metadatan ja näytteiden vastaavuus meni XCTestissä.

## Mitä ajettiin

Katso `06-test-results.md`. Lyhyesti: 24 XCTestiä PASS iPhone 16 Pro / iOS 18.5 -simulaattorissa. Viisi erillistä Swift-tarkistusta PASS. Kaksi lokalisaatioajoa PASS. 6/8-kaava PASS/FAIL laskettiin Pythonilla, ei sovellusoliolla. Analyysin erillisajo kaatui hiekkalaatikossa, eikä sitä uusittu. AnalysisLabia, Android-JAR-vertailua, linttiä, fyysistä puhelinta, Bluetoothia, mikrofonia ja mainoslomaketta ei ajettu.

## Nimitarkistus 2026-11-16

Haettiin `Choir Conductor`, `Choir Master`, `CFBundleDisplayName`, `PRODUCT_NAME` ja `PRODUCT_BUNDLE_IDENTIFIER` lähteistä, kielitauluista, `project.pbxproj`-tiedostosta ja schemestä. Luettiin `ContentView.swift` rivit 24 ja 230–235, `RecordingManager.swift` rivi 28, `SavedChord.swift` avain `savedChords.v1` ja `ConductorModel.swift` UserDefaults-avaimet. App Store Connectia ei avattu. Kaupan tietueen vastaavuus perustuu projektin README- ja RELIABILITY-merkintään, ei erilliseen kaupan tarkistukseen.

## Mitä ei analysoitu

- Google Mobile Ads- ja UMP-kirjastojen lähdekoodi.
- `PrivacyInfo.xcprivacy` SDK-paketin sisällä.
- Jokaisen käännöksen merkitys.
- Kuoron analyysitarkkuus oikealla äänellä.
- Katkosten ja viiveen mittaus laitteella.
- `Untitled Project/Choir Conductor.xcodeproj` muuta kuin sen toteamista, että `project.pbxproj` puuttuu.

Arvio: sovelluksen oma toimintalogiikka on käyty läpi noin 90-prosenttisesti tiedostojen tasolla. Rivikohtainen varmuus on korkea sessiossa, mallissa, virittimessä, äänityksessä ja rendererissä. Se on matalampi lokalisaatioteksteissä, binääriresursseissa ja SDK:ssa. Sataa prosenttia koko työtilasta, mukaan lukien 31 kieltä ja mainos-SDK, ei saavutettu.

## Oman analyysin tarkastus

Ennen raporttia hylättiin vakavilta kuulostaneet väitteet, jotka koodi ja testit kumoavat. Lista on `07-findings.md`-tiedoston lopussa. Erityisesti:

- Näytön hereilläpito pianolle on toteutettu. Virhe on README:ssa (F-004), ei puuttuva ominaisuus.
- Oletustempo 80 pistetahdissa säilyy 6/8-vaihdossa. F-001 rajattiin koskemaan niitä tempoja, joissa jako, pyöristys tai 240 BPM -katto muuttaa luvun. Sitä ei kuvata niin, että oletuspolku olisi rikki.
- F-007 jätettiin epäilyksi. Koodi käynnistää kaksi engineä, mutta epäonnistumista ei nähty.
- F-008 jätettiin epäilyksi. `nil`-view-controller on riski, ei todistettu bugi.
- Erillisajon analyysikaatumista ei nostettu sovellusviaksi, koska simulaattorin XCTest läpäisi saman algoritmin.

Jäljelle jäänyt mahdollinen sokea piste: `RecordingPitchAnalysis.observe` on voinut muuttua sen täyden luvun jälkeen. Jos sieltä löytyy virhe, tämä raportti ei ole sitä sulkenut. Synteettinen XCTest ei korvaa sitä aukkoa kokonaan.

Toinen sokea piste: käyttöliittymää ei klikattu. F-002 on päätelty kutsupolusta. Uusintaluku vahvisti, että `silencePiano` (rivit 206–211) ei sijoita `soundMode`-arvoa. Rivin 213 sijoitus on `prepareChordSelection`, ei hiljennys. `soundMode`-didSet kutsuu hiljennystä eikä palauta tilaa pianoksi. `prepareTuner` kutsuu `stopSound`, joka ei vaihda tilaa.

## Ristiriidat, joita ei siloteltu

- Ensimmäinen lukukerta piti `ContentView.swift` riviä 104 pelkkänä valitsimena ja väitti, että 6/8-varoitusta ei ole. Uusi luku näytti rivit 102–103 ja `Analysis.strings`-avaimen. `RELIABILITY.md` rivit 86–88 pitävät. Ristiriita peruttiin. Jäljelle jää se, että kuvateksti ei näytä tulevaa BPM-lukua ja että muunnos ei ole käänteinen.
- README ja `refreshIdleTimer` eivät kuvaa samaa hereilläpitoa.
- Tekijän muutosloki puhuu 21 tai 17 testistä eri kohdissa. Tässä ajossa läpäisi 24 testiä. Luku on kasvanut tuonnin ja keskeytyskorjausten jälkeen. Loki on jäljessä, testit eivät ole ristiriidassa keskenään.
