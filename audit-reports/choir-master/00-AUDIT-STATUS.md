# 00 — Auditoinnin tila

Päivitetty: 2026-11-17. Tuote: **Choir Master**.
Bundle ID `com.atte.tenkanen.ChoirConductor` säilyy ennallaan.

Käyttäjän luvalla `choir-conductor/`-hakemiston kaksi raporttipohjaa kopioitiin
16.–17.11. `choir-master/`-hakemistoon. Alkuperäisiä ei muutettu. Tämä hakemisto
on jatkoauditoinnin voimassa oleva raporttipuu. Muissa hakemistoissa olevia
vanhoja havaintoja ei otettu todisteiksi tarkistamatta koodia tai ajamatta testiä.

Ennen metronomivaihetta tehtiin erillisellä korjauspyynnöllä F-001/F-002/F-003/
F-004/F-006/F-010-muutokset ja ajettiin 30 XCTest-testiä. Metronomivaihe tarkasti
korjatun, committoimattoman työpuun. Sen aikana ei muutettu tuotantokoodia,
projektia, alkuperäistä testikohdetta eikä tehty commitia. SHA-256-lähtötila ja
mittaukset on tallennettu evidenssiin; repon tiedostojen sisältövertailu
metronomivaiheen alusta loppuun ei löytänyt muutoksia.

| Vaihe | Raportti | Tila | Todennettu kattavuus |
| --- | --- | --- | --- |
| 1 Kokonaiskartoitus | `01-PROJECT-INVENTORY.md` | valmis, olennaiset viitteet päivitetty | 25 Swift-tiedostoa; oikea projekti/scheme, iOS 17.0, 30 tuotanto-XCTest-metodia; ei koko sovelluksen toimivuustodistus |
| 2 Metronomi | `03-METRONOME.md` | valmis rajauksin | Koodi ja riippuvuudet, 211 tempoa, 7 × 10 min offline, 1–16 aksentit, 44,1/48 kHz engine, 97 pianoääntä, mailbox-kilpailu, 4 erillistä audit-XCTest-metodia |
| 3 Piano ja ääni | `04-PIANO-AND-AUDIO.md` | valmis rajauksin | 25 WAV:ia, 291 pianoääntä, 291 oskillaattoriääntä, precise/SoundFont, Task-peruutus, kaksi tilapäistä XCTestiä; AUD-001/002 |
| 4 Viritysjärjestelmät | `05-TUNING-SYSTEMS.md` | valmis rajauksin | 7 järjestelmää, 12 pohjasäveltä, A4-ankkuri, oktaavit, susikvintit, nimitaulut, virittimen tarkka kohde; ei DAC- eikä sampleriääntä |
| 5 Äänitys | `06-RECORDING.md` | **seuraava, ei aloitettu** | — |
| 6 Elinkaari | `07-IOS-LIFECYCLE.md` | ei aloitettu | Metronomin session-rajapinnat luettu; laitekokeet avoinna |
| 7 Käyttöliittymä | `08-USER-INTERFACE.md` | ei aloitettu | Metronomikomentojen polut luettu, ei UI-ajoa |
| 8 Arkkitehtuuri | `02-ARCHITECTURE.md` | ei aloitettu | Vaiheen 1 kuva on alustava |
| 9 Tietosuoja | `09-SECURITY-AND-PRIVACY.md` | ei aloitettu | Mainoksia/lupatekstejä ei muutettu eikä lomaketta testattu |
| 10 Testikokonaisuus | `10-TEST-RESULTS.md` | ei kokonaisuutena aloitettu | Tähän mennessä ajettujen metronomitestien tulokset raportissa 03 ja evidenssissä |
| 11 Löydösrekisteri | `11-FINDINGS.md` | osittainen, päivittyvä | MET-001/002, AUD-001/002 ja TUN-001; äänitys ja myöhemmät vaiheet avoinna |
| 12 Korjaussuunnitelma | `12-REMEDIATION-PLAN.md` | ei aloitettu | Metronomin paikalliset ehdotukset raportissa 03; ei toteutusta |
| 13 Kattavuus | `13-COVERAGE.md` | osittainen, päivitetty vaiheeseen 4 | Mitatut, vain luetut ja kokonaan avoimet osa-alueet eroteltu |
| 14 Loppupäätös | `14-FINAL-ASSESSMENT.md` | ei aloitettu | Ei koko sovelluksen julkaisuvalmiuspäätöstä |

## Tämän vaiheen löydökset

- **MET-001, MEDIUM, varmistettu:** 6/8:n rajanuolen näkyvästi muuttumaton painallus
  tyhjentää palautustempon. 96 → 240 → plus → 240 → paluu 80;
  80 → 30 → miinus → 30 → paluu 90. Tuotantokoodia ei korjattu auditissa.
- **MET-002, LOW, varmistettu tilaraja:** palautustempo ei säily uuden mallin
  alustuksessa tallennetusta tilasta. 96 → 240 → uusi malli → paluu 80.
  Oikeaa prosessia ei tapettu. Alkuperäisen tempon säilyminen käynnistysten yli
  vaatii tuotepäätöksen; saman käyttöjakson korjaus läpäisee muuten 422 tapausta.
- Näytekellon tai aksenttien virhettä ei osoitettu tehdyillä offline-testeillä.
  Tämä ei todista fyysisen laitteen jitteriä, viivettä tai audiodeadlineja.

## Jatka tästä

Lue ensin tämä tiedosto, `05-TUNING-SYSTEMS.md`, `11-FINDINGS.md` ja
`13-COVERAGE.md`. Aloita vaihe 5 raporttiin `06-RECORDING.md`.
Tuotantokoodia ei muuteta auditointipyynnöllä.
Älä yhdistä engineitä, muuta mainoksia tai nimeä/bundle ID:tä. Älä poista
juuren kopioita tai tyhjää vanhaa projektihakemistoa. Älä tee commitia.

Laitetodentaminen on edelleen avoin. Fyysistä iPhonea ei käytetty.

## Vaiheen 3 päivitys 17.11.2026

Käyttäjän pyytämä commit/push tehtiin metronomivaiheen jälkeen: e523a5b,
tag v1.0.1-rc.2. Tämä pianoauditointi alkoi siitä puhtaasta lähdetilasta.
Raporttien Git-versio on nyt `Untitled Project/audit-reports/choir-master/`;
työtilan ulkopuolinen alkuperäinen raporttipuu pidetään peilikopiona.
Tuotantokoodia, projektia ja alkuperäisiä testejä ei muutettu pianoauditissa.

- **AUD-001, MEDIUM, varmistettu:** ennen käynnistymistä peruttu Play-Task voi
  aloittaa äänen immediate Stopin jälkeen. Precise jäi soimaan; SoundFontin
  piilossa oleva sävel palasi kuuluviin myöhemmästä configure-kutsusta.
- **AUD-002, LOW/IMPROVEMENT:** pianon volume vaihtuu ilman näyteramppia;
  PCM-epäjatkuvuus varmistettu, kuultavaa napsahdusta ei kuunneltu.
- Pianon sustainin spektrihuippujen vire vaihteli; tulokset on kirjattu
  luonnehdintana, ei temperamenttikaavan vikana.
- Kaikki testatut 291 pianoääntä soivat ja sammuivat. Suoran oskillaattorin
  291 taajuutta, normaalit precise-/SoundFont-ajot ja kaksi simulaattoritestiä
  läpäisivät. Tämä ei poista AUD-001:n erillistä peruutushaaran virhettä.

Seuraavana viritysjärjestelmät. Laitteen kuuntelu, oikea monikosketus ja
VoiceOver sekä CPU-/viive-/reittivaihtomittaukset ovat edelleen avoinna.

## Vaiheen 4 päivitys 17.11.2026

Viritysjärjestelmät tarkistettiin nykyisestä lähteestä ajamalla tuotannon
`Temperament`- ja `NoteNaming`-koodi sekä erillinen kvinttiympyrämalli.
Tuotantokoodia ei muutettu. Tulokset: `05-TUNING-SYSTEMS.md` ja
`evidence/tuning-2026-11-17/`.

- Laskentavirhettä ei löytynyt tasavireestä, valitusta 5-limit-luonnonvireestä,
  Pythagoralaisesta, ¼-komman keskisävelestä, Werckmeister III:sta,
  Kirnberger III:sta eikä Vallottista. A4 ja oktaavit pitävät.
- **TUN-001, IMPROVEMENT:** suomen historiallinen kirjoitusasu (E♭/F♯) eroaa
  tasavireen Es/Fis-nimistä. Sävelkorkeus ei muutu.
- SoundFont-sampleria ja iPhonen lähtöä ei äänitetty. `Float`-senttimuunnos
  laskettiin, suurin ero 0,000030 senttiä.

Seuraavana äänitys. Laitteen kuuntelu ja reittikokeet ovat edelleen avoinna.
