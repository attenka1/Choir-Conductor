# Choir Master – iPhone

Avaa `Choir Master.xcodeproj`. Projektin, targetin, jaetun schemen ja sovelluksen nimi on **Choir Master**.

## Projektiasetukset

Projektin, targetin, lähdekansion ja schemen nimet muutettiin Choir Masteriksi sekä versionumeroksi 1.0.0. Bundle Identifier on `com.atte.tenkanen.ChoirConductor`, jotta Choir Master käyttää olemassa olevaa App Store Connect -tietuetta. Kehittäjätiimi `XN792Q268W` ja automaattinen allekirjoitus säilyivät. Targetin alkuperäinen `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)` ratkaisi nykyisellä Xcodella iOS 17.0:ksi. Targetiin on nyt asetettu sama 17.0 suoraan; projektitason 27.0-arvo ei ole tämän targetin toteutuva vähimmäisversio. Ominaisuudet käyttävät iOS 17:n rajapintoja.

## Toteutus

- SwiftUI-päänäkymä, metronomi ja vaakasuunnassa vieritettävä pianokoskettimisto. Koskettimet ovat kaksinkertaisen levyisiä: kahden oktaavin alueesta näkyy noin puolet kerrallaan; vaakasuunnassa leveämpi piano. Pienessä näkymässä äänenvoimakkuudet ovat Asetuksissa.
- Tempo 30–240, oletus 80, numerosyöttö ja Valmis, ±1-nuolet ja pitkän painalluksen toisto. Tahtilajin osoittaja 1–16 ja nimittäjä 16, 8, 4, 2 tai 1 valitaan erikseen. BPM tarkoittaa nimittäjän nuottiarvoa. 6/8:ssa voi valita kaksi pisteellistä neljäsosaiskua tai kuusi kahdeksasosaiskua. Molemmat tahtilajin luvut tallennetaan; aiempi 6/8-valinta säilyy päivityksessä. BPM:n nuottiarvo näkyy.
- Iskujen ajoitus ja korostetut klikkaukset syntyvät AVAudioSourceNoden renderöinnissä 44 100 näytteen sekuntikellolla. UI-ajastin lukee vain iskuindikaattorin. Tempon muutos vaikuttaa viimeistään seuraavan iskun jälkeen ajastettavaan väliin.
- UIKit-koskettimisto seuraa jokaista UITouch-kosketusta, myös liu'utusta ja peruutusta. Vähintään 24 pisteen yhden sormen vaakaveto vierittää koskettimistoa ja peruuttaa soittokosketuksen; peruuntunut sävel sammutetaan myös Pidon aikana. C2–C6, keskimmäinen C4; oletusnäkymä C3–C5. Pito, sävelkohtainen sammutus ja Hiljennä kaikki.
- Kaikki näytteet esiladataan monoksi ennen soittoa. Lineaarinen interpolointi, noin 5 ms:n attack ja noin 90 ms:n release. Pito jatkaa näytettä ristihäivytetyllä silmukalla. Tanh-rajoitus estää ulostulon ylityksen.
- A4 415/440/442 Hz ja oma arvo 300–500 Hz (oletus 442), suomalainen H/B tai kansainvälinen B/B♭, omat äänenvoimakkuudet. Asetukset tallentuvat UserDefaultsiin.
- Taustalle siirtyminen, äänikeskeytys ja kuulokkeiden irrotus pysäyttävät äänen. Tilapäinen inactive-tila ei pysäytä harjoitusta. Audioenginen formaattimuutoksen jälkeen aktiivinen soitto palautetaan. Äänikeskeytyksen jälkeen ääni ei käynnisty itsestään. Näyttö pysyy hereillä metronomin, mikrofonitallennuksen ja jatkuvan viritysäänen aikana.
- Äänenkäsittely ja tallenteiden analyysi toimivat paikallisesti. Asetusten Google Mobile Ads / UMP -integraatio käyttää verkkoyhteyttä; mainoksia ja suostumusikkunaa ei ladata harjoittelun aikana.

`ContentView.swift` sisältää näkymät, `ConductorModel.swift` ohjauksen ja asetukset, `PianoKeyboard.swift` kosketukset, `AudioEngine.swift` audioistunnon ja esilatauksen sekä `AudioRenderer.swift` näytekohtaisen soiton ja metronomin.

## Jatkuva viritysääni

Päänäkymän Piano / Viritysääni -valinta vaihtaa äänenannon toimintaa. Asetukset → Viritysääni → Ääni valitsee **Tarkan viritysäänen** (oletus) tai **SoundFont-urut**. Tarkka ääni tuotetaan `ReferenceOscillator.swift`-lähdenodessa 44,1 kHz:n näytekellolla: perustaajuus sekä samaan vaiheeseen sidotut toinen ja kolmas yläsävel. Äänenvoimakkuus säätyy näytekohtaisesti 18 ms:n lineaarisella siirtymällä, ja aloituksessa on 5 ms:n nousu. Audioengine muuntaa formaatin tarvittaessa laitteen näytetaajuuteen. Valinta tallentuu ja sen vaihtaminen hiljentää äänenannon. Piano säilyttää moniäänisen soiton ja Pidon. Viritysäänessä koskettimen napautus jättää yhden sävelen soimaan; seuraava kosketin vaihtaa sen. Hiljennä kaikki, tilanvaihto ja sovelluksen taustalle siirtyminen lopettavat äänen. Pito näkyy vain pianotilassa. Metronomi ja äänenannon voimakkuussäätö toimivat molemmissa tiloissa.

SoundFont-vaihtoehdossa `ReferenceTone.swift` käyttää AVAudioUnitSampleria ja GeneralUser GS:n Pipe Organ -soitinta (GM-ohjelma 20, nollasta laskettuna 19). SoundFontin omat silmukat tuottavat jatkuvan äänen. Vaihto ja sammutus käyttävät noin 18 ms:n gain-häivytystä; nopea uusi valinta peruuttaa edellisen siirtymän. Sama audioengine tuottaa metronomin, pianon ja viritysäänen. Nykyinen oletus on tarkka, näytteistä riippumaton viritysääni; GeneralUser GS:n urut ovat edelleen valittavissa Asetuksissa. SoundFontin viritystaso säädetään samplerin desimaalitarkkuutta tukevalla hienovirityksellä. SoundFont ja lisenssi kopioitiin alkuperäisiä muuttamatta `SoundFonts`-resursseihin ja tarkistettiin sovelluspaketista.

Aiemmassa SoundFont-offline-testissä viritysääni jatkui kuusi sekuntia, sammui ja pysyi rajatuissa ääniarvoissa. Perustaajuus oli noin 440,025 Hz ja 442,064 Hz (alle 0,3 sentin poikkeama tässä Macin offline-renderöinnissä). Nopeiden valintojen jälkeinen välitön pysäytys ei käynnistänyt ääntä uudelleen. Simulaattorissa testattiin sävelen jääminen korostetuksi, vaihtaminen toiseen säveleen ja Hiljennä kaikki metronomin käydessä. Ääntä ei kuunneltu; iPhonen sävelkorkeus, äänen miellyttävyys ja katkaisujen pehmeys pitää vielä tarkistaa laitteella.

Testi: käännä `ReferenceTone.swift`, `ReferenceOscillator.swift`, `Temperament.swift`, `Localization.swift` ja `Tests/ReferenceToneChecks/main.swift` yhdessä xcrun swiftc:llä, ja anna ohjelmalle SoundFontin tiedostopolku. Testi käyttää AVAudioEnginen offline-renderöintiä, ei mikrofonia tai kaiutinta. Macin sandbox voi estää sampler-audioyksikön löytymisen.

### Viritystasot ja 24 säveltä oktaavissa

Asetuksissa voi valita A4 = 415, 440 tai 442 Hz tai syöttää oman arvon 300–500 Hz (desimaalipilkku ja piste hyväksytään). Arvo ja 12/24-sävelinen asteikko tallennetaan seuraavaa käyttökertaa varten. Päänäkymässä näkyvät aktiivinen A4 ja asteikon sävelmäärä.

24-sävelinen tasavireinen asteikko jakaa oktaavin 50 sentin askeliin. Jokainen pianokosketin jaetaan vasempaan perussäveleen ja oikeaan ↑-merkittyyn, 50 senttiä korkeampaan säveleen. Näkyvän alueen viimeinen C on rajakosketin ilman ylimääräistä puolikasta. Koskettimistolla on enemmän vieritettävää leveyttä, jotta puolikkaiden osuma-alue säilyy aiemman kokoisena. Soitto, korostukset, Pito ja jatkuva viritysääni käsittelevät puolikkaat erillisinä sävelinä; asteikon vaihtaminen hiljentää äänenannon. Metronomi jatkaa ennallaan.

Offline-testeissä 415 Hz, 443,5 Hz ja 442 Hz:n A4↑ olivat alle puolen sentin päässä tavoitetaajuudesta. UI:ssa testattiin oman arvon 443,5 syöttö desimaalipilkulla, asteikon vaihto 12 → 24 → 12 ja C3↑:n jatkuva ääni sekä korostus. Todellista monikosketusta tai iPhonen taajuuksia ei testattu. Pianon esiladatuista näytteistä renderöidyt A4 ja A4↑ mitattiin noin −1,9 ja +2,0 sentin poikkeamilla (näytteiden oma sävelkorkeus vaihtelee hieman). Taajuustarkistuksen voi uusia Swift-testien jälkeen komennolla `python3 Tests/ReferenceToneChecks/check_pitch.py`; se tarvitsee NumPyn. Asetuksissa on myös pythagoralainen ja ¼-komman keskisävelviritys.

## Pianonäytteet ja viritys

Alkuperäiset tiedostot kopioitiin kansiosta `/Users/attetenkanen/AndroidStudioProjects/pianokosketinsoundit`; niitä ei muokattu. Projektin `PianoSamples` sisältää 25 stereo PCM WAV -tiedostoa, 44,1 kHz / 16 bit, noin 1,26–1,51 sekuntia. Xcoden synkronoitu lähdekansio liittää ne automaattisesti sovelluspakettiin (nykyisessä käännöksessä paketin juureen). Sovellus lukee vain Bundle.main-resursseja.

Spektrianalyysin perustaajuudet vastaavat MIDI-numeroita 55–79 eli G3–G5. Myös yläsävelrakennetta tarkastettiin; voimakkain spektrihuippu ei aina ole perustaajuus. Mitattu A4-näyte on noin 439,672 Hz. Näytteistä laskettu A4-vastaavuus vaihtelee noin 436,7–440,0 Hz, joten yhtä täsmällistä alkuperäistä viritystasoa ei voi ilmoittaa. Kunkin näytteen mitattu perustaajuus toimii toistonopeuden korjauksen lähtökohtana. Pianoäänessä on useita hieman eri taajuuksilla soivia komponentteja; mittaus on arvio, ei tallentajan viritysmetadata.

G3–G5-alueella jokainen kosketin käyttää omaa näytettään. Alueen ulkopuolella lähin reunasävel transponoidaan C2–C6:n kattamiseksi. Äänen väri muuttuu siksi ääripäissä. Mittaustulokset ovat `Tests/sample-analysis.csv`, ja `Tools/analyze_samples.py` toistaa analyysin (vain kehitystyökalu, tarvitsee NumPyn).

## Tehdyt tarkistukset

- Xcode 27.0: iOS Simulator Debug -käännös onnistui ilman allekirjoitusta.
- 25 pakattua näytettä tarkistettiin; sovellus asennettiin ja käynnistettiin iPhone 11 Pro Max / iOS 26.5 -simulaattorissa.
- Simulaattorin päänäkymä tarkastettiin visuaalisesti sekä pysty- että vaaka-asennossa. Metronomin käynnistys/pysäytys ja tempon syöttö 80 → 96 → 80 testattiin käyttöliittymän kautta. Kaksinkertaiset kosketinleveydet ja vaakavedolla vierittäminen tarkistettiin simulaattorissa.
- Tuotannon AudioRendererilla ajetut offline-tarkistukset läpäisivät: tarkat iskuvälit, 2/3/4/6-iskujen kierto ja korostus, tempon muutos, 97 samanaikaista säveltä, silmukoiden jatkuminen, rajattu ääniulostulo ja vapautuksen vaimeneminen.
- Ääntä ei kuunneltu. Todellista monikosketusta, laitteen viivettä, keskeytyksiä ja kaikkia näyttökokoja ei testattu.

Offline-tarkistusten uusinta projektin juuresta:

```sh
xcrun swiftc -module-cache-path /tmp/ChoirSwiftCache 'Choir Master/AudioRenderer.swift' 'Choir Master/PianoSampleMetadata.swift' Tests/AudioRenderChecks/main.swift -o /tmp/choir-audio-checks
/tmp/choir-audio-checks 'Choir Master/PianoSamples'
```

## Kokeile oikealla iPhonella

1. Soita usean sormen sointu metronomin käydessä. Kuuntele viive, äänen tasaisuus, klikkauskorostus ja säröttömyys.
2. Vapauta koskettimet; äänten pitää sammua pehmeästi. Kokeile Pitoa, saman sävelen uudelleenpainallusta, Pidon poistamista ja Hiljennä kaikki -painiketta.
3. Kokeile 30/240 BPM, nuolten pitkä painallus, tempon numerosyöttö käynnissä sekä kaikkia tahtilajeja ja 6/8:n kumpaakin tulkintaa.
4. Vertaa 440/442 Hz viritysmittarilla ja kuuntele pitkään pidetyn soinnun silmukka. Tarkista C2 ja C6 sekä H/B-nimistö.
5. Siirrä sovellus taustalle, lukitse puhelin, kokeile äänikeskeytystä ja irrota kuulokkeet. Äänten tulee pysähtyä. Tarkista näytön hereilläpito ja asetusten säilyminen uudelleenkäynnistyksessä.
6. Kokeile pienintä käytettävää iPhonea, vaaka-asentoa ja suurennettua tekstikokoa. Pianon kosketustuntuma ja painikkeiden käytettävyys on arvioitava laitteella.

## Historialliset viritysjärjestelmät

Asetuksissa valitaan tasavireinen, luonnonvire, pythagoralainen, ¼-komman keskisävel, Werckmeister III, Kirnberger III tai Vallotti. Muulle kuin tasavireiselle valitaan pohjasävel. `Temperament.swift` laskee yhteisen sävelkorkeuden sekä pianolle että SoundFont-viritysäänelle. A4 on aina täsmälleen valittu vertailutaajuus laskennassa. Pythagoralaisessa ja ¼-komman keskisävelvirityksessä pohjasävel sijoittaa 12 sävelen kvinttiketjun (−3…8 kvinttiä); C-pohjalla ketju kulkee Es–B–F–C–G–D–A–E–H–Fis–Cis–Gis. Kvinttiketjun sulkemiseen jää susikvintti. Mustien koskettimien enharmoniset nimet eivät tarkoita historiallisessa virityksessä samaa taajuutta.

24-sävelinen valinta käyttää tasavireistä asteikkoa. Sen valitseminen vaihtaa järjestelmän tasavireiseksi, historiallisen järjestelmän valinta palauttaa 12 sävelen asteikon. Muutokset hiljentävät äänenannon; metronomi jatkaa. Järjestelmä ja pohjasävel tallennetaan. Luonnonvire on kiinteä, pohjasäveleen suhteutettu 5-limit-asteikko; automaattista soinnun tunnistusta ja harmonian mukaan muuttuvaa viritystä ei ole.

Laskenta perustuu kvinttisuhteisiin 3/2 ja 5^(1/4), ks. [BYU:n tutkimusjulkaisu](https://physics.byu.edu/docs/publication/2791). `Tests/TemperamentChecks/main.swift` tarkistaa A4-ankkurin, oktaavit, pythagoralaiset kvintit ja keskisävelvirityksen 5/4-terssit kaikilla pohjasävelillä sekä 24-EDO-askeleen. Käännä testi yhdessä Temperament.swiftin ja Localization.swiftin kanssa. Myös aiempi ReferenceTone-offline-testi tarvitsee nyt Temperament.swiftin käännöslähteeksi. Uusien viritysten ääntä ei kuunneltu eikä niitä kokeiltu oikealla iPhonella.

### Luonnonvire ja kiertävät historialliset viritykset

Luonnonvireen kromatiikka käyttää suhteita 1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8. Tämä on yksi 5-limit-kromatiikan valinta, ei kaikille soinnuille yhtä aikaa puhdas yleisviritys. Valitun pohjasävelen duurikolmisointu on 4:5:6 ja mollikolmisoinnun terssi 6:5. Vaihda pohjasäveltä harjoiteltavan harmonian mukaan. [SFU:n akustiikan käsikirjan suhteet](https://www.sfu.ca/sonic-studio-webdav/handbook/Just_Tuning.html).

C-pohjan kiertävät järjestelmät:

- Werckmeister III: C–G, G–D, D–A ja H–Fis kapenevat ¼ pythagoralaisella kommalla; muut kvintit puhtaita. [Cembalonrakentajan viritysohje](https://www.hpschd.nu/tech/tmp/werckmeister.html).
- Kirnberger III: C–G, G–D, D–A ja A–E kapenevat ¼ syntonisella kommalla, Fis–Cis skismalla. C–E on puhdas 5:4. [Viritysohje](https://www.hpschd.nu/tech/tmp/kirnberger.html).
- Vallotti: F–C–G–D–A–E–H-ketjun kuusi kvinttiä kapenevat ⅙ pythagoralaisella kommalla; loput puhtaita. [Viritysohje](https://www.hpschd.nu/tech/tmp/vallotti.html).

Pohjasävelen vaihtaminen transponoi kaavion, ja A4 ankkuroidaan uudelleen valittuun hertsilukuun. Kiertävissä järjestelmissä ei ole avoimen kvinttiketjun susikvinttiä. Luonnonvire, viritysjärjestelmä ja barokin 415 Hz:n viritystaso ovat erillisiä valintoja.

Laajennetut laskentatestit läpäisivät kaikkien järjestelmien A4-ankkurin ja oktaavien tarkistukset kaikilla 12 pohjasävelillä; lisäksi puhtaat duuri/molliterssit, kvintit, Werckmeisterin/Vallottin tunnusomaiset terssit ja kaikkien kiertävien järjestelmien kvinttien rajat. Tuotannon SoundFontilla renderöitiin jokaisen järjestelmän E4 kuuden sekunnin ajan ja tarkistettiin katkaisu sekä rajattu ulostulo. E4:n taajuuspoikkeamat olivat noin +0,7…+1,4 senttiä. Näyteääni sekä aiemman toteutuksen kokonaisiin sentteihin pyöristäminen rajoittivat lopullista äänen tarkkuutta; puhtaat laskennalliset suhteet eivät takaa täysin huojumatonta näyteääntä. Uusien järjestelmien ääntä tai käyttöliittymää ei kokeiltu iPhonella.

### Simulaattorin asetusten valinnat

A4, viritysjärjestelmä, pohjasävel ja 12/24-asteikko avaavat nyt erillisen vaihtoehtolistan pienen ponnahdusvalikon sijaan. Päivitetty sovellus asennettiin simulaattoriin; viritysjärjestelmän listan avaaminen, Werckmeister III:n valinta ja palautus tasavireiseksi testattiin hiirellä. Käännös onnistui. Alkuperäinen ponnahdusvalikkokin toimi kokeessa, joten käyttäjän ilmoittamaa täydellistä klikkausongelmaa ei saatu toistumaan.

## Koko alueen viritysäänen tarkistus ja tarkka ääni

SoundFont-urkujen koko alueen mittaus paljasti noin 5,75 sentin suurimman poikkeaman ja noin 7,17 sentin eron eri mittausikkunoiden välillä. Kiinteää kalibrointitaulukkoa ei lisätty: näyteääni ei läpäissyt vakausvaatimusta. Asetukset → Viritysääni → Ääni tarjoaa nyt **Tarkan viritysäänen** (oletus) ja **SoundFont-urut**. Piano käyttää edelleen alkuperäisiä näytteitä.

Tarkasta äänestä mitattiin 4 505 yhdistelmää 44,1 kHz:n ulostulossa ja 391 yhdistelmää 48 kHz:n ulostulossa. Kaikki läpäisivät 0,01 sentin rajan (mitattu suurin poikkeama noin 0,00014 senttiä). Näin pienet offline-poikkeamat eivät ole lupaus fyysisen laitteen tarkkuudesta. [Tarkat tulokset ja rajaukset](Tests/ReferencePitchSweep/RESULTS.md), [testin uusinta](Tests/ReferencePitchSweep/README.md).

iOS Simulator -käännös onnistui. Simulaattorissa tarkistettiin äänen lähteen vaihto, jatkuva C3 → E3 -ääni metronomin käydessä ja Hiljennä kaikki. Kuuden sekunnin sointi, pehmeä pysäytys ja nopeiden vaihtojen peruutus läpäisivät offline-testit. Ääntä ei kuunneltu eikä iPhonen ääniulostuloa mitattu. Oikealla iPhonella tulee vielä tarkistaa sävelkorkeus riippumattomalla mittarilla, äänen miellyttävyys, katkaisujen pehmeys ja käytetyt kaiutin-/kuuloke-/Bluetooth-reitit.

## Tallennetut aloitussoinnut

Pääruudun **Soinnut** avaa nimettyjen sointujen listan. **Valitse sävelet koskettimistolla** palauttaa pianotilan, hiljentää aiemman äänenannon ja kytkee Pidon päälle. Valitse sävelet yksi kerrallaan tai monikosketuksella, avaa Soinnut uudelleen, anna nimi ja tallenna. Jokainen muistipaikka sisältää sävelet, viritysjärjestelmän, pohjasävelen, A4-tason ja 12/24-asteikon. Viritysäänen lähdettä, tempoa tai tahtilajia ei tallenneta sointuun.

Soinnun napautus palauttaa sen viritysasetukset, vaihtaa pianotilaan ja käynnistää kaikki sävelet saman audiopuskurin rajalla. Pito jää päälle; Hiljennä kaikki tai Pidon poistaminen vapauttaa soinnun. Metronomi jatkaa. Nimen vieressä oleva valikko tarjoaa nimeämisen ja poistamisen vahvistuksella. `SavedChord.swift` vastaa tietomuodosta ja tarkistamisesta, `ChordLibraryView.swift` listanäkymästä; UserDefaultsiin tallennettu JSON säilyy käynnistysten välillä.

Soinnut käyttävät pianonäytteitä ja niiden olemassa olevaa virityskorjausta. Luonnonvireen laskennalliset suhteet välittyvät näytteiden toistonopeuteen, mutta tämä ei tee pianoäänen omista komponenteista täysin huojumattomia. Tarkka jatkuva viritysääni on edelleen yksisävelinen; sointujen toisto tarkalla synteesiäänellä ei ole tässä vaiheessa mukana.

`Tests/ChordStoreChecks/main.swift` tarkistaa nimettyjen profiilien ja neljäsosasävelten tallennuksen/latauksen, virheellisten sävelten torjunnan, aiempien tietojen säilymisen hylätyn tallennuksen jälkeen sekä rikkinäisen JSON:n tunnistamisen. Käännä yhdessä Temperament.swiftin, SavedChord.swiftin ja Localization.swiftin kanssa. Testit ja iOS Simulator -käännös läpäisivät.

Simulaattorissa valittiin C3–E3–G3 Pidolla, tallennettiin **C-duuri** luonnonvireessä A4 = 442 Hz, käynnistettiin sovellus uudelleen ja soitettiin muistipaikka yhdellä painalluksella metronomin käydessä. Koskettimien kolme korostusta ja Hiljennä kaikki tarkistettiin käyttöliittymästä. Esimerkkisointu jäi simulaattoriin. Ääntä ei kuunneltu eikä todellista monikosketusta testattu. Kokeile laitteella soinnun yhteistä aloitusta, pehmeää vapautusta ja viritysasetusten palautumista toisista asetuksista.

## Äänitys, tahtilajin valinnat ja käyttöliittymän kielet

Pääruudun mikrofonipainike avaa äänityspaneelin. **Aloita äänitys** pyytää mikrofoniluvan vasta ensimmäisellä käyttökerralla. Paneelissa näkyvät kesto sekä käynnistys- ja lopetuspainike. Paneelin voi sulkea äänityksen jatkuessa; pääruudun punainen mikrofonikuvake kertoo käynnissä olevasta äänityksestä. Metronomia ja äänenantoa voi käyttää samalla. Äänitys tallentaa mikrofonin äänen, ei suoraa digitaalista kopiota metronomin tai pianon ulostulosta; kaiuttimesta kuuluva ääni voi tallentua mikrofonin kautta.

Tallenteet ovat paikallisia mono-AAC / M4A -tiedostoja (44,1 kHz, 128 kbit/s) sovelluksen Documents/Recordings-kansiossa. Lopetuksessa kesto luetaan valmiista tiedostosta; tallenne tallentuu automaattisesti ilman nimeämistä. Listasta voi kuunnella, nimetä, jakaa iOS:n jakonäkymällä ja poistaa vahvistuksen jälkeen. Tiedoston UUID-nimi ei muutu nimeämisessä. `RecordingManager.swift` hoitaa mikrofonin ja toiston, `RecordingStore.swift` tarkistaa ja tallentaa metatiedot atomisesti, `RecordingView.swift` näyttää paneelin. Jos indeksitiedosto on vaurioitunut, siitä säilytetään varmuuskopio ja luettavat äänitiedostot palautetaan listaan.

Taustalle siirtyminen, äänikeskeytys tai käytössä olevien kuulokkeiden irrotus lopettaa äänityksen ja muun äänen. Pelkkä hetkellinen inactive-tila (esimerkiksi lupakysely) hiljentää äänenannon, mutta varsinainen background-tila pysäyttää myös tallennuksen. Tallenteen kuuntelu pysäyttää metronomin ja äänenannon. Mikrofoniin siirtyvän audioistunnon laitteistomuutoksessa aktiivinen audioengine käynnistetään uudelleen rendererin tilaa säilyttäen. Reitin vaihdon todellinen katkos ja samanaikaisen äänityksen toiminta on vielä tarkistettava laitteella.

Tahtilajin numerot ovat vähintään 44 pisteen painikkeita. Osoittaja avaa rivivalinnan **1–16**, nimittäjä **1, 2, 4, 8, 16**. Valittu vaihtoehto näkyy valintamerkillä; valinta sulkee listan. Pystyasennossa metronomin käynnistys/pysäytys on vieritysalueen ulkopuolella, joten se säilyy näkyvissä myös 6/8-valinnalla ja pitkissä käännöksissä.

**Asetukset → Kieli** sisältää suomen ja 30 muuta kielivalintaa. Kielivalinta tallentuu ja vaihtuu ilman uudelleenkäynnistystä. Oikealta vasemmalle kirjoittavat kielet saavat vastaavan asettelun; pianon sävelkorkeudet kasvavat silti aina vasemmalta oikealle. Sävelnimien H/B- tai B/B♭-valinta säilyy kielestä riippumattomana.

Kielijoukko perustuu [vuoden 2026 kokonaispuhujamäärien luetteloon](https://en.wikipedia.org/wiki/List_of_languages_by_total_number_of_speakers), joka erottaa myös kielivariantteja. Valinnat ovat englanti, mandariinikiina, hindi, espanja, arabia, ranska, bengali, portugali, indonesia, urdu, venäjä, saksa, japani, Nigerian pidgin, Egyptin arabia, marathi, vietnam, telugu, swahili, hausa, turkki, läntinen pandžabi (Shahmukhi), tagalog, tamili, kantoninkiina, wu-kiina, persia, korea, amhara ja thai. Wu-valinta käyttää yhteistä kirjoitettua kiinaa (merkitty kielivalikon nimessä); Egyptin arabia käyttää muodollista kirjoitettua arabiaa. Suomen kanssa valintoja on yhteensä 31.

Kaikki 122 käyttöliittymätekstiä ja mikrofoniluvan kuvaus on pakattu paikallisiin `.lproj`-resursseihin. Käyttäjän kirjoittamia sointujen ja tallenteiden nimiä ei käännetä. iOS:n lupakyselyn ja jakonäkymän kieli määräytyy järjestelmän omista kieliasetuksista. Sovellus ei käytä käännöspalvelua ajon aikana. Kehitysvaiheen konekäännökset, pidgin-luonnos ja erilliset musiikkitermien korjaukset ovat **alustavia käännöksiä**, eivät äidinkielisesti hyväksyttyjä julkaisutekstejä. Erityisesti historiallisten viritysten ohjeet on tarkistettava kielittäin ennen julkaisua.

Käännösten ylläpitotiedostot ovat `Tools/localization_source.json`, `Tools/languages.json`, `Tools/pidgin_translations.json` ja `Tools/localization_overrides.json`. Kehitystyökalu `generate_localizations.py` hakee vain yleisiä englanninkielisiä käyttöliittymätekstejä julkisesta käännöspalvelusta; projekti, näytteet, tallenteet tai käyttäjän tiedot eivät kuulu pyyntöihin. Aja tämän jälkeen `finish_localizations.py`, joka palauttaa erilliset terminologiakorjaukset ja yhteiset kirjoituskielet. Sovellus itse ei sisällä näitä verkkohakuja.

Uudet tarkistukset:

```sh
python3 Tests/LocalizationChecks/check.py
xcrun swiftc -module-cache-path /tmp/ChoirSwiftCache 'Choir Master/RecordingStore.swift' Tests/RecordingStoreChecks/main.swift -o /tmp/choir-recording-store-check
/tmp/choir-recording-store-check
```

Kielitesti tarkistaa 31 × 122 tekstin kattavuuden, paikkamerkkien määrän, tyhjät käännökset ja Applen `.strings`-syntaksin. Testille voi antaa käännetyn `.app`-kansion polun kaikkien kieliresurssien paketoinnin tarkistamista varten. Tallennetietojen testi tarkistaa tallennuksen/latauksen, uudelleennimeämisen, tiedostonimien riippumattomuuden käyttäjän syötteestä, virheellisten kestojen ja päällekkäisten tunnisteiden torjunnan sekä vanhojen tietojen säilymisen hylätyssä tallennuksessa. Aiemmat Foundation-testit tarvitsevat nyt myös `Localization.swift`-tiedoston käännöslähteeksi.

Käännös, resurssitesti, tallennetietojen testi, viritystesti ja sointujen tallennustesti läpäisivät. Simulaattorissa tarkistettiin osoittajan ja nimittäjän valinta hiirellä, äänityspaneelin avautuminen sekä englanninkielinen päänäkymä. Suomi → arabia → suomi -kielenvaihto, valintarivien nimien päivittyminen ja arabian oikealta vasemmalle asettuva päänäkymä/asetussivu tarkistettiin. Mikrofonista ei tehty oikeaa äänitystä eikä tallenteita kuunneltu tässä ympäristössä.

Kokeile iPhonella: mikrofoniluvan myöntäminen ja epääminen, lyhyt harjoitusäänitys, samanaikainen metronomi/piano, lopetus ja heti kuuntelu, tallenteen säilyminen uudelleenkäynnistyksessä, nimeäminen/jakaminen, taustalle siirtyminen ja kuulokkeiden irrotus äänityksen aikana. Tarkista lisäksi pitkät käännökset pienellä näytöllä ja suurennetulla tekstillä.

## Luotettavuuskorjaukset 11.10.2026

Projektissa on nyt `ChoirMasterTests`-testikohde, joka ajetaan jaetulla Choir Master -schemellä Xcodessa Cmd–U:lla. Korjausten kuvaus, tarkistukset ja laitetestilista ovat `RELIABILITY.md`-tiedostossa. Paketin pianonäytteiden taajuudet ja silmukka-asetukset löytyvät `PianoSamples/metadata.json`-resurssista; alkuperäisiä Macin äänitiedostoja ei muutettu.

## Tallenteen säveltason analyysi iOS:llä

Tallenneluettelon **Analysoi säveltaso** avaa paikallisen jälkianalyysin myös
aiemmin tallennetuille M4A-tiedostoille. Laskenta vastaa Androidin
`android-lab-10`-menetelmää: 15 sekunnin jaksot, kahden sekunnin askel,
A4-asetukseen suhteutettu taso, 100 sentin monitulkintaisuus ja enintään
12 sentin muutos pistettä kohti. Epävarmat havainnot ja pitkät tauot katkaisevat
piirretyn käyrän. Lyhyt, alle 15 sekunnin tallenne näyttää ohjeen pidemmästä
äänitteestä. Käyrän rinnalla voi kuunnella tallennetta ja siirtyä sen eri kohtiin.

Laskenta toimii taustatyönä, näyttää edistymisen ja voidaan perua. Johdettu,
enintään 1 200 piirrettävän pisteen tulos tallennetaan atomisesti erilliseen
Analysis-kansioon. Lähdetiedoston SHA-256, A4 ja menetelmäversio tarkistetaan
uudelleen avattaessa. Tallenteen poistaminen poistaa myös sen analyysituloksen.
Taustalle siirtyminen peruu analyysin. Uudet tekstit ovat suomeksi ja englanniksi;
muut kielet käyttävät englanninkielistä varatekstiä.

Nykyisiin iOS-tallenteisiin ei ole kirjattu piano-/metronomiäänten aikavälejä,
joten niitä ei voida sulkea luotettavasti analyysistä. Käyttöliittymä kertoo
mahdollisesta vaikutuksesta. Menetelmä on kokeellinen, ja oikean kuoron
mittaustarkkuuden validointi on avoin.

Tarkistukset 15.11.2026: Xcoden testikäännös ja kaikki 14 simulaattoritestiä
läpäisivät iOS 18.5:llä. Erilliset Swift-testit läpäisivät myös WAV/M4A-dekoodauksen,
perumisen sekä välimuistin tarkistukset. Kolmen identtisen PCM-aineiston 65 pistettä
vastasivat Androidin tuloksia alle 0,000001 sentin erolla. Simulaattoriajossa
havaittu AudioSessionCoordinatorin eristetyssä vapautuksessa syntyvä kaatuminen
korjattiin eksplisiittisellä nonisolated-deinitillä. Käyttöliittymää ei tarkistettu
visuaalisesti eikä analyysiä validoitu fyysisellä iPhonella.

[Testien uusinta](Tests/RecordingAnalysisChecks/README.md).
