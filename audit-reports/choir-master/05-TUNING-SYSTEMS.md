# 05 — Viritysjärjestelmät

Päiväys: 2026-11-17. Tuotantokoodia ei muutettu. Lähde on `Untitled Project/Choir Master/`.

Tämä vaihe tarkasti sävelten laskennan, sävelnimet ja virittimen kohdehaun. Se ei mitannut kaiuttimen tai SoundFont-samplerin ääntä uudelleen. Pianon spektrihuippujen hajonta on vaiheen 3 havainto, ei uusi kaavavirhe.

## Malli

`Temperament.frequency` (`Temperament.swift` 71–73) on

`f(n) = A4 · 2^((n − 69) / 12 + korjaus(n) / 1200)`.

Korjaus riippuu vain sävelluokasta. A4-ankkuri vähennetään niin, että MIDI 69 pysyy valitussa hertsiluvussa myös silloin, kun pohjasävel ei ole A (`correction`, rivit 66–69). Oktaavi on tämän jälkeen tarkalleen 2:1.

Tasavireessä korjaus on 0, joten kaava on `A4 · 2^((n − 69) / 12)`. Puolisävelaskel 0,5 on 50 senttiä. 24-sävelisyys on kytketty vain tasavireeseen: `ConductorModel` rivit 32–40 vaihtavat järjestelmän tasavireeksi tai palauttavat 12 kosketinta. Asetusteksti kertoo saman (`ContentView.swift` 209).

415 Hz on korkeusvalinta, ei oma viritysjärjestelmä (`ContentView.swift` 185).

## Järjestelmät ja riippumaton vertailu

Python-malli `evidence/tuning-2026-11-17/compare.py` ei kutsunut Swiftin `offset`-silmukkaa. Se laski suhteet ja kvinttiympyrän määritelmistä ja vertasi niitä tuotantokoodin dumppiin. Nykyinen `Tests/TemperamentChecks/main.swift` ajettiin samalla lähteellä: PASS.

| Järjestelmä | Käytetty määritelmä | Tulos tuotantokoodia vasten |
| --- | --- | --- |
| Tasavire | `2^((n−69)/12)`, myös 50 sentin askeleet | täsmää, suurin ero alle 10⁻⁹ |
| Luonnonvire | yksi 5-limit-kromaattinen asteikko: 1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8 | sama suhde pohjasäveleen kaikilla 12 pohjasävelellä |
| Pythagoralainen | 11 puhdasta kvinttiä 3:2, ketju −3…+8 | ketjun kvintit täsmäävät; susikvintti 678,495 senttiä |
| ¼-komman keskisävel | kvintti `300·log2(5)` = 696,578 senttiä, duuriterssi 5:4 | terssi ja 11 kvinttiä täsmäävät; susikvintti 737,637 senttiä |
| Werckmeister III | kvintit C–G, G–D, D–A ja H–Fis kavennettu ¼ pythagoralaisella kommalla | kvinttiympyrä sulkeutuu; C–E = 390,225 senttiä |
| Kirnberger III | C–G, G–D, D–A ja A–E kavennettu ¼ syntonisella kommalla; Fis–Cis skismalla | C–E = 5:4 kaikilla pohjasävelillä; ympyrä sulkeutuu |
| Vallotti | kuusi kvinttiä F–C–G–D–A–E–H kavennettu ⅙ pythagoralaisella kommalla | ei sekoitu Young II:een; C–E = 392,180 senttiä |

Pythagoralainen komma oli 23,460 senttiä ja syntoninen 21,506 senttiä. A4 pysyi arvoissa 300, 415, 440, 442 ja 500 Hz kaikissa järjestelmissä ja pohjasävelissä. Oktaavisuhde nuoteille 36–72 oli 2 alle 10⁻⁹:n erolla.

Suurin poikkeama tasavireestä oli 37,637 senttiä (keskisävel). Virittimen haku katsoo tasavireisen arvauksen ympäriltä ±2 askelta (`PitchDetector.swift` 13–24). Se riittää näille poikkeamille. Tarkka kohdetaajuus palautti oikean sävelen ja alle 10⁻⁶ sentin virheen 7 järjestelmälle, 12 pohjasävelelle ja sävelille 36, 60, 69, 70, 76 ja 84. Tasavireiset 50 sentin askeleet välillä 48–72 palautuivat samoin.

Luonnonvire ei ole yleinen luonnonpuhdas järjestelmä. Tritoni on valittu 45/32, ei esimerkiksi 25/18. Pohjasäveleen rakennettu duuri- ja mollikolmisointu on puhdas; D–A-kvintti ei ole. Teksti `Temperament.swift` riveillä 19 ja `ContentView.swift` rivillä 200 sanoo tämän.

Susikvintin paikka avoimessa ketjussa on pohjasävelestä kahdeksan ja kolme kvinttiaskelta (`ContentView.swift` 202). Se on sama pari kuin ketjun päät.

## Sävelnimet

Oktaavimerkintä on MIDI/12 − 1. Tuotannon `NoteNaming.label` antoi C2, C4, A4 ja C6 sekä ↑-merkin puolikkaalle. Kansainväliset C-pohjaiset nimet täsmäävät ketjuun: keskisävelen ja Pythagoraan mustat koskettimet ovat C♯, E♭, F♯, G♯ ja B♭, eivät D♯ tai A♯. Luonnonvireen 16/15 kirjoitetaan D♭:ksi, koska suhde on pieni sekunti eikä korotettu C. Kaikilla 7 × 12 × 2 nimitaululla oli 12 eri nimeä.

## Äänenantoon meno

- Tarkka viritysääni saa `frequency`-arvon suoraan (`ReferenceTone.swift` 75 ja 117).
- SoundFontin `globalTuning` on sentteinä sama suure. `Float`-muunnos muutti sitä enintään 0,000030 senttiä testatuissa A4-arvoissa ja sävelissä. Tätä ei soitettu samplerin läpi tässä vaiheessa.
- Piano kertoo tavoitetaajuuden näytteen `fundamentalHz`-arvolla (`ConductorModel.swift` 163–166). Suhde on kaavan mukainen. Näytteen todellinen spektrihuippu on eri kysymys, ja se jää vaiheen 3 mittaukseen.

## Löydös

**TUN-001, IMPROVEMENT, varmistettu ajamalla `NoteNaming`.** Suomen tasavire käyttää kirjaimellisia etumerkkejä Es, Fis ja Gis (`NoteNaming.swift` rivi 5). Suomen luonnonvire, Pythagoralainen ja keskisävel korvaavat ne merkeillä E♭ ja F♯ (rivit 17–32). Pohjasävelen valitsin lukee tasavireiset nimet (`ConductorModel.rootNames`, `ContentView.swift` 196–197), koskettimet historialliset. Sävelkorkeus ja sävelluokka eivät tästä vaihdu. Kansainvälinen nimistö on yhtenäinen.

## Rajaus

Ei kuunneltu, ei soitettu SoundFont-sampleria, ei ajettu koko ReferencePitchSweep-matriisia eikä mitattu iPhonen DAC-lähtöä. Laulajan epäpuhdas sävel ja kahden kohteen tasatilanne virittimessä jäivät kokeilematta; tarkat kohteet ja suurin teoreettinen etäisyys tasavireestä tarkistettiin.
