# 08 — Korjaussuunnitelma

Järjestys on käyttäjälle näkyvä riski ensin. Lähdekoodia ei muutettu tämän suunnitelman kirjoittamisen yhteydessä.

## 1. F-001, 6/8-tempo

Valitsimen alla on jo kuvateksti (`ContentView.swift` 102–103): vaihto muuntaa BPM-luvun ja alue voi rajoittaa sitä. Täydennä sitä näyttämällä nykyinen ja tuleva BPM ennen vaihtoa. Jos tulos osuu rajaan 30 tai 240 eikä paluu palauta alkuperäistä, älä vaihda kysymättä. Vaihtoehto, joka säilyttää musiikillisen nopeuden paremmin, on pitää käyttäjän BPM ja vaihtaa vain iskun yksikköteksti, jos muunnosta ei voida tehdä tarkasti.

Testi: temput 80, 96 ja 100, molemmat suunnat, edestakainen vaihto. Odotus kirjoitetaan testiin eksplisiittisesti, ei vain onnistuneelle parille 60 ja 180.

## 2. F-002, mittarin tila

Tallenna `soundMode` ennen vertailuääntä. `silencePiano` mittarista palatessa palauttaa sen. Älä jätä päänäkymää viritysäänitilaan, ellei käyttäjä ole valinnut sitä päänäkymässä.

Testi: piano → `playTunerReference` → `silencePiano` → tila on piano.

## 3. Laitekoe, ennen TestFlightia

Tämä ei ole yhden funktion korjaus. `RELIABILITY.md` luettelee samat aukot. Minimi:

- metronomi ja äänitys yhdessä, reitin vaihto
- Bluetooth-kuuloke äänityksessä ja mittarissa: pysyykö toisto A2DP:nä ja sammuuko mikrofoni-indikaattori
- vertailuääni ja laulu yhtä aikaa, kuuloke ja kaiutin (F-007)
- Control Center ei sammuta metronomia; tausta, keskeytys ja kuulokkeen irrotus sammuttavat
- kahden tunnin raja ja tuonti Tiedostoista
- suostumuslomake näkyy (F-008)
- VoiceOver ja suuri teksti pienellä puhelimella

## 4. F-003, F-004, F-006, F-010

Pienet ja paikalliset. Yhdistä virheilmoitukset. Päivitä README hereilläpidosta. Anna `volume`-funktiolle käännösavain. Aseta projektin deployment target 17.0:ksi.

## 5. F-005, yksi puu

Pidä käännettävä projekti ja sen testit yhdessä paikassa. Merkitse juuren kopiot tai poista ne, jotta lokalisaatioskriptiä ei ajeta väärästä puusta. Juuren skripti läpäisi nyt, koska se osoittaa `Untitled Project/Choir Master` -kansioon, mutta Python-työkalut eroavat.

## 6. F-008 ja F-009, mainokset

Välitä näkyvä view controller. Älä niele suostumusvirhettä pelkkään lokiin. Tee Release-arkiston privacy report ja päätä ATT ennen lähetystä. SDK on jo mykistetty ja sidottu siihen, ettei se omista sessiota. Älä lataa banneria äänen soidessa. Tämä sääntö on jo koodissa (`audioBusy`).

## 7. Mitä ei tarvitse tehdä uudelleen

Älä rakenna istunnon omistusta, temperointimittaria, A2DP-lippua, sointujen vioittumissuojaa tai näytepostilaatikkoa alusta. Ne ovat olemassa ja niillä on läpäisseet testit. Uusi työ on reunatapaukset ja laite.

Älä muuta bundle ID:tä `com.atte.tenkanen.ChoirConductor`, testitunnistetta, UserDefaults-avaimia äläkä `Documents/Recordings`-polkua nimen yhdenmukaistamiseksi. Choir Masterin näyttönimi on jo kohdallaan. F-011 on vain lupatekstien siistiminen. F-012:n tyhjä `Choir Conductor.xcodeproj` on kehityskoneen kansio, ei asennettu nimi.

## Tarkistus korjausten jälkeen

1. `xcodebuild` samaan iOS 18.5 -simulaattoriin, 24 nykyistä testiä plus F-001 ja F-002.
2. Lokalisaatioskripti `Untitled Project` -puusta.
3. Erilliset temperamentti-, pitch-, render-, chord- ja recording-store-tarkistukset.
4. Yksi fyysisen puhelimen lista kohdasta 3, kirjattuna `RELIABILITY.md`-tiedostoon vasta kun se on tehty.
