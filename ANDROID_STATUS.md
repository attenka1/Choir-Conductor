# Android-siirron tila — 16.10.2026

## Valmista tällä kierroksella

- Nykyinen iOS-työpuu talletettu muuttamatta sovelluslähteitä: a45c5b7.
  Tämä sisältää ennen Android-työtä olemassa olleet nimeämiset ja mainosmuutokset.
- SPEC.md ja ARCHITECTURE.md: hyväksytty suunnitelma, vastuurajat ja kriteerit.
- AKG Lyra USB-C/host: todellisen tuloreitin varmistus, näkyvä tulolaitteen
  valinta, väärään mikrofoniin siirtymisen esto ja irrotuksen turvallinen lopetus.
- Stereo huomioitu sekä tallennuksessa että analyysissä; kanavien kumoutuminen
  vastavaiheessa estetään analysoimalla kanavat erikseen.
- AnalysisLab: suoritettava jälkianalyysikoe, deterministinen testiaineisto,
  vertailuraportin generaattori, PCM16 WAV -lukija ja 16 yksikkötestiä.

## Todella suoritetut tarkistukset

- `python3 -m unittest discover -s tests -v` AnalysisLab-hakemistossa:
  16 testiä läpäisi, viimeinen ajo noin 1,1 s.
- `python3 validate.py`: 14 synteettistä vertailua (7 tapausta × 2 menetelmää).
  RESULTS.json sisältää kattavuuden, virheet ja työasemalla mitatun ajoajan.
- `python3 -m py_compile ...`: neljän Python-tiedoston syntaksitarkistus onnistui.
- `git diff --check`: tarkistetaan myös staged-muutoksille ennen committia.

Nämä testit eivät ole Android-sovelluksen testejä. Android- tai iOS-käännöstä
ja laitetestejä ei tehty tällä kierroksella. Työasemalla ei ole testattu Lyraa,
USB-virransyöttöä, Android-reititystä, mikrofonitallennusta tai todellista kuoroa.

## Vaiheet ja jatko

0. Lähtötilanne/dokumentointi: tehty.
1. Analyysikoe: synteettinen ensimmäinen versio tehty; todellisen kuoron
   validointi vielä avoin. Tuotantokäyttöön ei vielä valmis.
2–6. Androidin audio, käyttöliittymä, musiikkiominaisuudet, äänitteet,
   analyysi-integrointi ja julkaisuvalmius: tekemättä.

Keskustelun työkansion ulkopuolelta löytyi Android Studion aloituspohja:
`../Choir Master Android` (applicationId com.attetenkanen.choirmaster).
Se ei ole Git-repositorio eikä sisällä varsinaisia musiikkiominaisuuksia.
Käyttäjälle lähetettiin sijaintivalinta; pohjaa ei muutettu tämän selvityksen
aikana. Seuraava Android-kohtainen vaihe tehdään valittuun projektikansioon
ja sen nykytilasta luodaan ensin palautuspiste. Arkkitehtuurille ei tarvita
uutta hyväksyntää: käyttäjä hyväksyi sen keskustelussa.

## Tunnetut riskit

Harmonisen suodatuksen alkuperäinen liian tiukka havaintotuen vaatimus hylkäsi
luonnonvireiset soinnut. Juurisyy korjattiin ja tapaus on nyt regressiotesti.
Synteettinen aineisto on yksinkertainen: realistinen vibrato, kaiku,
puuttuvat perussävelet ja muuttuva intonaatio tarvitsevat vielä mittaukset.
Laatupiste ei ole kalibroitu varmuustodennäköisyys. Pitkä tauko katkaisee
käyrän jatkuvuuden. Suoraan WAViin tallentaminen ei poista laitteen aiempaa
signaalinkäsittelyä eikä takaa USB-mikrofonin valintaa.

USB-C-kaapeli, host/OTG, virransyöttö ja puhelimen audioajuri on tarkistettava
käytettävällä puhelinmallilla. Lyran suurin valmistajan ilmoittama formaatti
ei ole lupaus Android-sovelluksessa saatavasta formaattivalikoimasta.
