# 04 — Piano ja ääni

Päiväys 2026-11-17. Vaihe 3 valmis alla olevin rajauksin. Lähdetila: commit
`e523a5b`, auditin alussa puhdas työpuu. Tuotantokoodia, projektia tai alkuperäisiä
testejä ei muutettu. Uudet XCTestit ajettiin tilapäisessä projektikopiossa.
Tiedostotiivisteet ja tulokset ovat [evidenssissä](evidence/piano-2026-11-17/README.md).

## Tarkastetut lähteet ja riippuvuudet

Polut ovat sovellusrepon juuresta, eli työtilan `Untitled Project/`-kansiosta.

| Lähde | Kohdat | Kattavuus |
| --- | --- | --- |
| `Choir Master/AudioRenderer.swift` | koko tiedosto, erityisesti 59–99 ja 101–161 | Avaimet, retrigger, release, postilaatikko, aktiiviset äänet, interpolointi, loop, crossfade, yhteinen rajoitin |
| `Choir Master/PianoSampleMetadata.swift` | koko tiedosto | Resurssijärjestys, muodot, loop-indeksien invariantit |
| `Choir Master/AudioEngine.swift` | koko tiedosto | Monoesilataus, pakettihaku, bufferin validointi, node-kytkentä, start/pause/silence |
| `Choir Master/ReferenceOscillator.swift` | koko tiedosto | Vaihe, ylä-äänet, gain ja volume-rampit, start/stop, try-lock |
| `Choir Master/ReferenceTone.swift` | koko tiedosto, erityisesti 52–123 | Tarkka/SoundFont-tila, sampler-viritys, Task-siirtymät ja peruutus |
| `Choir Master/PianoKeyboard.swift` | koko tiedosto | Key geometry, 12/24-jako, kosketuskartta, swipe, cancel, VoiceOver-aktivoinnin kytkentä |
| `Choir Master/ConductorModel.swift` | 24–52, 151–170, 180–262, 273–310 ja 329–334 | Soiton ohjaus, pito, tilanvaihdot, soinnut, idle-stop ja virittimen paluu |
| `Choir Master/ContentView.swift` | pianoControls, volume, asetusten soitto- ja viritysvalinnat | Kaikkien käyttäjän soitto-ohjainten kytkentä |
| `Choir Master/SavedChord.swift`, `NoteNaming.swift` | koko tiedostot | Soitettavien sävelten validointi ja kosketinmerkintöjen riippuvuus |
| `Temperament.swift`, `AudioSessionCoordinator.swift` | aiemmin luetut rajapinnat ja nykyinen käyttötapa | Taajuustaulukko ja sessionin omistus; matemaattinen temperamenttiauditointi kuuluu vaiheeseen 4 ja laite-elinkaari vaiheeseen 6 |
| 25 WAV-tiedostoa, `metadata.json`, SF2 | headerit, PCM, SF2-preset header | WAV/metadata-vastaavuus, monosekoitus ja soitettavan presetin tunnistus |
| `Tests/ReferenceToneChecks`, `Tests/ReferencePitchSweep`, `Tests/AudioRenderChecks` ja nykyiset XCTestit | testilähteet ja rajat | Vanhan testin oletusäänen tarkistus sekä lisätestien tarpeet |

Koko `ConductorModel` ja `PianoKeyboard` luettiin; taulukko yksilöi tämän vaiheen
varsinaiset vastuualueet. Fyysisen kosketusjärjestelmän toimintaa ei ole luettu
UIKitin toteutuksesta eikä monikosketusta ole mitattu laitteella.

## Todellinen toiminta ja invariantit

Piano käyttää 97 paikkaa: C2–C6 puolisävelaskelin eli myös 48 neljäsosasäveltä.
Näytteet ovat MIDI 55–79. Lähin kokonaislukusävel valitaan `rounded()`-operaatiolla,
alueen ulkopuolella reunanäytteestä. A4:n ja temperamentin taajuus jaetaan
metadatan mitatulla näytefundamentaalilla. Tämä on toistonopeuden korjaus,
ei takuu siitä, että jokainen akustisen pianon spektrikomponentti olisi kohdallaan.

`ChoirAudio` lukee kaikki näytteet pääsäikeessä ja muodostaa stereoista monon.
25 tiedostossa oli yhteensä 1 643 856 kehystä: Float32-monotaulukoiden hyötydataa
6 575 424 tavua, ilman Swift-taulukoiden ja dekoodausbufferien lisätilaa.
Näytteet olivat 44,1 kHz / 16 bit / stereo ja vastasivat metadataa. Absoluuttinen
huippu vaihteli välillä 0,233246–0,525391. Yhden näytteen koko tiedoston stereo-
korrelaatio oli noin −0,493, joten monoksi summaaminen voi muuttaa sointiväriä ja
osien voimakkuutta. Monosoitto on nykyinen tarkoituksellinen toteutus, ei tässä
vaatimusten vastaiseksi osoitettu vika.

Attack on gainin lisäys `1/220` per näyte (noin 5 ms), release kerroin 0,997 per
näyte. Ääni jätetään aktiivisesta listasta, kun gain putoaa alle 0,00001:n.
Uusi onset resetoi saman paikan position ja gainin. Vanhaa ääntä ei ristihäivytetä
uutena erillisenä äänenä; retrigger ei lisää polyfoniaa. Sävelen lopetus on pehmeä,
mutta kaikkia gain- tai retrigger-muutoksia ei siloteta (katso AUD-002).

Loopin lopussa luetaan lineaarisesti `data[i]` ja `data[i+1]`. Metadata vaatii
`loopEnd <= frames−2`, positiivisen ja loppua lyhyemmän loopin sekä crossfaden,
jonka siirretty luku ei mene ennen nollaa. `p >= end` kiedotaan modulo-operaatiolla,
mikä kestää myös yhden loopin ylittävän positiivisen toistoaskeleen. Metadatan
ja muuttumattomien taulukoiden yhdistelmä pitää indeksit testatuilla syötteillä
rajoissa. `AudioRenderer` itsessään ei validoi mielivaltaisia sisäisiä `notes`- tai
`pitches`-taulukoita: käyttöliittymän ja sointuvalidoinnin esiehdot ovat osa sopimusta.
Ulostulo on monona molempiin kanaviin ja `tanh`-rajoitettu. Rajoitus estää ylivuodon,
mutta ei todista säröttömyyttä tai miellyttävää äänenlaatua.

Pito hallitaan mallin `pressed`- ja `sounding`-joukoilla. Pidon poisto vapauttaa
vain painamattomat äänet. Peruutus vapauttaa sävelen myös pidossa. Kosketinnäkymä
pitää kosketuskohtaisen kartan; samaa säveltä pitävistä sormista viimeinen vapauttaa
äänen. Vähintään 24 pisteen selvä yhden sormen vaakaliike peruuttaa soittokosketuksen
ja vierittää. Sointukosketusta ei muuteta swipeksi jäljelle jääneen sormen perusteella.
Geometrian muutos ja ikkunasta poisto kutsuvat peruutusta.

Tarkan vertailuäänen kolme osaa ovat samaan vaiheeseen sidottuja: 0,8 perustaajuutta,
0,14 toista ja 0,06 kolmatta yläsäveltä. Volume muuttuu 18 ms:n näyterampilla,
gain nousee noin 5 ms ja laskee noin 18 ms. Suora oskillaattorin stop toimi.
SoundFont käyttää oikeasti ohjelmaa 19 pankissa 0; SF2:n preset-headerissa sen nimi
on **Pipe Organ**. Ohjelman 19 muissa pankeissa oli myös variantteja. Käytettävän
pankin nimi tarkistettiin tiedostosta, eikä vain GM-kommentista.

## Ajot ja tulokset

Ympäristö: Xcode 27.2, Swift 6.4.2, Apple Silicon macOS. iOS-mallitestit:
iPhone 16 Pro App Store / iOS 18.5 -simulaattori, ei fyysistä puhelinta.
Offline-engineajoille annettiin pääsy järjestelmän audiokomponentteihin;
mikrofonia tai kaiutinta ei käytetty. Mallitestin piano-/click-volume oli nolla.

| Testi | Toteutus | Tulos |
| --- | --- | --- |
| WAV ja metadata | 25 headeria, frame count, kanavat, sample rate, PCM-arvot | PASS |
| Pianon koko alue ja A4-rajat | 97 × A4 300/442/500 Hz = 291 yhdistelmää, 3 s per ääni, release ja hiljaisuus | PASS; äärellinen, rajattu, kanavat samat, jokainen ääni soi ja sammui |
| Puskurikoko | Sama C2/A4↑/C6-soitto 4096:n vs vaihtelevien 1/17/512/389:n puskureilla | PASS; bitilleen sama PCM |
| Ylisuuri loop-askel | Sisäisesti asetettu 50000:n positiivinen askel 4096 näytteen ajossa | PASS; modulo pysyi rajoissa; tämä on rajatestisyöte, ei UI:n normaali askel |
| Attack ja volume-askel | Vakionäyte, 220 kehyksen nousu, volume 1→0 | Attack täyttyi; volume katkeaa suoraan (AUD-002) |
| Suora tarkka oskillaattori | 291 yhdistelmää, 2 s per ääni; nollanylityksistä mitattu f0; stop | PASS; suurin poikkeama 0,00003145 senttiä, stereo/rajat/hiljaisuus läpäisivät. Ei DAC:n tarkkuusmittaus. |
| Nykyinen ReferenceToneChecks | 11 × 6 s, A4-esivalinnat, oma 443,5, neljäsosasävel ja E4-järjestelmät; tavallinen stop | PASS. Testi käyttää `configure`-oletuksena **precise**-ääntä, vaikka alun kommentti puhuu SoundFontista. |
| Erillinen SoundFont-ajo | Kopio samasta harnessista, mutta eksplisiittisesti `sound: .soundFont`; 11 × 6 s | PASS; ääni jatkui, pysyi rajoissa ja tavallinen stop sammutti |
| Jonotettu Play→Stop | Molemmat äänet, soft/immediate stop ilman awaitia Playn välissä, myöhempi configure | Luonnehdinta toisti AUD-001:n; immediate-haara ei sammuta turvallisesti |
| Malli ja koskettimisto | 97 sävelen down/up, invalid down, pito, sävelkohtainen toggle, cancel, referenssitila; 6 näkyvän alueen/jakotavan geometriaa ja aktivoinnit | 2 tilapäistä XCTest-metodia, 0 epäonnistumista. Ei todellisia UITouch-sormitapahtumia tai VoiceOver-käyttäjäkoetta. |

Suoran oskillaattorin testi kattaa tasavireisen taajuuden tuottamisen. Seitsemän
viritysjärjestelmän kaavojen riippumaton oikeellisuus ei tule todistetuksi sillä,
että niiden taajuuksia voidaan soittaa; se on seuraava vaihe.

### Pianon säveltason luonnehdinta

97 säveltä A4=442 Hz:n tasolla mitattiin tuotetusta PCM:stä Hann-ikkunalla,
zero-pad FFT:llä ja logaritmisella huippuinterpoloinnilla. Hakualue oli ±4 %
tavoitteesta. Mittari etsii vahvimman lähellä olevan huipun, ei erota pianon kaikkia
kieliä tai inharmonisia komponentteja. Mittaukselle ei asetettu jälkikäteen
läpäisyrajaa eikä sitä nimetä tarkaksi havaintopsykologiseksi perustaajuudeksi.

Havaitut 1–3 s -ikkunan poikkeamat olivat −10,3305…+5,1549 senttiä. Esimerkiksi
MIDI 58:n tavoite 234,141344 Hz tuotti vahvan huipun 232,748940 Hz (−10,3261 senttiä).
Saman lähdenäytteen MIDI 57,5:llä poikkeama oli −10,3305 senttiä. Ensimmäisen ja
viimeisen mittausikkunan ero oli enimmillään 12,4336 senttiä (MIDI 37); huipun
vaihtuminen komponentista toiseen voi vaikuttaa tähän lukuun.

Tämä varmistaa, ettei näytepianon sävelpuhtautta pidä samastaa suoran tarkan äänen
mitattuun tarkkuuteen. Se ei yksin osoita temperamentin laskukaavan vikaa eikä anna
yleistä senttirajaa akustisen pianon havaitulle vireelle. Tarkka viritysääni on
käyttöliittymässä erillinen valinta. Näytteiden pidettyjen silmukoiden vire,
sointiväri ja huojunta tarvitsevat kuuntelun sekä tarkemman komponenttianalyysin,
jos pianolle asetetaan tiukempi virityslupaus. Ei kiinteää korjausta auditissa.

## Löydökset

### AUD-001 — Peruttu jonotettu vertailuääni käynnistyy Stopin jälkeen

Vakavuus MEDIUM. **Varmistettu tuotannon ReferenceTone-luokalla ja oikealla
offline-enginellä**, ei käyttöliittymän tai fyysisen iPhonen tapahtuma-ajolla.
Lähde: `ReferenceTone.swift` 63–94 ja 100–123; `AudioEngine.silence` 53–58.

Toisto samalla MainActor-vuorolla:

```
tone.configure(tuning: 442, volume: 0.7, sound: .precise)
tone.play(69)
tone.stop(immediately: true)
// Anna jonotetun tehtävän käynnistyä, renderöi sen jälkeen.
```

Stop peruu Taskin ja tappaa senhetkiset äänet. Vielä käynnistymätön peruttu
Play-Task ei tarkista peruutusta alussa. Kun `currentNote` on nil, se ohittaa
vanhan äänen fade-haaran, käynnistää oskillaattorin/samplerin ja vasta sitten
havaitsee peruutuksen fadessa. Tarkka fade tekee `applyVolume`-kutsun ennen
peruutuksen havaitsevaa awaitia, ja epäonnistunut fade palaa tappamatta ääntä.

| Tila | RMS stopin jälkeisen toisen offline-sekunnin aikana | RMS myöhemmän configure-kutsun jälkeen |
| --- | --- | --- |
| precise, immediate | 0,0141083 — ääni jatkuu | 0,0141105 |
| soundFont, immediate | 0 — aluksi piilossa | 0,0109874 — pysäytetty ääni tulee kuuluviin |
| precise, soft | 0 | 0 |
| soundFont, soft | 0 | 0 |

SoundFont-haara jättää samplerin sävelen/currentNote-tilan eloon, vaikka mixer
pysyy nollassa. Myöhempi `configure` nostaa sen takaisin kuuluviin. Sovelluksen
`silence` pausettaa enginen, mikä voi peittää äänen siihen asti, että engine
käynnistetään uudelleen. Koko sovelluksen tämän tapahtumajärjestyksen UI-toistoa
ja oikean pausen jälkeistä restartia ei ajettu; piilossa jäävä ääni ja sen
asetuspäivityksellä palautuminen on silti toistettu yllä.

Nykyisen testin `play(60); play(72); stop(immediately:true)` läpäisy ei kumoa
löydöstä: kaksi eri peruttua Play-tehtävää kulkee eri haarojen kautta ja voi
peittää ensimmäisen käynnistämän äänen. Yhden Playn peruutus tarvitaan erikseen.

Jatkotoimi: tarkista peruutus/sukupolvi ennen yhtäkään ääntä käynnistävää sivuvaikutusta
ja varmista, ettei vanha tehtävä siivoa tai julkaise uudemman tilaa. Lisää yhden
Playn immediate stop sekä myöhempi configure/restart regressioiksi. Ei toteutettu.

### AUD-002 — Pianon volume päivitetään ilman näyteramppia

Vakavuus LOW / IMPROVEMENT. Signaalin epäjatkuvuus **varmistettu**, mahdollinen
kuultava napsahdus ei ole kuuntelulla todistettu.
Lähde: `AudioRenderer.swift` 47–50, 83 ja 150–156; `ConductorModel.swift` 29.

Konfigurointi vaihtaa pianoVolumen audiopuskurin rajalla suoraan. Vakionäytteen
vakaassa pidossa volume 1→0 vaihtoi peräkkäiset PCM-arvot 0,0299910 → 0.
Attack-/release-vaippa ei silota tätä, koska sävel pysyy pidettynä. Suuren
volume-muutoksen nopea käyttö voi siis tuottaa ylimääräistä laajakaistaista
energiaa. Tarkalla oskillaattorilla on erikseen 18 ms:n volume-rampitus.

Jatkotoimi: jos napsahdukset kuunnellaan toistettaviksi, harkitse pianon gainin
lyhyttä audiokellossa kulkevaa ramppia. Tämä ei ole ulostulon ylivuoto eikä
varmistettu yleinen äänenlaadun hylkäys. Ei tuotantokoodimuutosta auditissa.

## Riskit ja todentamatta jääneet osat

- Fyysinen monikosketus, UITouch-cancel/swipe-matriisi, todellinen VoiceOver,
  ruudun kääntö sormien ollessa koskettimilla ja UI:n visuaalinen tarkastus.
  Geometria ja ohjelmallinen aktivointi eivät korvaa näitä.
- iPhonen kuulokekuuntelu: bassoalueen transponoinnin väri, loop-saumat,
  sustain-huojunta, reartikuloinnin ja volume-askelluksen napsahdukset.
- Fyysisen laitteen DAC-/Bluetooth-taajuus, viive, CPU/energia, muistihuippu ja
  realtime-underrunit. Esilataus/SoundFont alustetaan synkronisesti pääsäikeessä;
  mahdollinen ensimmäisen ruudun viive on riski, ei tässä mitattu laitevirhe.
- Näytteiden alaspäin transponointi C2–F♯3-alueelle ja lineaarinen interpolointi
  muuttavat sointiväriä. Ylöspäin siirtävällä resamplerilla ei ole erillistä
  alipäästöä; mahdollisen laskostumisen havaittavaa tasoa ei mitattu.
- SoundFontin koko alueen sävelpuhtaus ja sample-zone/loop-rakenne. Preset-header
  ja 11 normaalin soiton tapausta tarkistettiin, ei jokaisen SF2-generaattorin
  riippumatonta parseria tai kaikkien pankkien auditointia.
- 4505 tapauksen ReferencePitchSweepiä tai sen 391 tapauksen 48 kHz -matriisia
  ei ajettu tässä vaiheessa; vanhoja CSV:itä ei käytetty tuoreena ajotodisteena.
- Oikea puhelu, reittivaihto, mikrofonin ja vertailuäänen samanaikaisuus sekä
  kahden enginen käyttäytyminen kuuluvat elinkaaren/laitteen tarkastukseen.

## Seuraava vaihe

**4 — Viritysjärjestelmät**, `05-TUNING-SYSTEMS.md`: kaikkien seitsemän järjestelmän
riippumattomat suhde-/senttitaulut, A4-ankkuri, transponoidut pohjasävelet,
24-jako, enharmoniat ja virittimen lähimmän tavoitteen valinta. Äänen tuottamisen
291 tapauksen testejä ei tarvitse toistaa matemaattisen taulukon sijasta.
