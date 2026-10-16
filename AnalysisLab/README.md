# Säveltason analyysikoe

Kokeellinen, paikallinen Python/NumPy-prototyyppi ennen Android-integrointia.
Ei valmis kuoron viritysmittari. Toteutus ei käytä tekoälymallia tai verkkoa.

## Toistaminen

Python 3.9+ ja NumPy 2.0.2. Aja tässä hakemistossa:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python validate.py
.venv/bin/python pitch_drift.py /path/to/recording.wav /path/to/result.json
```

Viimeinen komento hyväksyy PCM16 mono-/stereo-WAVin. Se ei muuta alkuperäistä
äänitettä. Syöte luetaan 32768 kehyksen lohkoina. JSON-pisteet säilytetään
CLI:ssä listana (noin viisi pistettä sekunnissa); itse analyysigeneraattori
voi kirjoittaa pisteet suoratoistona. Muissa formaateissa olevia tallenteita
laboratoriolukija ei tue. 24-bittinen Lyra-aineisto edellyttää erillistä
lukijaa; mahdollinen muunnos dokumentoidaan eikä sitä sekoiteta puhelimen
alkuperäiseen formaattiin.

## Menetelmä

16384 näytteen Hann-ikkuna, 0,2 s askel, nollatäytetty FFT ja huippujen
logaritminen interpolointi. Ikkuna on 22,05 kHz:llä noin 743 ms ja 48 kHz:llä
341 ms. Nollatäyttö interpoloi spektriä eikä lisää alkuperäisen signaalin
informaatiota. Kaikki spektrihuiput eivät ole perussäveliä.

Koeversio vaimentaa tunnistettuja yläsäveliä ja muodostaa painoltaan rajatun
100 sentin ympyräjakauman. Vähintään kahden harmonisesti erillisen taajuuden
pitää tukea keskittymää; nämä eivät todista kahta eri laulajaa. Todelliset
oktaavikaksinnukset voivat poistua yläsävelinä. Kolmen peräkkäisen ikkunan
tuki tarvitaan uuden segmentin aloitukseen. Lyhyessä epävarmuudessa säilytetään
jatkuvuus, yli kahden sekunnin katkos aloittaa uuden nollatason. Seuranta on
ahne ja deterministinen, ei Viterbi eikä kalibroitu todennäköisyysmalli.

Stereo analysoidaan kanavittain. Jos molemmat kanavat antavat arvion ja ne
eriävät yli 10 c, tulos hylätään. Muuten käytetään vahvempaa havaintotukea.
Vastavaiheiset kanavat eivät siis kumoa toisiaan. Tämä ratkaisu tarvitsee
vielä kuoroaineistolla arvioinnin myös kanavan vaihtumisen osalta.

## Testit ja tulokset

`fixtures.py` tuottaa yksinkertaisia harmonisia sointuja. `validate.py`
vertaa huippuihin perustuvaa lähtömenetelmää harmoniseen suodatukseen ja
kirjoittaa `RESULTS.json`-raportin. Luvut ovat synteettisen kokeen
mittaustuloksia, eivät puhelimen tai AKG Lyran tarkkuuslupauksia.

Harmonisen version nykyiset synteettiset kokeet: vakaan mutta vaihtuvan
harmonian kattavuus noin 92 %, 95. persentiilin drift-virhe noin 0,31 c.
30 c ja 120 c laskun kattavuus noin 95–96 %. Luonnonvireisten sointujen
kattavuus noin 86 %. Raportti sisältää myös harhasävelen, hallitsevan
vireeltään poikkeavan äänen ja vastavaiheisen stereon.

Ensimmäinen harmoninen suodatus hylkäsi luonnonvireisissä soinnuissa koko
aineiston, koska kolmen taajuuden vaatimus laski oktaavin poiston jälkeen
havaintotuen liian pieneksi. Kahden erillisen taajuuden vaatimus korjasi
juurisyyn näissä kokeissa. Sekä tämä tapaus että yksittäisen harmonisen
äänen hylkäys ovat regressiotestejä. Hyväksymisrajoja ei löysennetty.

Yksikkötestit tarkistavat myös 44,1/48/96 kHz, WAV-lukemisen, lohkorajojen
riippumattomuuden, pitkän tauon, leikkautumisen, kohinan ja hiljaisuuden.
10 minuutin stereo-hiljaisuus testaa suoratoiston muistirajaa. Se EI ole
tunnin mikrofonitallennus tai raskaan lauluaineiston suorituskykytesti.

## Avoimet validointitarpeet

- Aito kuoro, vibrato, epäharmonisuus, puuttuva perussävel, kaiku ja huoneääni.
- Stemmojen voimakkaat tasapainomuutokset ja yksittäisen laulajan dominanssi.
- Vaihtuva luonnonvireinen intonaatio, historialliset viritykset ja modulaatiot.
- Pakattujen tiedostojen vertailu alkuperäiseen, mikrofonin ja puhelimen DSP.
- AKG Lyra Android-puhelimessa, sen suuntakuviot, gain ja USB-reitit.
- Peräkkäisten havaintojen ajallinen riippuvuus: päällekkäiset ikkunat eivät
  ole itsenäisiä todisteita.
- Eri näytetaajuuksien ajallisen erottelukyvyn yhdenmukaistaminen.
- Tunnin oikea tallennus/analyysi, akun kulutus ja lämpeneminen.

Tuotantoon integrointia ei ole hyväksytty tämän kokeen tuloksilla.
