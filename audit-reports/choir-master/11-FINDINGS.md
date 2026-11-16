# 11 — Löydösrekisteri (osittainen)

Päivitetty: 2026-11-17. Kattaa vain valmiit vaiheet 1–2. Tämä ei ole koko
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
