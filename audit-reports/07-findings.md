# 07 — Havainnot

Vakavuudet: CRITICAL, HIGH, MEDIUM, LOW, IMPROVEMENT.

Varmuustaso: todistettu, todennäköinen, epäily.

CRITICAL- tai HIGH-havaintoja ei jäänyt tämän ajon todisteiden perusteella. Aiemmin epäillyt istunnon jumittuminen, tasavireinen mittari ja HFP-profiili on korjattu koodissa, ja vastaavat XCTestit läpäisivät. Tätä ei pidä lukea niin, että laite olisi testattu.

## F-001 — 6/8-tempon muunnos ei ole käänteinen

- Vakavuus: MEDIUM
- Varmuus: todistettu kaavan tasolla. Sovellusoliota ei kutsuttu tälle syötteelle. XCTest kattaa vain 60 ↔ 180 ja läpäisi.
- Sijainti: `Untitled Project/Choir Master/ConductorModel.swift`, `setCompound`, rivit 298–305. Valitsin: `ContentView.swift` rivi 104. Yleinen kuvateksti: sama tiedosto rivit 102–103, avain `Analysis.strings` (fi ja en). Muutosloki: `Untitled Project/RELIABILITY.md` rivit 86–88. Loki ja kuvateksti vastaavat toisiaan. Aiempi väite, että varoitusta ei ole, oli virheellinen.
- Kuvaus: pistetahtiin siirryttäessä tempo jaetaan kolmella, pyöristetään ja rajataan 30–240. Kahdeksasosiin siirryttäessä tempo kerrotaan kolmella ja rajataan. Oletus 80 pistetahdissa palaa (80 → 240 → 80). Tempo 96 pistetahdissa muuttuu 240:ksi ja takaisin 80:ksi. Tempo 80 kahdeksasosatilassa muuttuu 30:ksi ja takaisin 90:ksi. Pythonilla 160 tempoa kumpaankin suuntaan väliltä 30–240 ei palaa. Kuvateksti sanoo, että vaihto muuntaa BPM-luvun ja että alue voi rajoittaa muunnosta. Se ei näytä tulevaa lukua eikä estä vaihtoa, joka hävittää alkuperäisen tempon. Koodikommentti rivillä 300 sanoo tahdin keston säilyvän. Raja- ja pyöristystapauksissa se ei säily.
- Toisto: aseta 6/8, pistetahti, tempo 96. Vaihda kuuteen kahdeksasosaan. Tempo on 240. Vaihda takaisin. Tempo on 80. Kuvateksti pysyy samana.
- Vaikutus: harjoituksen nopeus voi muuttua. Käyttäjä näkee uuden BPM-luvun vasta vaihdon jälkeen.
- Korjaus: näytä tuleva BPM ennen vaihtoa, tai säilytä alkuperäinen tempo, jos jako ja rajat eivät ole käänteisiä. Nykyinen kuvateksti voi jäädä. Lisää testi tempolle 96 ja tempolle 80 kahdeksasosatilassa.
- Testaus: XCTest, joka vertaa `tempo`-arvoa ennen ja jälkeen edestakaisen vaihdon.

## F-002 — Virittimen vertailuääni jättää päänäkymän viritysäänitilaan

- Vakavuus: MEDIUM
- Varmuus: todistettu koodipolusta. Käyttöliittymää ei klikattu.
- Sijainti: `ConductorModel.playTunerReference`, rivit 293–296. `TunerView.onDisappear`, rivi 87, kutsuu `stopReference` ja `tuner.stop`. `stopReference` on `silencePiano`, joka ei aseta `soundMode`-arvoa.
- Kuvaus: vertailuäänen kytkentä asettaa `soundMode = .reference`. Sheetin sulkeminen hiljentää äänen ja pysäyttää mittarin. Pianon ja viritysäänen valitsin jää viritysääneen. Seuraava kosketin soittaa yhtä jatkuvaa säveltä, ei sointua.
- Toisto: avaa mittari, aloita kuuntelu, kytke vertailuääni, sulje näkymä. Päänäkymän valitsin on Viritysääni.
- Vaikutus: tila ja käyttäjän odotus eroavat. Ääni itsessään on hiljennetty.
- Korjaus: palauta `soundMode` arvoon, joka oli ennen mittaria, kun vertailu sammutetaan tai näkymä suljetaan.
- Testaus: XCTest, joka asettaa tilan pianoksi, kutsuu `playTunerReference`-funktiota ja tarkistaa tilan `silencePiano`-kutsun jälkeen. Nykyisin sellaista testiä ei ole.

## F-003 — Äänen alustusvirhe voi kadota sointuvirheen alle

- Vakavuus: LOW
- Varmuus: todistettu järjestyksestä. Kaksoisvirhettä ei ajettu.
- Sijainti: `ConductorModel.init`, rivit 91–92.
- Kuvaus: `self.error` saa ensin äänen alustusvirheen ja heti perään sointuarkiston virheen, jos molemmat heittävät. Käyttäjä näkee vain jälkimmäisen.
- Toisto: riko näytemetadata ja sointu-JSON samassa asennuksessa.
- Vaikutus: piano puuttuu, mutta ilmoitus puhuu soinnuista.
- Korjaus: pidä virheet erillään tai ketjuta molemmat tekstit.
- Testaus: alustus, jossa kumpikin lataus heittää, ja väite että molemmat viestit näkyvät.

## F-004 — README ei vastaa näytön hereilläpitoa

- Vakavuus: LOW
- Varmuus: todistettu tekstivertailulla.
- Sijainti: `Untitled Project/README.md` rivi 17. Koodi: `ConductorModel.refreshIdleTimer`, rivit 266–267. Testi `testCompoundConversionAndHeldChordKeepScreenAwake` odottaa, että pidetty sointu pitää näytön hereillä.
- Kuvaus: README sanoo, että näyttö pysyy hereillä metronomin, äänityksen ja viritysäänen aikana. Koodi lisää ehdon `!sounding.isEmpty`, joten myös pianon pito estää lukituksen. Juuren `README.md` eroaa `Untitled Project/README.md`-tiedostosta; sama puutteellinen lause on luettu `Untitled Project` -kopiosta.
- Vaikutus: dokumentaatio aliarvioi toteutuksen. Ei käyttäjän toiminnallinen vika.
- Korjaus: päivitä README vastaamaan `refreshIdleTimer`-ehtoja.
- Testaus: ei ajonaikainen. Tekstin ja koodin vertailu riittää.

## F-005 — Kaksi dokumentti- ja työkalupuuta

- Vakavuus: LOW
- Varmuus: todistettu `diff -rq` -ajolla.
- Sijainti: työtilan juuri ja `Untitled Project/`. Eroavat ainakin `README.md`, `Tools/finish_localizations.py` ja `Tools/generate_localizations.py`. `Untitled Project/Choir Conductor.xcodeproj` ei sisällä `project.pbxproj`-tiedostoa.
- Kuvaus: voimassa oleva sovellus on `Untitled Project`. Juuren kopiot voivat näyttää samalta ja jäädä jälkeen. Juuren lokalisaatioskripti osoittaa oikeaan sovelluskansioon ja läpäisi, joten se ei ole tällä hetkellä rikki.
- Vaikutus: väärän puun muokkaus ei päivity sovellukseen.
- Korjaus: yksi juuri, tai selkeä README joka sanoo juuren kopiot vanhoiksi.
- Testaus: `diff -rq` julkaisun yhteydessä.

## F-006 — Äänenvoimakkuuden otsikko käännetään kahdesti

- Vakavuus: IMPROVEMENT
- Varmuus: koodi on todistettu. Väärä käyttäjälle näkyvä merkkijonoa ei osoitettu. Lokalisaatiotesti läpäisi.
- Sijainti: `ContentView.volume`, rivit 155–156. Kutsut rivit 38, 41, 45 ja 214 antavat argumentiksi `T("…")`.
- Kuvaus: funktion sisällä `T(title)` hakee jo käännettyä tekstiä avaimena. Jos avainta ei löydy, Apple palauttaa avaimen, joten teksti sattuu säilymään. Törmäys toiseen avaimeen vaihtaisi tekstin.
- Korjaus: välitä käännösavain, ei käännettyä merkkijonoa.
- Testaus: yksikkö, joka antaa suomen- ja englanninkielisen avaimen ja vertaa otsikkoa tauluun.

## F-007 — Kaksi AVAudioEngineä vertailuäänen aikana

- Vakavuus: MEDIUM
- Varmuus: epäily. Koodipolku on olemassa. Häiriötä ei toistettu.
- Sijainti: `LiveTuner.start` rivi 116 luo enginen. `playTunerReference` → `noteDown` → `ChoirAudio.start` käynnistää toisen, jos vertailu kytketään mittarin jo kuunnellessa.
- Kuvaus: Apple kohtelee useaa engineä samassa prosessissa herkkänä. Session on jaettu ja vertailu on tarkoituksellinen. Katkos, reitin vaihto tai mittarin virheellinen sävel kaiuttimen vuodon takia on mahdollinen. Näkymä varoittaa kaiuttimesta.
- Korjaus: yksi engine, jonka input-tap ja soitto ovat samassa graafissa. Laitekoe kuulokkeilla ja kaiuttimella.
- Testaus: fyysinen iPhone, vertailu päällä, laulu mikrofoniin, kuuloke ja kaiutin erikseen.

## F-008 — Suostumuslomake ilman view controlleria

- Vakavuus: LOW
- Varmuus: epäily. Lomaketta ei avattu.
- Sijainti: `SettingsBanner.swift`, `AdsConsent.prepare` rivi 19 ja `showPrivacyOptions` rivi 34.
- Kuvaus: `from: nil` jättää näkymänhaun SDK:lle. Jos lomake ei tule näkyviin, käyttäjä ei saa suostumusvalintaa, ja virhe jää lokiin.
- Korjaus: välitä asetussivun näkyvä `UIViewController`. Näytä virhe käyttöliittymässä.
- Testaus: simulaattori alueella, joka vaatii UMP-lomakkeen. Verkko tarvitaan. Ei ajettu.

## F-009 — Mainosriippuvuuden ja tietosuojalomakkeen katve

- Vakavuus: IMPROVEMENT
- Varmuus: todistettu siitä, mitä projektissa ei ole. Ei todistettu App Store -hylkäystä.
- Sijainti: `Package.resolved` (GoogleMobileAds 13.11.0, UMP 3.1.0). Ei `NSUserTrackingUsageDescription`-avainta. Ei sovelluksen omaa `PrivacyInfo.xcprivacy`-tiedostoa. SDK:n manifestia ei luettu.
- Kuvaus: paikallinen äänisovellus avaa mainos-SDK:n asetuksissa. Seurannan ravintosisältö ja mahdollinen ATT-velvoite pitää tarkistaa ennen julkaisua. SDK:n haavoittuvuuksia ei skannattu.
- Korjaus: arkistoi privacy report, täytä App Store -lomake SDK:n datan mukaan, päätä tarvitaanko ATT.
- Testaus: Release-arkisto ja Xcoden privacy report.

## F-010 — Projektitason deployment target on 27.0

- Vakavuus: LOW
- Varmuus: todistettu `project.pbxproj`-tiedostosta.
- Sijainti: rivit 280 ja 344, arvo 27.0. Sovellus- ja testikohde rivit 383, 432, 463 ja 481, arvo 17.0.
- Kuvaus: nykyiset kohteet eivät peri 27.0:aa. Uusi kohde ilman omaa arvoa vaatisi iOS 27:n.
- Korjaus: aseta projektin oletus 17.0:ksi.
- Testaus: `xcodebuild -showBuildSettings` uudelle kohteelle.

## F-011 — Osassa lupadialogeja tuotenimen perässä on käännetty rooli

- Vakavuus: IMPROVEMENT
- Varmuus: todistettu merkkijonoista. Dialogia ei avattu laitteella.
- Sijainti: 26 tiedostoa `*/InfoPlist.strings`, avain `NSMicrophoneUsageDescription`. Esimerkki: `hi.lproj/InfoPlist.strings` rivi 1. Sama kaava on käyttämättömässä avaimessa `Mikrofonin käyttölupa` vastaavissa `Localizable.strings`-tiedostoissa. Swift ei viittaa siihen avaimeen.
- Kuvaus: englanti, suomi, tagalog, amhara ja Nigerian Pidgin nimeävät sovelluksen Choir Masteriksi ilman toista nimeä. Muissa 26 kielessä lause on muotoa `Choir Master:` ja sen perässä käännös roolista kuoronjohtaja. Merkkijonoa `Choir Conductor` ei ole käyttöliittymässä. Kotinäyttö, päänäkymän otsikko ja `CFBundleDisplayName` ovat kaikissa 31 kielessä Choir Master.
- Vaikutus: järjestelmän lupadialogi voi näyttää kahdelta nimeltä. Päivitys ja tallennetut tiedot eivät riipu tästä tekstistä.
- Korjaus: kirjoita lupateksti samaan tapaan kuin englannissa: Choir Master käyttää mikrofonia. Älä muuta bundle ID:tä.
- Testaus: vaihda simulaattorin kieli ja avaa mikrofonilupa ensimmäisen kerran. Vertaa tekstiä `InfoPlist.strings`-tiedostoon.

## F-012 — Vanha projektinimi on vain kehityskoneella

- Vakavuus: LOW
- Varmuus: todistettu hakemistolistauksella ja merkkijonohaulla.
- Sijainti: työtilan juuri `Choir Conductor`. `Untitled Project/Choir Conductor.xcodeproj` sisältää vain `project.xcworkspace`-kansion, ei `project.pbxproj`-tiedostoa.
- Kuvaus: asennettavan Choir Masterin kohde, scheme ja tuote ovat `Choir Master`. Vanhaa nimeä ei kopioida puhelimeen tästä tyhjästä projektihakemistosta. Macin kansion nimi ei näy käyttäjälle.
- Vaikutus: väärän `.xcodeproj`-kansion avaaminen ei käännä sovellusta. Se ei riko jo asennettua versiota.
- Korjaus: jätä bundle ID ennalleen. Tyhjän projektihakemiston voi poistaa myöhemmin, kun varmistetaan, ettei siihen ole viittauksia.
- Testaus: hae `Choir Conductor` lähteistä ja kielitauluista. Osuma saa jäädä vain dokumentaation bundle ID -selitykseen ja tähän kehityskansion nimeen.

## Hylätyt tai vanhentuneet epäilyt

Näitä ei kirjata avoimiksi vioiksi:

- Istunto jää `playAndRecord`-tilaan äänityksen jälkeen. `reconcile` palauttaa `.playback`. Testi läpäisi.
- Mittari on vain tasavireinen. `TunerPitch.target` käyttää valittua järjestelmää. Testi läpäisi kaikilla pohjasävelillä.
- Bluetooth-HFP on päällä. Valinnoissa on A2DP, ei HFP. Testi tarkisti liput, ei kuuloketta.
- Pianon pito ei pidä näyttöä hereillä. `refreshIdleTimer` ja XCTest osoittavat päinvastaista. README on vanha (F-004).
- SoundFontin puute estää pianon. `configure` vaihtaa tarkkaan ääneen. Testi läpäisi.
- Kosketin ja sointulista käyttävät eri enharmonioita. `NoteNaming` on yhteinen. Testi läpäisi.
- Erillisen analyysiajon hiekkalaatikkokaatuminen. XCTestin analyysitestit läpäisivät. Katso `06-test-results.md`.
- Bundle ID `com.atte.tenkanen.ChoirConductor` ei ole nimen jäänne, joka pitäisi korjata. Se on päivityksen ja tallennussäiliön tunniste. Näyttönimi on jo Choir Master.
