# Viritysäänen mittaustulos

Macin AVAudioEngine-offline-renderöinti, 11.10.2026. Tämä mittaus ei ole fyysisen iPhonen ääniulostulon kalibrointi.

| Viritysjärjestelmä | Mittauksia (44,1 kHz) | Suurin poikkeama, senttiä |
|---|---:|---:|
| Tasavireinen | 389 | 0.000141 |
| Luonnonvire | 686 | 0.000100 |
| Pythagoralainen | 686 | 0.000096 |
| ¼-komman keskisävel | 686 | 0.000103 |
| Werckmeister III | 686 | 0.000098 |
| Kirnberger III | 686 | 0.000099 |
| Vallotti | 686 | 0.000095 |

Kaikki 4 505 mittausta läpäisivät 0,01 sentin rajan. Suurin poikkeama oli 0,000142 senttiä; aikaisen ja myöhäisen mittausikkunan suurin ero oli 0,000077 senttiä. 48 kHz:n ulostulossa tarkistettiin 391 säveltä: suurin poikkeama oli 0,000131 senttiä ja ikkunoiden välinen ero alle 0,00002 senttiä. Viimeistellyn näytekohtaisen äänenvoimakkuushäivytyksen jälkeen 48 kHz:n testi uusittiin samalla tuloksella. Tarkat tiedot ovat CSV-tiedostoissa.

A4 = 415/440/442 Hz: kaikki C2–C6-sävelet kaikissa järjestelmissä C-lähtösävelellä. Lisäksi kaikki historiallisten järjestelmien ja luonnonvireen muut lähtösävelet koko alueelta A4 = 442 Hz:n tasolla; tasavireiset 50 sentin välisävelet kaikilla kolmella tasolla; oman viritystason 300/500 Hz rajat tasavireisinä. Muita mukautettuja arvoja tai kaikkia lähtösävelten ja hertsitasojen ristiinyhdistelmiä ei mitattu.

SoundFont-urkujen alkuperäisessä 49-sävelen mittauksessa suurin poikkeama oli noin 5,75 senttiä ja suurin eri mittausikkunoiden ero noin 7,17 senttiä. Näiden havaintojen perusteella kiinteää korjaustaulukkoa ei otettu käyttöön. Oletuksena käytetään suoraan taajuuteen tuotettua viritysääntä; SoundFont-urut pysyvät valittavissa. Pianonäytteisiin tämä muutos ei vaikuta.

Myös kuuden sekunnin sointi, pehmeä pysäytys, ääniarvojen rajat ja nopeiden vaihtojen peruutus tarkistettiin tuotannon ReferenceTone-luokalla. Simulaattorissa kokeiltiin äänen lähteen valintaa, jatkuvan sävelen vaihtoa metronomin käydessä sekä Hiljennä kaikki -toimintoa. Ääntä ei kuunneltu, oikeaa monikosketusta ei kokeiltu eikä fyysisen iPhonen DAC-, kaiutin- tai Bluetooth-ulostuloa mitattu.

Aiempi kokonaisiin sentteihin pyöristäminen poistettiin SoundFont-soitosta. [Applen globalTuning-rajapinta](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler/globaltuning) käyttää Float-tyyppistä senttiarvoa. Aiempi maininta samplerin yhden sentin pakollisesta rajoituksesta oli virheellinen.

Uusintaohje: [README.md](README.md).
