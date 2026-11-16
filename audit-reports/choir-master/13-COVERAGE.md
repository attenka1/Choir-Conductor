# 13 — Tarkastuksen kattavuus (osittainen)

Päivitetty: 2026-11-17. Voimassa oleva lähde on `Untitled Project/`.
Auditoinnin jatkoraportit ovat tässä `choir-master/`-hakemistossa.

| Osa-alue | Rivi-/polkutarkastus | Ajotodiste | Avoin |
| --- | --- | --- | --- |
| Metronomin DSP ja näytekello | valmis; `AudioRenderer.configure`, `consumeControls`, `render`, start/reset/clear | 211 BPM, 7 × 600 s, eri puskurit, 1–16 PCM-aksentit, start/stop/mute/tempo | Fyysinen jitter/drift/deadline ja absoluuttinen viive |
| 6/8 ja BPM-asetukset | valmis; `ConductorModel`, UI-valitsimet ja UserDefaults-polku | 422 saman mallin edestakaista tapausta; rajat, uusi tempo, rajanuolen ja uuden mallin luonnehdinnat | Prosessin todellinen uudelleenkäynnistys; MET-001/002 avoinna |
| Tahtilajin numerot ja iskuarvo | valmis polkutarkastus; `MeterSelectionView` ja `beatUnit` | 160 numero/nimittäjä/iskutapa-yhdistelmää | UI:n visuaalinen ja saavutettavuuden testaus |
| Näytetaajuusmuunnos metronomille | lähdenoden 44,1 kHz -kytkentä luettu | Oikea offline-AVAudioEngine, 44,1/48 kHz ulostulo, 137 BPM / 60 s | Muut taajuudet, Bluetooth/USB, fyysinen ulostulo |
| Julkaisun lukituskilpailu | try-lock-koodi luettu | 1 000 000 saman tilan päivitystä ja 60 s PCM-vertailu | Vaihtuvien komentojen maksimiviive; realtime-profilointi |
| Piano ja metronomi yhdessä | vain metronomin ajoituksen osalta | 97 oikeista näytteistä soitettua ääntä + 30/240 BPM, 12 s molemmat | Pianon silmukat, kosketusten elinkaari, äänenlaatu ja realtime-kuorma kokonaisuutena vaiheessa 3 |
| Piano, oskillaattori ja SoundFont | alustava kartoitus, ei täydellistä auditointia | Olemassa oleva renderer-tarkistus ajettu riippuvuutena; ei vaiheen 3 kattavuutta | Vaihe 3 seuraavana |
| Temperamentit ja sävelnimet | vain vaiheen 1 kartoitus | Ei tässä vaiheessa uusia testejä | Vaihe 4 |
| Äänitys, tuonti, analyysi ja toisto | vain vaiheen 1 kartoitus ja metronomin rajapinnat | Ei tässä vaiheessa uusia tallennuskokeita | Vaihe 5 |
| iOS session/elinkaari | metronomin käyttämät metodit luettu | Malli- ja engine-offlinekokeet, ei laitetapahtumia | Vaihe 6; puhelu, route, inactive/background, mic-indikaattori |
| UI, VoiceOver, Dynamic Type, lokalisoinnin laatu | metronomin komennot luettu | Ei UI-ajoa | Vaihe 7 |
| Arkkitehtuuri ja tietosuoja/mainokset | kartoitus vain; ei SDK-auditointia | Ei mainos-/suostumus-/verkkokokeita | Vaiheet 8–9 |

## Ajot ja rajaukset

Metronomiauditissa: neljä tilapäisen projektikopion XCTest-metodia,
uusi PCM-kelloharness, uusi engine-harness, rinnakkaisjulkaisuharness,
maksimipianosekoitusharness ja nykyinen `Tests/AudioRenderChecks`.
Tarkat tulokset ja komennot raportissa 03 ja sen evidenssissä.

Ennen tätä vaihetta tehdyssä rajatussa korjausajossa 30 alkuperäisen
`ChoirMasterTests`-kohteen testiä ja lokalisaatiotarkistus läpäisivät.
Niitä ei nimetty uudeksi koko sovelluksen auditointiajaksi. Metronomivaiheen
lisätestit eivät muuttaneet sovelluksen testikohdetta.

Ei ajettu fyysistä puhelinta, 70 minuutin realtime-koetta, oikeaa mikrofonia,
Bluetoothia/USB:tä, puhelua/Siriä, VoiceOveria, TestFlightia tai App Store -validointia.
Metronomivaiheen macOS sandboxissa epäonnistunut engine-komponentin luonti
uusittiin onnistuneesti samalla binaarilla järjestelmän komponenttipääsyllä.

## Muutosten hallinta

Auditin alun ja lopun tiedostokohtainen SHA-256-vertailu vahvisti, ettei
`Untitled Project/`-puun tiedostojen sisältö muuttunut auditin aikana.
Tuotannossa olevat committoimattomat korjaukset edeltävät tätä auditointivaihetta.
Alkuperäiset `audit-reports/choir-conductor/`-pohjat ja juuren kopiot säilyivät.
