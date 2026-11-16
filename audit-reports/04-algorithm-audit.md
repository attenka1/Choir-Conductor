# 04 — Algoritmien auditointi

## Temperointi — `Temperament.swift`

Tarkoitus: A4 pysyy annetussa hertsiluvussa, muut sävelet lasketaan järjestelmän mukaan, ja pohjasävel siirtää kaaviota.

Tarkistus: `frequency` = `a4 * 2^((note-69)/12 + correction/1200)`. Korjaus vähentää A:n oman offsetin, joten MIDI 69 on tasan A4. Avoin kvinttiketju −3…8, Werckmeister III, Kirnberger III ja Vallotti seuraavat dokumentoituja kavennettuja kvinttejä. Luonnonvire käyttää kiinteitä 5-limit-suhteita, ei sointukohtaista viritystä.

Ajettu testi: `swiftc` + `Tests/TemperamentChecks/main.swift`. Tulos PASS: A4-ankkuri, oktaavit, puhtaat kvintit ja terssit, 24-EDO. XCTest `testTunerTargetsAllTemperamentsAndQuarterTones` lisäksi: jokainen sävel 36...84, jokainen järjestelmä ja pohjasävel, syöte on järjestelmän oma taajuus, tulos 0 senttiä tarkkuudella 0,000001.

Ei löytynyt vastaesimerkkiä, jossa kelvollinen sävel antaisi väärän oktaavin tai irtoaisi A4-ankkurista. `offset`-funktion `first!` on turvallinen, koska 12 peräkkäistä kvinttiä kattaa kaikki jäännösluokat modulo 12. Tätä ei rikottu testissä.

Raja: 24-jako pakotetaan tasavireiseksi mallissa (`divisions`-didSet). `TunerPitch.target` käyttää 0,5-askelta vain, jos jako on 24 ja järjestelmä on tasavireinen. Yhdistelmää 24 + historiallinen järjestelmä ei voi tallentaa kelvolliseen sointuun (`SavedChord.isValid`).

## Sointujen ja näytteiden nimet — `NoteNaming.swift`

Tasavire käyttää suomalaista tai kansainvälistä 12 nimeä. Avoin ketju ja luonnonvire kirjoitetaan uudelleen kvintti- tai asteikkosäännöllä. Kosketin ja sointulista kutsuvat samaa funktiota (`ConductorModel.keyNames`, `PianoKeyboard.configure`). Asetusten susikvinttiteksti käyttää samoja `keyNames`-arvoja (`ContentView` rivi 201). XCTest `testHistoricalPitchSpellingFollowsFifthChain` läpäisi (G♯, E♭, transponoitu A♭, luonnonvireen A♭ ja D♭).

## Metronomi ja piano — `AudioRenderer.swift`

Iskun ehto `remaining <= 0` lisää koko jakson ja vähentää sitten yhden. Yli- tai alijäämä säilyy seuraavaan jaksoon. Erillinen testi tarkisti tasatempoilla 1–16 iskua ilman näytepoikkeamaa, tempon vaihdon, 97 ääntä, silmukan, rajatun ulostulon ja vapautuksen. Tulos PASS, huippu 0,1586.

Aktiiviset äänet kerätään puskurin alussa. Puskurin aikana alkanut sävel kuuluu vasta seuraavassa puskurissa. Ohjaus on suunniteltu puskurin rajalle. `sourceIndices` on esilaskettu välille 0...24. Metadatan tarkistus estää nollapituisen silmukan (`PianoSampleMetadata.load`).

`startNotes` ei tarkista indeksiä. Kutsujat rajaavat sävelen. Kelvoton sävel kaataisi. Sitä ei voi syöttää käyttöliittymästä nykyisillä tarkistuksilla. Ei erillistä havaintoa.

6/8-muunnos ei ole rendererin virhe. Se on `setCompound`-funktion kokonaislukukaava. Katso F-001. Kaava toistettiin Pythonissa; sovellusprosessia ei kutsuttu tälle vastaesimerkille. Olemassa oleva XCTest osoittaa vain parin 60 ja 180.

## Tarkka oskillaattori — `ReferenceOscillator.swift`

Postilaatikko, 18 ms voimakkuusramppi, sammutuksessa myös gain laskee 18 ms (`gain - 1/(rate*0.018)` rivi 59). Vaihe nollataan vain uudessa onsetissa. Taajuusmuutos ei nollaa vaihetta. Äänen kuuntelua ei tehty. Erillistä spektrimittausta ei ajettu tässä auditoinnissa; aiempi projektidokumentaatio väittää alle 0,01 sentin offline-poikkeamaa. Tätä väitettä ei toistettu nyt.

## YIN ja alipäästö — `PitchDetector.swift`

`detect`: varianssikynnys, CMNDF-kynnys 0,12, parabolinen huippu, hyväksytty kaista 65...1500 Hz. Hiljaisuus, tasajännite, kohina ja leikkautuminen hylätään.

`TunerInputProcessor`: Blackman-Harris-ikkunoitu sinc, katkaisu `min(0.45, 0.4/decimation)`, kertoimet normalisoidaan. Symmetrinen FIR, joten kerroinjärjestys ei muuta vastetta. Ryhmäviive ei muuta sävelkorkeutta.

Ajettu `swiftc`-testi: PASS kestäville äänille, yläsävelille, hiljaisuudelle, tasajännitteelle, kohinalle, leikkautumiselle sekä suodatetulle virralle 44,1 / 48 / 96 kHz. Temperointikohteet PASS.

`TunerTap`: audiokutsu vain kopioi renkaaseen `try`-lukolla. Työntekijä suodattaa 20 ms välein. Ylikuorma hylkää vanhan puskurin ja nollaa prosessorin. Rajaton jono ei kasva. Tätä ylikuormapolkua ei rasitustestattu.

## Tallenneanalyysi — `RecordingPitchAnalysis.swift`

Tarkoitus: spektripiikkien vaiheerotus, taitto ±50 senttiin A4-tasavireestä, luotettavuus ympyräkeskiarvona, jatkuvuus enintään 12 senttiä askelta kohti, 15 s ikkuna. Jos edellisestä luotettavasta pisteestä on yli yksi lohko, `previous` nollataan (rivit 242–245), joten tauko ei vedä uutta jaksoa vanhaan tasoon.

Rajoitus, ei piilovirhe: moniääninen kuoro ja kaiuttimesta vuotanut piano sulautuvat yhdeksi luvuksi. Käyttöliittymä kertoo tämän. Menetelmä ei mittaa luonnonvireisen soinnun puhtautta. XCTest läpäisi synteettisellä aineistolla ja A4-välimuistin mitätöinnillä. Kuoron oikeaa tarkkuutta ei validoitu.

`RecordingAnalysisStore` lukee tiedoston kahdesti (sormenjälki alussa ja lopussa) ja dekoodaa PCM:n taustatehtävässä. Välimuisti hylätään, jos hash, A4 tai versio ei täsmää.

## Mitä ei yritetty rikkoa ajamalla

- Rendererin silmukka näytteellä, jonka metadata on tahallaan rikki. Lataaja hylkää sen ennen soittoa.
- YIN alle 65 Hz tai yli 1500 Hz. Koodi palauttaa nil. Erillinen testi kattaa rajat vain osin (65,41 Hz oli mukana).
- Analyysin käyttäytyminen oikealla kuorolla.
