# 03 — Metronomi

Päiväys: 2026-11-17. Vaihe 2. Tila: valmis tämän raportin rajauksella.

Auditoinnin aikana ei muutettu tuotantokoodia, sovelluksen XCTest-tiedostoa,
projektiasetuksia tai alkuperäistä `choir-conductor`-raporttipohjaa. Koodi sisältää
ennen tätä vaihetta tehdyt kuusi rajattua korjausta. HEAD ei yksin kuvaa testattua
koodia: työpuussa on committoimattomia muutoksia. Tiedostokohtaiset SHA-256:t ovat
[evidenssin lähdetilassa](evidence/metronome-2026-11-17/source-snapshot.json).

## Kattavuus ja lähteet

Rivi rivilta tarkastettu metronomipolku:

| Lähde (`Untitled Project/`-juuresta) | Rivit / symboli | Tarkastettu toiminta |
| --- | --- | --- |
| `Choir Master/AudioRenderer.swift` | 9–56, 71–125, 156–161 | Komentopostilaatikko, aloitus, reset, clear, näytekello, klikki, ulostulo ja iskun julkaisu |
| `Choir Master/ConductorModel.swift` | 19, 24–27, 59–69, 77–84, 142–190, 264–288, 312–334 | Asetusten luku/tallennus, BPM, 6/8, käynnistys/pysäytys, UI-pollaus, hereilläpito ja elinkaareen liittyvät rajapinnat |
| `Choir Master/ContentView.swift` | 65, 72–131, 159–169, 253–275 | Käyttöliittymän kaikki metronomikomennot, nuolten toisto, tempoeditori, 6/8, iskun näyttö |
| `Choir Master/RecordingView.swift` | 104–129 | Tahtilajin osoittajan ja nimittäjän valinta |
| `Choir Master/AudioEngine.swift` | 12–59 | Näytteiden alustus, 44,1 kHz lähdenode, engine start/pause ja session-claim |
| `Choir Master/AudioSessionCoordinator.swift` | 36–97 | Käynnistyksen, keskeytyksen ja kategorian vaikutus metronomin käytettävyyteen; koko sessionin laiteauditointi ei kuulu tähän vaiheeseen |
| `Choir Master/PianoSampleMetadata.swift` | 1–26 | Renderöintitestin näytteiden validoinnin riippuvuus |
| `Choir MasterTests/ReliabilityTests.swift` | `testCompound…`, `testMailbox…`, `testAudioRendering…` | Olemassa olevan testikattavuuden ja testien rajoitusten arvio |
| `Tests/AudioRenderChecks/main.swift` | koko tiedosto | Uudelleen ajettu olemassa oleva offline-tarkistus |
| Xcode-projekti ja jaettu scheme | asetukset ja TestAction | Choir Master, iOS 17.0, oikea testikohde; ei fyysistä puhelinta |

Täydellinen mallin ja sessionin lähde sekä `ReferenceTone.swift` ja `ReferenceOscillator.swift` luettiin riippuvuuksien ymmärtämiseksi. Tempoa päivittävä `configure` päivittää myös vertailuäänen asetuksia, mutta nämä eivät ajoita metronomin iskuja. Engine-kokeessa käytettiin vain metronomin lähdenoden ja mainMixerin minimigraafia, ei koko sovelluksen graafia.
Pianon silmukoiden ja viritysten oikeellisuutta ei tällä perusteella merkitä
vaiheiden 3–4 osalta tarkastetuksi. Viitteet koskevat yllä tallennettua lähdetilaa.

## Todellinen toimintatapa

1. `setTempo` rajaa BPM:n välille 30–240. Valitsimet sallivat osoittajan 1–16 ja
   nimittäjät 1, 2, 4, 8 ja 16. Käynnistyksessä myös tallennetut arvot validoidaan.
2. BPM tarkoittaa yhtä näytettyä iskua minuutissa. Nimittäjä vaihtaa iskuarvon
   merkitystä ja tekstiä; se ei kerro renderöinnin periodia neljäsosiksi.
   Tavallisissa tahtilajeissa iskuja on osoittajan verran. Vain 6/8:n pistetahti
   käyttää kahta pisteellistä neljäsosaa; toisessa 6/8-tilassa on kuusi iskua.
3. `AudioRenderer` käyttää 44 100 Hz:n lähdenäytekelloa. Iskuväli on
   `44100 × 60 / BPM`. `remaining` pienenee vain renderöidyistä näytteistä.
   Uusi periodi lisätään jäljelle jääneeseen murtolukuun, joten jakovälin
   näytepyöristystä ei summata joka iskulla samaan suuntaan.
4. Klikin alku ajoittuu ensimmäiseen näytteeseen, jossa laskuri on enintään nolla.
   Ensimmäinen PCM-arvo on attackin ja sinivaiheen vuoksi nolla; suoran PCM-testin
   havaitsemasta ensimmäisestä ei-nollanäytteestä vähennettiin yksi näyte.
   Näytteiden tarkastelu ei käyttänyt `remaining`- tai `beat`-arvoja ajoitusoraakkelina.
5. Tahdin ensimmäinen isku on 1600 Hz, muut 1000 Hz. Korostus on korkeusero,
   ei erillinen suurempi gain. Klikki kestää enintään 1600 lähdenäytettä
   (noin 36,28 ms), nousu kestää 30 näytettä ja vaippa vaimenee eksponentiaalisesti.
   Lyhin sallittu iskuväli on 11025 näytettä, joten klikkien vaipat eivät limity.
6. Tempo muuttuu postilaatikon kulutuksessa seuraavan audiopuskurin alussa,
   mutta jo alkanutta iskuväliä ei skaalata. Seuraava isku tulee vanhan periodin
   mukaan; siitä eteenpäin käytetään uutta tempoa. Tämä vastaa README:n kuvausta.
7. Tahtilajin tai 6/8-tulkinnan muutos resetoi tahdin. Seuraava audiokäsittely
   aloittaa uuden ykkösiskun heti, eikä odota vanhan tahdin loppua. Tahdin vaihto
   voi siis katkaista iskuvälin. Tämä on vahvistettu koodikäyttäytyminen, ei
   tässä vaatimusten vastaiseksi osoitettu virhe.
8. Audio käyttää postilaatikossa `lock.try()`-yritystä. Jos julkaisu on kesken,
   vanha tila jatkaa soimista; renderöinti ei jää tähän lukkoon odottamaan.
   Komennon kulutuksen viiveelle ei silti ole ehdotonta ylärajaa jatkuvassa
   lukituskilpailussa. Tuloksia ei pidä tulkita reaaliaikaisen deadlinen todistukseksi.
9. `Timer.publish(1/30)` lukee vain viimeksi julkaistun iskun UI:lle. Se ei ajoita
   ääntä. UI voi näkyä ääneen nähden viiveellä. Käynnistys ja pysäytys resetoivat
   klikin; tausta ja oikea keskeytys pysäyttävät harjoitteluäänen.
10. Lähdenode on kytketty engineen nimenomaisesti 44,1 kHz:n muodossa. Muu
    ulostulotaajuus muunnetaan enginessä, joten renderöinnin 44100-vakio ei yksin
    ole 48 kHz:n tempoa vääristävä virhe.

## Testit ja tulokset

Ympäristö: Apple Silicon macOS, Xcode 27.2 (27B52), Swift 6.4.2.
Mallin lisätestit ajettiin iPhone 16 Pro App Store / iOS 18.5 -simulaattorissa,
UDID `66ADE923-337F-4741-BC44-C77EB5E997B1`. Fyysistä puhelinta ei käytetty.
Offline-testit eivät tarvitse mikrofonia tai kaiutinta. Offline-audion kesto
alla ei tarkoita vastaavaa seinäkellossa kulunutta testiaikaa.

| Testi | Aineisto ja riippumaton tarkistus | Tulos |
| --- | --- | --- |
| Kaikki tempot | 211 kokonaislukua 30–240, 8 PCM:stä havaittua alkua per tempo, vaihtelevat 1/127/512/4096/33 näytteen puskurit | PASS; jokainen alku enintään 1 lähdenäytteen päässä ideaalista |
| Pitkä näytekello | 7 × 600 s: 40, 60, 120, 180, 240, 137 ja 239 BPM | PASS; yhteensä 70 min offline-audiota, ei kasvavaa iskuvirhettä |
| Puskuririippumattomuus | 40/137/240 BPM, sama 4 s signaali 512:n ja vaihtelevan 1/17/4096/89/256:n puskureilla | PASS; PCM bitilleen sama |
| Tahdit ja korostukset | Kaikki 1–16 iskua, täysi kierto ja seuraava tahti; klikin taajuus PCM:n nollanylityksistä | PASS; 1600/1000 Hz oikeissa kohdissa, mittaus alle 0,5 Hz:n päässä |
| Ohjauspostilaatikko | 120→240 BPM muutos lähdekehikolla 1000 | PASS; klikkien alut `[0, 22050, 33075, 44100]` |
| Pysäytys/clear/uusi aloitus/mute | PCM:n nolluus ja uusi ensimmäinen isku; mykistetty kello etenee | PASS |
| Lukituskilpailu | 1 000 000 saman tilan konfigurointia ja iskun lukua rinnakkain; 60 s / 137 BPM | PASS; PCM bitilleen sama kuin ilman rinnakkaista julkaisua |
| Maksimiäänimäärä | 97 pidettyä neljäsosasävelääntä, pianon todelliset WAV:t, metronomi 30 ja 240 BPM, 12 s kumpikin | PASS; 6/48 klikkiä oikeilla ajoilla; PCM oli äärellinen ja alle ykkösen. Klikki eristettiin kahden saman pianorenderöinnin erotuksena `atanh`-rajoittimen käänteismuunnoksen jälkeen. Ei reaaliaikaisen suorituskyvyn mittaus. |
| Todellinen AVAudioEngine, minimigraafi | 137 BPM / 60 s, 44,1 kHz lähde → 44,1 ja 48 kHz offline-ulostulo | PASS; kummassakin 137 havaittua klikkiä |
| Mallin lisä-XCTestit | 422 edestakaista 6/8-muunnosta, 160 tahtiasetuksen/iskutulkinnan yhdistelmää, BPM-rajat, uusi temposyöttö, kaksi virheen luonnehdintatestiä | 4 testimetodia, 0 epäonnistumista; luonnehdintatestin PASS tarkoittaa jäljempänä olevan ongelman toistumista |
| Olemassa oleva AudioRenderChecks | Tuotannon nykyinen renderer ja pakatut näytteet | PASS; 1–16, aksentit, tempo, 97 ääntä, silmukat, ulostulorajat ja release |

Kymmenen minuutin ajot:

| BPM | Havaitut iskut | Suurin absoluuttinen ajoituspoikkeama ideaalista, lähdenäytteitä |
| --- | --- | --- |
| 40 | 400 | 0 |
| 60 | 600 | 0 |
| 120 | 1200 | 0 |
| 180 | 1800 | 0 |
| 240 | 2400 | 0 |
| 137 | 1370 | 0,992701 |
| 239 | 2390 | 0,995816 |

Yksi lähdenäyte on noin 22,68 µs. Kokonaisluvusta poikkeavan periodin vuorottelu
kahden kokonaisen näytevälin välillä on näytekvantisointia, ei mitattua iOS-ajastusjitteriä.

Engine-testin ensimmäinen havaittu ei-nollanäyte oli 44,1 kHz:llä 1 ja 48 kHz:llä
10. Suurin ensimmäiseen havaintoon suhteutettu vaihe-ero oli 0,992701 ja
2,649635 ulostulonäytettä. Jälkimmäinen on noin 55,2 µs ja sisältää muuntimen
sekä onset-kynnyksen vaikutuksen. Nämä eivät ole kaiuttimen tai Bluetoothin
viivemittauksia. Ensimmäinen rajattu engine-ajo kaatui audiokomponentin
luontiin (`comp != nullptr`); sama binaari läpäisi järjestelmän komponentteihin
pääsevällä uusinta-ajolla. Tätä ei luokitella sovellusviaksi.

## Varmistetut löydökset

### MET-001 — Rajanuolen tyhjä painallus hävittää 6/8-palautustempon

Vakavuus: MEDIUM. Varmuus: toistettu nykyisellä `ConductorModel`-koodilla.

Lähteet: `ConductorModel.swift` 19, 24, 173 ja 312–327;
`ContentView.swift` 80 ja 84.

Toisto ja luonnehdintatestin havainto:

- 6/8, pistetahti 96 → kahdeksasosat 240 → plusnuoli → yhä 240 → paluu → **80**.
- 6/8, kahdeksasosat 80 → pistetahti 30 → miinusnuoli → yhä 30 → paluu → **90**.

`setTempo` rajaa nuolen 241:n 240:ksi ja 29:n 30:ksi. Swiftin `didSet` suoritetaan
myös saman arvon asetuksessa; se tyhjentää `compoundReturn`-muistin. Käyttäjä ei
näe muutosta rajalla, mutta paluu ei enää palauta alkuperäistä tempoa. Suora
edestakainen vaihto ilman nuolta läpäisee kaikilla 211 lähtötempolla molempiin
suuntiin; alkuperäinen rajattu korjaus ei siis ole kokonaan epäonnistunut.

Korjausehdotus jatkoa varten: erota oikea temposyöttö ja rajalla tapahtuva
nuolen no-op. Säilytä palautusmuisti, kun nuoli ei muuta tempoa; päätä erikseen,
pitäisikö saman luvun tarkoituksellisen numerosyötön nollata muisti. Lisää yllä
olevat tapaukset tuotantotestien regressioiksi. Tässä auditoinnissa ei korjattu.

### MET-002 — Palautustempo ei säily tallennetun tilan uudelleenluvussa

Vakavuus: LOW / tilan säilymisen raja. Varmuus: toistettu alustamalla uusi
malli samasta `UserDefaults`-tilasta; oikeaa prosessia ei tapettu.

Lähteet: `ConductorModel.swift` 19, 77–84, 142–149 ja 312–327.

96 pistetahti → 240 kahdeksasosaa → `flushSettings` → uusi `ConductorModel`
lukee 240/false → paluu pistetahtiin antaa **80**. Vain nykyinen tempo ja
iskutulkinta tallennetaan. Alkuperäinen 96 jää yksityiseen muistissa elävään tupleen.

Tämä ei riko saman mallin edestakaisen vaihdon testejä, mutta rajaa korjauksen
lupauksen nykyiseen käyttöjaksoon. Tuotemäärittely ei erikseen lupaa muunnoksen
lähtötempon säilymistä uudelleenkäynnistyksessä; siksi löydös on LOW, ei uusi
näytekellon virhe. Päätettävä jatkossa: säilytetäänkö lähtötempo tai molempien
iskutapojen käyttäjätempot myös levyllä vai dokumentoidaanko käyttöjaksoraja.

## Vahvistetut rajoitukset, joita ei kirjata uusiksi vioiksi

- 6/8:n rajallinen muunnos ei aina säilytä tahdin kestoa: 96 pistetahti → 240
  kahdeksasosaa muuttaa tahdin 1,25 sekunnista 1,5 sekuntiin. Kahdeksasosien 80 →
  pistetahdin 30 muuttaa 4,5 sekuntia 4 sekunniksi. BPM-raja ja kuvateksti ovat
  nimenomaisia vaatimuksia; muistettu paluu palauttaa tempon vain kun muistia ei
  ole tyhjennetty. Tämä ei ole vanhan F-001:n sellaisenaan uudelleen kirjaus.
- Tahtilajin vaihto resetoi ykkösiskun. Vaihtoa ei kvantisoida tahdin rajaan.
- Klikki on tiukasti yhteen periodiin ja tahdin alkuun sidottu. Swingiä,
  erillisiä alijakoja tai aksenttien muokkausta ei ole toteutettu eikä niitä
  vaadittu tässä auditoinnissa.
- Rinnakkaistesti julkaisi samaa tilaa. Se ei osoita muuttuvan komennon
  kulutusviiveen enimmäisarvoa eikä kaikkien scheduler-tilanteiden toimivuutta.

## Suorittamatta jääneet testit

- Fyysinen iPhone: kaiutin-/kuulokeulostulon mitattu jitter, pitkäaikainen drift,
  absoluuttinen viive, akunkulutus ja audiodeadlinen ylitykset. Ei käytettävissä
  tässä auditissa eikä fyysisen puhelimen käyttöä pyydetty.
- Todellinen äänitys metronomin ja pianon kanssa, Bluetooth-/USB-reittivaihto,
  puhelu, Siri, Control Center ja kuulokkeen irrotus. Offline-graafi ei toista
  näitä; päävastuu vaiheissa 5–6.
- Käyttöliittymän klikkaus, pitkä nuolipainallus, VoiceOver ja suurennettu teksti.
  Koodipolut luettiin, mutta UI-ajoa ei tehty. Vaihe 7.
- 70 minuutin jatkuva reaaliaikainen toisto: 70 minuuttia oli nopeutettua
  offline-audiota, ei vastaavan pituinen reaaliaikainen laitekoe.
- Kaikkien näytetaajuuksien ja laitteiden matriisi: engine-testissä 44,1 ja
  48 kHz / 137 BPM. 96/192 kHz:n laiteulostuloja ei testattu.
- TestFlight, allekirjoitus, App Store -validointi tai julkaisupäätös.

## Toistettavuus ja seuraava vaihe

Testilähteet, JSON-mittaukset, ajolokit ja tarkat komennot:
[evidence/metronome-2026-11-17/README.md](evidence/metronome-2026-11-17/README.md).
Auditin lisätestit olivat vain tilapäisessä projektikopiossa. Nykyisessä
sovellusrepossa on edelleen 30 XCTest-metodia; neljä auditointimetodia eivät
ole uusi tuotantotestikohteen muutos.

Seuraava vaihe on **3 — Piano ja ääni**, raportti `04-PIANO-AND-AUDIO.md`.
Aloita `AudioRenderer`-äänten elinkaaresta ja loop-interpoloinnista,
`PianoSampleMetadata`-invarianteista, `AudioEngine`-esilatauksesta,
`ReferenceOscillator`/`ReferenceTone`-vaipoista sekä `PianoKeyboard`-kosketuksista.
Metronomin yllä tehtyjä mittauksia ei tarvitse aloittaa uudelleen. Kahden enginen
laitekäyttäytyminen on vielä avoin; niitä ei yhdistetä auditoinnin yhteydessä.
