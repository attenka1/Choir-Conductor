# 03 — Toiminnallinen auditointi

Jokainen kohta erottaa sen, mikä nähtiin koodista, sen, minkä testi osoitti, ja sen, mitä ei kokeiltu.

## Metronomi

Normaali polku: `toggleMetronome` käynnistää session ja enginen, nollaa iskun ja alkaa lukea `currentBeat`. `AudioRenderer.render` lisää jakson `44100 * 60 / tempo` ja vähentää yhden näytteen kerrallaan, joten murto-osa säilyy. Erillinen render-tarkistus ja XCTestin rinnakkainen ohjaus menivät läpi.

Tahtilajin vaihto kutsuu `resetMeter`, joka nollaa iskun. Tempo vaihtuu seuraavaan jaksoon, ei kesken nykyisen jakson. Tämä on koodin tarkoituksellinen käytös.

Poikkeus: `setCompound` (`ConductorModel.swift` 298–305) muuntaa BPM:n kolmella, pyöristää kokonaisluvuksi ja rajaa 30–240. Oletus 80 ja pisteellinen neljäsosa palaa samaksi luvuksi (80 → 240 → 80). Raja pettää sen ulkopuolella. Kaava ajettiin Pythonilla samalla aritmetiikalla: pistetahtilajista kahdeksasosiin ja takaisin 160 tempoa väliltä 30–240 ei palaa. Esimerkki 96 → 240 → 80. Kahdeksasosista pistetahtiin 80 → 30 → 90. XCTest kattaa vain 60 ↔ 180. `ContentView.swift` rivit 102–103 näyttävät yleisen kuvatekstin: vaihto muuntaa BPM-luvun ja alue 30–240 voi rajoittaa muunnosta. Avain on `fi.lproj` ja `en.lproj` Analysis-tauluissa. `RELIABILITY.md` rivit 86–88 pitävät tästä. Kuvateksti ei kerro tulevaa lukua. Havainto F-001.

Syöte: tempo rajataan `setTempo`-funktiossa. Tyhjä numerokenttä ei tallenna (`commitTempo`).

## Piano ja pito

`noteDown` hylkää ei-äärellisen, alueen 36...84 ulkopuolisen ja sävelen, joka ei ole 0,5-askeleen monikerta. Pito päällä sama sävel sammutetaan uudelleenpainalluksella. Peruutus sammuttaa myös pidon aikana. Vierityskynnys on 24 pistettä (`PianoKeyboard.handleDrag`). 24-sävelisen koskettimiston leveys on vähintään `15 * 44 / 0.31` (`layoutSubviews` rivi 54), jolloin mustan koskettimen puolikas on vähintään 44 pistettä. Tätä ei mitattu näytöltä tässä auditoinnissa; kaava tarkistettiin.

`playChord` kutsuu `ensureAudio` ennen asetusten vaihtoa. Epäonnistuminen kutsuu `stopSound`, ei `recordings.stopAll` (`ensureAudio` rivi 176).

## Viritysääni

Tarkka ääni: perus + toinen ja kolmas harmoninen, yhteinen vaihe, 5 ms nousu, 18 ms voimakkuussiirtymä (`ReferenceOscillator.render`). SoundFontin puute ei kaada pianoa. Valinta palautuu tarkkaan ääneen ja asettaa virheen (`ConductorModel.configure` 145–148). XCTest `testMissingSoundFontStillProducesPreciseTone` läpäisi.

## Viritin

`prepareTuner` estää käynnistyksen äänityksen tai luvan kyselyn aikana, pysäyttää toiston ja soiton. `TunerView` näyttää temperoinnin, pohjasävelen ja 12/24-jaon. Sentit lasketaan `TunerPitch.target`. XCTest kävi kaikki järjestelmät, pohjasävelet ja sävelet 36...84 sekä neljäsosasävelen.

Vertailuääni: `playTunerReference` asettaa `soundMode = .reference` ja soittaa sävelen. Sheetin `onDisappear` kutsuu `silencePiano` ja `tuner.stop`, mutta ei palauta tilaa pianoksi. Sulkemisen jälkeen päänäkymän valitsin voi jäädä viritysääneen. Havainto F-002. Kuulokevaroitus on näkymässä (rivi 49). Kaiuttimen vuotoa mikrofoniin ei mitattu.

Kahden enginen yhtäaikaisuutta ei ajettu. Havainto F-007, epäily.

## Äänitys ja tuonti

Äänitys alkaa vasta luvan jälkeen. Epäonnistunut alku vapauttaa session ja poistaa keskeneräisen tiedoston. Kesto on enintään `2 * 60 * 60` sekuntia (`record(forDuration:)`). Lopetus lukee keston tiedostosta. Tyhjä tiedosto poistetaan.

Tuonti: pääte allowlistissa, UUID-nimi, security-scoped luku, koordinoitu kopio, `AVAudioFile`-tarkistus, enintään 2 tuntia, julkaisu vasta indeksin tallennuksen jälkeen. Virhe tai peruutus poistaa kopion. XCTest kattoi WAV-tuonnin ja analyysin, M4A:n, vanhan indeksin, virheellisen tiedoston, peruutuksen ja indeksivirheen siivouksen. Fyysistä Tiedostot-valitsinta ei käytetty.

Toisto keskeytyksen jälkeen: `begin(.playback, userInitiated: true)` nollaa parittoman keskeytystilan ja yrittää aktivointia. Järjestelmän hylkäys jää voimaan. Kaksi XCTestiä läpäisi.

Käynnistyksen taustaluku voi avata jokaisen orvon tiedoston `AVAudioPlayer`illa keston vuoksi (`loadLibrary` rivi 58). Tätä ei profiloitu. Ei osoitettu virheeksi.

## Analyysikäyrä

Käyrä on yksi yhteinen senttiluku, ei stemmoja. Näkymä sanoo tämän (`RecordingAnalysisView` noin rivi 108). Tauon jälkeinen jakso nollaa jatkuvuuden (`estimate` 242–245). XCTest `testRecordingAnalysisDecodesFileAndInvalidatesA4Cache` ja `testImportedWavIsPreservedAnalyzedAndReopened` läpäisivät. Erillinen `swiftc`-ajo kaatui hiekkalaatikossa AVFoundation-virheeseen; sitä ei tulkittu sovellusviaksi, koska sama analyysi meni simulaattorin XCTestissä. Katso `06-test-results.md`.

## Soinnut ja asetukset

Virheellinen sointu-JSON säilyy, eikä tyhjä tallennus ylikirjoita sitä. Kaksi XCTestiä läpäisi.

Jos sekä äänen alustus että sointujen luku epäonnistuvat, jälkimmäinen virhe korvaa ensimmäisen (`init` 91–92). Havainto F-003.

Äänenvoimakkuus tallennetaan 300 ms kuluttua. Taustalle meno kutsuu `flushSettings`.

`volume`-funktio saa jo käännetyn merkkijonon ja ajaa sen uudelleen `T()`-funktion läpi (`ContentView` 155–156). Nykyisillä kielitauluilla lokalisaatiotesti läpäisi, eikä väärää merkkijonoa osoitettu. Havainto F-006, parannus.

## Kielet ja saavutettavuus

31 kieltä, 123 avainta, suomi ja englanti myös viritin- ja analyysitauluissa. Skripti tarkisti paikkamerkit ja `plutil -lint`. Käännösten musiikillista laatua ei arvioitu.

VoiceOver-kosketin soittaa lyhyen sävelen (`PianoKeyAccessibilityElement`). Vaakavieritys on toteutettu. Dynaamista tekstikokoa ja oikealta vasemmalle -asettelua ei ajettu tässä auditoinnissa. Tumma tila on pakotettu pois (`.preferredColorScheme(.light)`).

## Yhdistelmät, joita ei ajettu laitteella

Metronomi ja äänitys yhtä aikaa, Bluetooth-reitti, vertailuääni ja elävä mikrofoni, mainosbanneri käynnissä olevan session rinnalla, kahden tunnin äänitys, keskeytys oikealla puhelulla. Nämä on lueteltu myös `RELIABILITY.md`-tiedostossa avoimina laitetarkistuksina.
