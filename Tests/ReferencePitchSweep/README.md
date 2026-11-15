# Jatkuvan viritysäänen mittaus

Tuotannon `ReferenceTone`, `ReferenceOscillator` ja `Temperament` käännetään yhdessä `main.swift`-testin kanssa. Testi käyttää AVAudioEnginen offline-renderöintiä; se ei käytä mikrofonia tai kaiutinta. NumPy tarvitaan vain kehitystyökalussa `analyze.py`.

```sh
xcrun swiftc -O -module-cache-path /tmp/ChoirSwiftCache 'Choir Master/Temperament.swift' 'Choir Master/Localization.swift' 'Choir Master/ReferenceOscillator.swift' 'Choir Master/ReferenceTone.swift' Tests/ReferencePitchSweep/main.swift -o /tmp/choir-reference-sweep
/tmp/choir-reference-sweep 'Choir Master/SoundFonts/GeneralUser-GS.sf2' /tmp/choir-reference-sweep-output
python3 Tests/ReferencePitchSweep/analyze.py /tmp/choir-reference-sweep-output --report /tmp/choir-reference-sweep.csv --limit .01
```

Lisävalinnat: `--48000` renderöi audioengine-ulostulon 48 kHz:n muodossa ja tarkistaa 391 säveltä. `--baseline` renderöi 49 korjaamatonta SoundFont-urkusäveltä 440 Hz:n tasolla; analysoi ne `--characterize`-valinnalla, koska näyteääni ei täytä tarkan viritysäänen rajoja.

44,1 kHz:n päätestin 4 505 yhdistelmää:

- Kaikki 49 C2–C6-säveltä kaikilla seitsemällä viritysjärjestelmällä ja C-lähtösävelellä, A4 = 415/440/442 Hz.
- Muut 11 lähtösäveltä kaikilla kuudella ei-tasavireisellä järjestelmällä koko alueelta, A4 = 442 Hz.
- Kaikki 48 lisättyä neljäsosasäveltä tasavireisessä asteikossa, A4 = 415/440/442 Hz.
- Oman viritystason rajat 300 ja 500 Hz koko 49-säveliseltä alueelta tasavireisinä.

Mittaus: 0,6 sekuntia asettumista, 2,05 sekunnin mono Float32 -tallenne. Hann-ikkunoitu FFT ja logaritminen kolmen pisteen huippuinterpolaatio mittaavat perustaajuuden tavoitteen läheltä. Ensimmäinen ja viimeinen sekunti mitataan erikseen vakauden tarkistamiseksi. Perustaajuushuipun erottuminen ympäristöstä ja rajan ulkopuoliset osumat tarkistetaan. Testi vertaa mitattua ääntä tuotannon laskemaan taajuuteen; viritysjärjestelmien matemaattiset suhteet tarkistetaan erikseen `TemperamentChecks`-testissä.

Rajat: <0,01 sentin taajuuspoikkeama ja <0,1 sentin ero aikaisen/myöhäisen mittausikkunan välillä. Kaikkien renderöityjen näytteiden tulee olla äärellisiä ja rajattuja; testin lopussa tarkistetaan hiljaisuus. Näitä erittäin pieniä offline-poikkeamia ei pidä tulkita iPhonen DAC:n kellon tai kaiutin-/Bluetooth-toiston todelliseksi tarkkuudeksi. Fyysisen laitteen ulostulo on vielä mitattava riippumattomalla laitteella.

`baseline.csv` kuvaa alkuperäisen SoundFont-urkuäänen havaittuja poikkeamia. `square-baseline.csv` dokumentoi myös kokeillun SoundFont-synteesiäänen; sitä ei otettu käyttöön. Kiinteää kalibrointitaulukkoa ei lisätty, koska mitattu korkeus riippui mittausikkunasta. Sovelluksen oletus on suoraan laskettuun taajuuteen tuotettu tarkka viritysääni. SoundFont-urut säilyvät käyttäjän valittavana.
