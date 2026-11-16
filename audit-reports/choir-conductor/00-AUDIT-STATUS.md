# 00 — Auditoinnin tila

Päiväys: 2026-11-16. Tuote tässä raportissa: **Choir Master**. Käyttäjän tehtävän otsikko käyttää vanhaa nimeä Choir Conductor. Asennettava nimi, target, scheme ja tuote ovat Choir Master. Bundle ID `com.atte.tenkanen.ChoirConductor` jätetään ennalleen. Sitä ei käsitellä näyttönimenä.

Lähdekoodia ei ole muutettu. Testejä ei ole ajettu tässä auditoinnissa. Aiemman audit-hakemiston tuloksia ei käytetä todisteena.

Vaihe on valmis vasta, kun sen kattavuus ja raja on kirjoitettu tähän tiedostoon. Tiedostoja 02–14 ei ole luotu, koska niitä vastaavia vaiheita ei ole tehty.

| Vaihe | Tiedosto | Tila | Kattavuus |
| --- | --- | --- | --- |
| 1 Kokonaiskartoitus | `01-PROJECT-INVENTORY.md` | valmis | Koodipuu, kytketyt ominaisuudet, luokat A–E. Ei ajoa, ei musiikillista mittausta. |
| 2 Metronomi | `03-METRONOME.md` | ei aloitettu | — |
| 3 Piano ja ääni | `04-PIANO-AND-AUDIO.md` | ei aloitettu | — |
| 4 Viritysjärjestelmät | `05-TUNING-SYSTEMS.md` | ei aloitettu | — |
| 5 Äänitys | `06-RECORDING.md` | ei aloitettu | — |
| 6 Elinkaari | `07-IOS-LIFECYCLE.md` | ei aloitettu | — |
| 7 Käyttöliittymä | `08-USER-INTERFACE.md` | ei aloitettu | — |
| 8 Arkkitehtuuri | `02-ARCHITECTURE.md` | ei aloitettu | Vaiheen 1 kuva on alustava, ei arkkitehtuurin arvio. |
| 9 Tietosuoja | `09-SECURITY-AND-PRIVACY.md` | ei aloitettu | — |
| 10 Testit | `10-TEST-RESULTS.md` | ei aloitettu | Testit on vain listattu. Niitä ei ole ajettu. |
| 11 Löydökset | `11-FINDINGS.md` | ei aloitettu | Vaihe 1 ei kirjaa vikoja. Luokitus ei ole löydös. |
| 12 Korjaussuunnitelma | `12-REMEDIATION-PLAN.md` | ei aloitettu | — |
| 13 Kattavuus | `13-COVERAGE.md` | ei aloitettu | Tämän vaiheen raja on alla. |
| 14 Loppupäätös | `14-FINAL-ASSESSMENT.md` | ei aloitettu | — |

## Vaiheen 1 raja

Luettu: Xcode-projekti, scheme, `Package.resolved`, kaikkien 25 sovellus-Swift-tiedoston rakenne ja julkiset kytkennät, testimetodien nimet, `SPEC.md` siltä osin kuin se erotetaan iOS-koodista. Avattu tarkemmin käynnistys, päänäkymän sheetit, metronomin näytekello, viritysten enum ja äänityksen aloitusasetukset.

Ei luettu rivi riviltä: FFT-analyysi, jokainen lokalisaatio, WAV- ja SF2-binäärit, Google-SDK:n lähde. Sovellusta ei käynnistetty. Simulaattoria ja iPhonea ei käytetty.

## Tarkennukset seuraaviin vaiheisiin

1. Metronomin ääni etenee `AudioRenderer.render`-näytekellossa. `Timer.publish` päivittää vain iskun numeron näytölle 30 kertaa sekunnissa. Vaiheen 2 mittari on renderöinnin näyteindeksi, ei SwiftUI-ajastin. Tempot 40, 60, 120, 180 ja 240 kuuluvat alueeseen 30–240. Laitteen jitter ja drift jäävät erilliseksi, kunnes iPhone on käytössä.
2. Virityksiä on seitsemän, ei vain tehtävässä nimetty neljä. 24-sävelinen tasavire on vain tasavireen lisätila. A4 415 Hz on esivalinta, ei erillinen barokkivireys. Luonnonvire on yksi valittu 5-limit-kromaattinen asteikko, ei yleinen luonnonvire.
3. `Untitled Project/SPEC.md` on Android-suunnitelma. USB-mikrofonin valintaa ja AKG Lyraa ei etsitä iOS-puutteena, ellei sama polku löydy iOS-koodista. Sitä ei löytynyt.
4. Juuren `Tests/`, `Tools/` ja `README.md` ovat kopioita. Voimassa oleva puu on `Untitled Project/`.
