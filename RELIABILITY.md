# Choir Master: reliability changes, 2026-10-11

## Implemented

- Local Git baseline `6ea15b7` preserves the app, renamed project and bundled sounds before these changes.
- Chord reads preserve corrupt data and a recovery copy in `savedChords.v1.unreadableBackup`. Saves refuse to replace an unreadable store. Restoring a validated payload is required before saving again.
- Recording renames persist the proposed list before publishing the new name. Stale recorder/player delegate callbacks are ignored. A failed recording start cleans its incomplete file and releases its session claim.
- AudioSessionCoordinator owns the session for sound, recording and recorded playback. Starting another key does not reactivate an existing session. Stopping recording restores playback routing; stopping one client keeps the session active for remaining clients. A real interruption stops everything and requires explicit restart.
- Temporary inactive scenes no longer stop practice. Background scenes still stop all audio. Recording and continuous reference tone prevent automatic screen lock, as does the metronome.
- Piano and reference DSP state belongs to their audio callbacks. A short control mailbox uses try-lock on the callback: if publication is busy, the callback renders its previous state without waiting or inserting silence. Pitch tables are computed before publication. No UI callbacks execute while the mailbox is locked.
- Beat polling starts only for a running metronome and only publishes changed values. Recording elapsed-time polling starts only while recording. Engine/session release waits 300 ms after the last live sound, allowing release envelopes to finish; new sound cancels that release.
- Chord playback prepares the audio engine before changing the stored profile, then commits the profile together.
- Shared note spelling follows the transposed open fifth chain for Pythagorean and quarter-comma tuning and the chosen scale intervals for just intonation; the keyboard and chord labels use the same labels.
- Missing or invalid SoundFont does not prevent piano/metronome/precise reference playback. The settings fall back to the precise tone with an error message when the unavailable font is selected.
- Keyboard geometry/accessibility elements are rebuilt only when necessary. VoiceOver activation plays a short note, with sustain/reference behavior preserved. The 24-note black halves are at least 44 points wide; the keyboard scrolls to cover the larger range. Deliberate swipe threshold is 24 points. VoiceOver horizontal scrolling is supported.
- Sample fundamentals moved unchanged from the existing measurement CSV into bundled metadata. Format, frame count and loop bounds are validated before playback. Existing loop points and timbre are retained. Safe loop wrapping supports large playback steps.
- Two identified Arabic terminology errors were corrected. Other translations remain drafts requiring human musical-language review.
- App minimum iOS is explicitly 17.0, the same value previously resolved by the SDK setting. The app is now named Choir Master. Its bundle identifier is `com.atte.tenkanen.ChoirConductor`, matching the existing App Store Connect record, with test ID `com.atte.tenkanen.ChoirConductor.Tests`. Development team and automatic signing remain unchanged.

## Verification

The shared Xcode scheme contains a hosted XCTest target. Tests cover session policy transitions, repeated activation, failed activation, interruption, corrupt chord preservation, stale recorder callback, transposed spelling, concurrent control updates, chord release, packaged sample format and missing SoundFont fallback. Use Cmd–U in Xcode. All 12 tests passed on the iPhone 11 Pro Max simulator running iOS 26.5. The Finnish portrait main screen was also inspected from a simulator screenshot.

Additional existing standalone checks exercise sample-clock metronome timing, all 97 notes, bounded output, release tails, chord persistence, reference-tone sustain/stop and localization key/format coverage. Their sources remain in the workspace-level `Tests` directory. These checks passed. The spectral check measured precise reference tones at their expected frequencies for the tested A4 values, quarter tone and E4 temperament cases; piano A4/quarter tone retained approximately −1.9/+2.0 cent differences, as before. No full-range pitch sweep was repeated in this change.

## Device validation still required

1. Start metronome and a held chord, start/stop microphone recording, and verify neither activity is lost during session format changes.
2. Repeat with Bluetooth headphones and wired/USB audio. Verify output routing and sound quality return after recording, and confirm the microphone indicator turns off.
3. Open/close Control Center and Notification Center. Verify temporary inactive scenes preserve playback; backgrounding, interruptions and headphone removal stop audio and leave no stuck notes.
4. Record without metronome and play a reference tone without metronome. Verify automatic screen lock remains disabled, then returns when the activity ends. Manual lock still stops audio by design.
5. Play chords with real multitouch; test sustain toggling, deliberate keyboard swipes and 24-note halves on a small iPhone.
6. Test VoiceOver activation and scrolling, larger text, landscape, long translations and RTL layouts.
7. Listen to C2–C6, especially C2–F3. Current samples span G3–G5; lower notes still use substantial downward transposition. Bass timbre needs listening and potentially additional original bass samples, not an unverified pitch-shift replacement.

No claim is made of real microphone, Bluetooth, speaker listening, device pitch, VoiceOver user testing or physical multitouch verification. Background recording has not been added. Full translation review and per-sample loop optimization remain follow-up work.

## Android planning and analysis experiment, 2026-10-16

The current iOS working tree is preserved by commit `a45c5b7`. Android
requirements and architecture are in `SPEC.md` and `ARCHITECTURE.md`;
`ANDROID_STATUS.md` distinguishes completed checks from remaining work.
`AnalysisLab/README.md` documents the synthetic pitch-drift experiment.
The older statement about no external runtime dependencies does not cover
the subsequently added Google Mobile Ads / UMP integration. No iOS runtime
source was changed for this Android preparation.

## Katselmuskorjaukset 15.11.2026

- Viritysmittari etsii lähimmän sävelen valitun viritysjärjestelmän, pohjasävelen,
  A4:n ja 12/24-jaon todellisista tavoitetaajuuksista. Nimistö vastaa koskettimistoa.
  24-jaossa asteikon näyttö on ±25 senttiä. Mittarissa voi kytkeä erikseen
  valittavan vertailuäänen; kuulokeohje kertoo kaiutinäänen vaikutuksesta mittaukseen.
- Mikrofonin tap kopioi vain rajattuun puskuriin odottamatta lukkoa. Suodatus ja
  YIN toimivat sarjallisessa taustotyössä. Windowed-sinc-alipäästö ehkäisee
  laskostumista ennen harvennusta. Ylikuormassa vanha aineisto pudotetaan ja
  analyysi alustetaan uudelleen; työjono ei kasva rajattomasti.
- Tallenneanalyysin v2 aloittaa pitkän tauon jälkeisen jakson omasta havainnosta.
  Vanha 12 sentin jatkuvuusrajoitus ei sido sitä edelliseen jaksoon. Versionvaihto
  mitätöi aiemmat välimuistit. Päällekkäisten analyysipyyntöjen valmistuminen ei
  ylikirjoita uudemman pyynnön tilaa.
- Analyysin ohje kertoo erikseen kaikkien äänten yhdistymisestä, stemmojen erottelun
  puuttumisesta sekä 100 sentin taiton ja tasoituksen vaikutuksesta. Menetelmä on
  edelleen yhteisen säveltason kokeellinen arvio, eikä luonnonvireisen soinnun
  puhtauden mittari. Stemmojen erottelua ei lisätty.
- Äänitys ja viritin sallivat Bluetooth A2DP -toiston ilman HFP-puheluprofiilia.
  Bluetooth-kuulokkeen mikrofonia ei käytetä; sisäinen tai langallinen mikrofoni
  toimii tulona. Viritin voi jakaa session vertailuäänen kanssa, mutta ei
  mikrofonitallennuksen tai tallenteen kuuntelun kanssa.
- Myös pianon pidetty sointu pitää näytön hereillä. Soiton käynnistysvirhe pysäyttää
  vain harjoitteluäänen ja jättää äänityksen toimimaan. Manuaalinen lukitus ja
  taustalle siirtyminen pysäyttävät toiminnan edelleen.
- Mainoksia ja suostumuksen valmistelua lykätään session vapautumiseen asti.
  Mainos-SDK on mykistetty, eikä se saa hallita AVAudioSessionia. Käyttöliittymä ja
  README kertovat verkkoyhteydestä. Mainoksia ei poistettu sovelluksesta.
- Äänenvoimakkuuksien tallennus odottaa 300 ms muutosten tasaantumista ja tehdään
  heti taustalle siirryttäessä. Käännösformaatit ja kielipaketit välimuistitetaan.
  Mainosten tietosuoja-avain lisättiin käännösten lähdeaineistoon; uusien
  suomi/englanti-taulujen avaimet ja muotoilupaikat tarkistetaan testeissä.
- Tallenneluettelon luku ja tiedostojen palautus tehdään taustalla. Äänitys on
  estetty latauksen ajan. Tunnettujen tiedostojen tarkistus käyttää joukkoa.
  Yhden tallenteen enimmäiskesto on kaksi tuntia, minkä jälkeen tiedosto viimeistellään.
- Renderöinti käy näytekohtaisesti läpi vain aktiiviset ja vaimenevat äänet;
  lähdenäytteiden indeksit on esilaskettu. Pianonäytteiden ja SoundFontin alkuperäinen
  esilataus on edelleen synkroninen. Nopeutuksen määrää ei ole profiloitu laitteella.
- 6/8-iskutavan vaihto muuntaa BPM:n kolminkertaiseksi tai kolmasosaan, jotta
  tahdin kesto säilyy mahdollisuuksien mukaan. 30–240 BPM -raja ja kokonaisluvuksi
  pyöristys voivat rajoittaa muunnosta; käyttöliittymä kertoo rajoituksesta.
  Historiallisten viritysten kosketin- ja susikvinttiohje käyttää nykyisiä sävelnimiä.
- Uusi mallin elinkaaritesti paljasti iOS 18.5:n Swift isolated-deinit
  -yhteensopivuuspolun kaatumisen sisäkkäisissä ääniolioissa. Eksplisiittiset
  nonisolated-deinitit välttävät saman polun kuin AudioSessionCoordinatorissa.

Tarkistukset: Xcoden testiajo iPhone 16 Pro / iOS 18.5 -simulaattorissa läpäisi
kaikki 17 XCTest-testiä. Erilliset virittimen, renderöinnin, tallenneanalyysin,
viritysjärjestelmien ja tallennemetadatan testit läpäisivät. Virittimen testit
kattavat kaikki viritysjärjestelmät ja pohjasävelet, neljäsosasävelen sekä
korkean taajuuden häiriön suodatuksen 44,1/48/96 kHz:n syötteillä. Käännöstarkistus
läpäisi 31 kieltä sekä suomen/englannin lisätaulut. Paikallisella Android-verrokkijarilla
ajettu 65 pisteen vertailu läpäisi: ero oli alle 0,000001 senttiä ennen jakson
uudelleenalustusta; tauon jälkeinen uusi iOS-tulos tarkistettiin testiaineiston
48 sentin tasoa vasten. Androidin lähdekoodia ei muutettu.

Fyysisellä iPhonella on vielä tarkistettava Bluetooth-reititys, samanaikainen
vertailuääni ja mikrofonimittaus, mainosten elinkaari, kahden tunnin tallennusraja
sekä virittimen kuorma ja viive. Käyttöliittymän uutta asettelua ei tarkistettu
visuaalisesti. Todellisen kuoron analyysitarkkuutta ei ole validoitu.

## Julkaisuehdokkaan tarkistus 16.11.2026

Version 1.0.1 (build 2) iPhone/arm64 Release -arkistointi läpäisi ilman
allekirjoitusta. Tämä varmistaa Release-käännöksen ja arkiston muodostamisen,
ei jakeluvarmennetta, provisioning-profiilia tai App Store Connectin validointia.
17 XCTest-testiä läpäisi edellisessä simulaattoriajossa. App Store Connectin
nykyistä build-numeroa ei ole tarkistettu. Ennen uutta lähetystä build-numeron
on oltava palvelussa käyttämätön.

Tests-, Tools- ja README-aineistot on kopioitu aiemmasta Git-repon ulkopuolisesta
työtilajuuresta tähän repoon. Kopioiden polut on sovitettu repon juureen;
alkuperäiset työtilan tiedostot on säilytetty. Lokalisaatiotarkistus läpäisi myös
repon sisältä ajettuna. Tag v1.0.1-rc.1 merkitsee julkaisuehdokasta.

Suositus: seuraavaksi allekirjoitettu arkisto ja TestFlight fyysiselle iPhonelle.
Julkista App Store -julkaisua ennen tarvitaan edellä luetellut mikrofonin,
Bluetoothin, vertailuäänen, mainosten ja käyttöliittymän laitetarkistukset.
