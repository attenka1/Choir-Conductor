# 11 — Löydösrekisteri (osittainen)

Päivitetty: 2026-11-17. Kattaa vaiheet 1–4. Tämä ei ole koko
sovelluksen puutelista eikä osoitus siitä, että muilla alueilla ei olisi vikoja.
Alkuperäisen erillisen auditoinnin F-tunnuksia ei kopioida avoimiksi löydöksiksi
ilman nykytilan todentamista.

| ID | Vakavuus | Varmuus | Löydös | Todiste | Tila |
| --- | --- | --- | --- | --- | --- |
| MET-001 | MEDIUM | varmistettu malliajolla ja UI-kutsupolulla | 6/8-palautusmuisti tyhjenee rajanuolen no-opista; paluu muuttaa 96:n 80:ksi tai 80:n 90:ksi | Raportti 03; `testNoOpBoundaryArrowsLoseReturnTempoCharacterization`; `ConductorModel` 24/173/312–327, `ContentView` 80/84 | avoin, ei koodikorjausta auditissa |
| MET-002 | LOW | varmistettu tallennetun tilan uudelleenluvulla | Palautuksen lähtötempo ei säily mallin uudelleenalustuksen yli | Raportti 03; `testLossyRoundTripAcrossReloadCharacterization`; `ConductorModel` 19/77–84/142–149/312–327 | avoin tilaraja/tuotepäätös; ei prosessin tappokoetta |

Molempien testien PASS tarkoittaa nykykäyttäytymisen onnistunutta reproduktiota,
ei sitä, että havaittu käyttäytyminen olisi korjattu. Tarkat toistoaskeleet,
vaikutus ja paikalliset korjausehdotukset ovat `03-METRONOME.md`-raportissa.

Mahdolliset laiteongelmat (jitter, buffer-underrun, Bluetooth ja kahden enginen
samanaikaisuus) ovat vielä todentamatta. Niitä ei luokitella tässä varmistetuiksi
virheiksi eikä niiden puuttumista väitetä todistetuksi.

## Vaihe 3 — piano ja ääni

| ID | Vakavuus | Varmuus | Löydös | Todiste | Tila |
| --- | --- | --- | --- | --- | --- |
| AUD-001 | MEDIUM | varmistettu tuotannon ReferenceTone-luokalla ja offline-enginellä | Jonotettu peruttu Play käynnistää tarkan äänen immediate Stopin jälkeen; SoundFontissa configure palauttaa piiloon jääneen sävelen | Raportti 04; `ReferenceTone.swift` 63–94/100–123; `reference-cancel.json` | avoin; ei UI-/fyysistä toistoa, ei korjausta auditissa |
| AUD-002 | LOW / IMPROVEMENT | PCM-askel varmistettu; kuultava vaikutus mahdollinen | Pianon volume vaihtuu suoraan puskurirajalla ilman ramppia | Raportti 04; `AudioRenderer.swift` 47–50/83/150–156; `dsp-summary.json` | avoin äänenlaadun parannus; ei kuuntelutodistetta |

Pianon mitattua spektrihuippujen vaihtelua ei kirjattu erilliseksi kaavavirheeksi:
monikomponenttisen näyteäänen ja tarkkaan taajuuteen tuotetun vertailuäänen
tarkkuus on erotettava. Raportti 04 sisältää lukemat ja mittarin rajoitukset.

## Vaihe 4 — viritysjärjestelmät

| ID | Vakavuus | Varmuus | Löydös | Todiste | Tila |
| --- | --- | --- | --- | --- | --- |
| TUN-001 | IMPROVEMENT | varmistettu tuotannon `NoteNaming`-funktiolla | Suomen historialliset nimet käyttävät merkkejä E♭/F♯, tasavire ja pohjasävelvalitsin nimiä Es/Fis. Sävelkorkeus ei muutu. | Raportti 05; `NoteNaming.swift` 5 ja 17–32; `ContentView.swift` 196–197; `compare.py` | avoin kirjoitusasu; ei korjausta auditissa |

Seitsemän viritysjärjestelmän intervallit, A4-ankkuri, oktaavit, susikvintit ja virittimen tarkka kohdehaku täsmäsivät riippumattomaan malliin. Niistä ei jäänyt avointa laskentavirhettä. SoundFontin `Float`-muunnos oli enintään 0,000030 senttiä laskettuna, ei samplerista äänitettynä.
