# 05 — Tietoturva ja suorituskyky

## Yksityisyys

Mikrofoni: käyttökuvaus on Info.plistissä ja jokaisessa `InfoPlist.strings`-tiedostossa. Lupa kysytään vasta ensimmäisestä äänityksestä tai mittarista. Kuvauksen kieli seuraa järjestelmää, ei sovelluksen kielivalintaa. Tämä on alustan rajoitus. Englannin ja suomen teksti nimeää sovelluksen Choir Masteriksi. 26 muussa kielessä sama dialogi alkaa `Choir Master:` ja jatkaa käännetyllä roolinimellä. Havainto F-011. Näyttönimen vaihtaminen ei muuta tallennussäiliötä.

Äänitteet ja analyysivälimuisti ovat sovelluksen Documents-kansiossa. Niitä ei lähetetä verkkoon `RecordingManager`- tai analyysikoodista. Tuonti lukee käyttäjän valitseman tiedoston security-scoped-oikeudella ja sulkee oikeuden `defer`-lohkossa.

Mainokset: `SettingsBanner` kutsuu suostumusta vain, kun `audioBusy` on epätosi. SDK mykistetään ja session hallinta jätetään sovellukselle (`AdsConsent.configureAudioPolicy`). XCTest `testAdsCannotManageSessionOrPlayAudio` tarkisti nämä kaksi lippua. Se ei avannut verkkoa eikä banneria.

`ConsentForm.loadAndPresentIfRequired(from: nil)` ja `presentPrivacyOptionsForm(from: nil)` (`SettingsBanner.swift` 19 ja 34). Nollaviittausta ei kokeiltu. On epäily, että lomake ei aina löydä näkymää. Havainto F-008. Virheet menevät `print`-lokiin, eivät käyttäjälle.

Seurantalupatekstiä (`NSUserTrackingUsageDescription`) ei ole projektissa. IDFA-kutsua ei löytynyt sovelluskoodista. App Storen tietosuojalomaketta ei voi vahvistaa tästä koodista. Havainto F-009.

Tuotannon mainosyksikkö on kovakoodattu `#else`-haaraan. Debug käyttää Googlen testitunnusta. Tunnukset ovat asiakasohjelmassa väistämättä luettavissa. Niitä ei toisteta tässä raportissa.

## Tiedostoturva

`RehearsalRecording.filename` on UUID ja allowlist-pääte (`m4a`, `wav`, `mp3`, `aiff`, `aif`, `caf`, `flac`, `aac`, `mp4`). Indeksi hylätään, jos nimi, kesto, päiväys tai pääte ei kelpaa tai tunnisteet toistuvat. Tallennus on atominen. Erillinen RecordingStore-testi: PASS, tiedostonimet eivät seuraa käyttäjän syötettä.

Tuonti tarkistaa `isValid` ennen kopiota, rajoittaa keston kahteen tuntiin ja julkaisee listan vasta indeksin kirjoituksen jälkeen. Epäonnistunut tallennus poistaa kopion. XCTest kattoi tämän.

`mp4` on sallittu. Jos `AVAudioFile` lukee videotiedoston ääniraidan, tiedosto hyväksytään. Tämä ei ole polkuhyökkäys. Se voi tuoda yllättävän suuren tiedoston. Ei erillistä havaintoa, koska dekooderin hylkäystä ei kokeiltu videotiedostolla.

## Istunto ja keskeytykset

Yksi koordinaattori omistaa kategorian. Äänityksen loppu palauttaa toiston, jos muita asiakkaita ei ole. Keskeytys tyhjentää asiakkaat ja vaatii uuden aloituksen. Pariton keskeytys ei jää pysyvästi estämään käyttäjän toistopyyntöä. Nämä ovat XCTestissä.

`allowBluetoothA2DP` ilman HFP:tä on koodissa ja testissä. Se ei todista, että fyysinen kuuloke pysyy A2DP-profiilissa. Laitetta ei ollut tässä ajossa.

## Suorituskyky

Hyvää:

- Audiokutsu ei odota käyttöliittymän lukkoa.
- Hiljaiset äänet ohitetaan aktiivisuuslistalla.
- Sävelkorkeustaulukko lasketaan vain viritysprofiilin muuttuessa, ei jokaisella äänenvoimakkuuden arvolla.
- Engine sammuu 300 ms hiljaisuuden jälkeen.
- Iskun ja äänityksen keston ajastimet käyvät vain tarvittaessa.
- Analyysi ja kirjaston luku ovat taustalla.
- Käännösmerkkijonot välimuistetaan (`TranslationCache`).

Jäljellä oleva kustannus:

- Kaikki pianonäytteet ja SoundFont ladataan käynnistyksessä pääsäikeen alustuksessa (`ChoirAudio.init`). Kestoa ei mitattu.
- `loadLibrary` voi avata jokaisen orvon äänitteen `AVAudioPlayer`illa.
- Analyysi lukee lähdetiedoston kahdesti ja dekoodaa sen kokonaan. Pitkä tuonti on raskas, mutta ei pääsäikeellä.
- 5 ms tavoitepuskuri (`setPreferredIOBufferDuration(0.005)`) pitää heräteviiveen pienenä ja CPU-kuorman korkeampana. Katkoksia ei mitattu.
- Viritin ja soittoengine voivat olla käynnissä yhtä aikaa. Kuormaa ei mitattu. F-007.

## Muisti

`nonisolated deinit {}` on tyhjä luokissa `AudioSessionCoordinator`, `ConductorModel`, `ChoirAudio`, `LiveTuner` ja `RecordingAnalysisModel`. Kommentti sanoo, että iOS 18.5:n isolated-deinit kaataa sisäkkäiset äänioliot. Vapautus tehdään `stop` / `stopAll` -kutsuilla. Jos olio vapautetaan ilman niitä, engine ja tap voivat jäädä. Nykyinen `ContentView` pitää mallin `@StateObject`ina koko ikkunan ajan, ja taustalle meno kutsuu `stopAll`. Käytännön vuotoa ei osoitettu. Tämä on tietoinen kiertotie, ei käyttäjälle näkyvä vika tässä rakenteessa.

## Riippuvuusriski

Google Mobile Ads 13.11.0 ja UMP 3.1.0 ovat ainoat verkkoriippuvuudet. Niiden haavoittuvuustietokantaa ei käyty läpi. Paketit on kiinnitetty `Package.resolved`-tiedostoon. Mainos-SDK on suuri hyökkäyspinta sovellukseen, joka muuten käsittelee äänen paikallisesti. Havainto F-009.
