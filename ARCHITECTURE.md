# Android-arkkitehtuuri

Päätös hyväksytty keskustelussa 16.10.2026. Ei vielä väite toteutuksesta.

## Rakenne

Kotlin + Compose, yksi sovellusmoduuli aluksi. Pakettirajat:
- ui: näkymät ja ViewModelit, yksisuuntainen näkymätila;
- music: puhtaat viritys-, nimistö- ja sointulaskennat;
- audio: alustariippuvainen elinkaari, focus, reitit, tallennus/toisto;
- storage: asetukset, validoitu ja versioitu sointu-/tallenneindeksi;
- analysis: alustasta riippumaton jälkianalyysi ja tulosformaatti.

Audio-ohjain on ainoa yhteisten ääniresurssien omistaja. Soitto,
mikrofonitallennus ja tallenteen kuuntelu ovat erillisiä tarpeita.
Tallenteen kuuntelu pysäyttää harjoitusäänen; äänitys voi toimia sen rinnalla.
Keskeytys ja todellinen tausta pysäyttävät; orientaatiomuutos ei.

Ääniulostulo: pieni C++-ydin + Oboe rajatun JNI-rajapinnan takana. Metronomi,
piano ja oskillaattori sekoitetaan saman renderöintikellon avulla. Todellinen
näytetaajuus on parametri; iOS:n 44100-lukuja ei kopioida laitekelloksi.
Esiladataan näytteet; callback ei tee tiedosto-I/O:ta, muistivarausta,
UI-kutsuja eikä odota lukkoa. Komennot julkaistaan rajatusti, ei rajattomaksi
kasvavaan tapahtumajonoon. Sointu ja sen viritysprofiili julkaistaan yhdessä.
Oboe perustellaan kosketinsoiton viiveellä; lisenssi ja versio kirjataan.
SoundFont-soitin on avoin päätös, ei syy estää tarkkaa viritysääntä.

## USB-tallennus

AudioRecord omistaa yhden mikrofonivirran. AudioManagerin laitelistaa ja
reittimuutoksia tarkkaillaan; käytetään Androidin USB-audioajuria, ei
omaa USB-protokollaa. setPreferredDevice on pyyntö; todellinen reitti
varmistetaan getRoutedDevice-kyselyllä käynnissä olevasta virrasta.

Tilat: Idle → Preparing → VerifyingRoute → Recording → Finalizing → Idle;
virheestä Finalizing, jos hyväksyttyä PCM-dataa on syntynyt. Vanhentunut
callback ei saa muuttaa uuden session tilaa. USB-vaatimus on eksplisiittinen:
väärä reitti ei muutu hiljaiseksi sisäisen mikrofonin varajärjestelmäksi.

Capture-työntekijä kirjoittaa PCM:n rajatuissa lohkoissa. Dataflush ja
WAV-otsakkeen viimeistely tapahtuvat hallitusti. Äkillisen prosessikuoleman
jälkeen palautetaan keskeneräinen tiedosto täydellisistä kehyksistä.
Hidas tallennus/ylivuoto raportoidaan, näytteitä ei pudoteta huomaamatta.
USB-irrotus ei saa odottaa ikuisesti blokkautunutta lukua.

## Analyysi

Ensimmäinen toteutus on tutkimuskoe AnalysisLab-hakemistossa. NumPy on vain
kehitysympäristön riippuvuus, ei Android-kirjasto. Julkaistavan ytimen kieli
ja FFT-kirjasto lukitaan vasta kun menetelmä läpäisee validoinnin.

Putki: PCM/kanavat → ikkunoitu spektri → harmoniset havainnot → ympyräjakauma
(periodi 100 c) → robusti ajallinen seuranta → segmentit/epävarmuus → käyrä.
Analyysi on keskeytettävä, deterministinen eikä muuta alkuperäistä ääntä.
Tulos sisältää menetelmäversion, parametrit, lähdeäänitteen tunnisteen ja
formaatin sekä pisteen ajan, segmentin, nullable driftCentsin ja laatupisteen.
Laatupiste ei ole kalibroitu todennäköisyys. Välimuisti mitätöidään version,
parametrien tai lähdeaineiston muuttuessa. Tulos tallennetaan atomisesti.

Kokeessa verrataan yksinkertaista spektrihuippumenetelmää harmoniseen
suodatukseen. Jatkuvuus ei korvaa heikkoa havaintoa. Pitkä tauko nollaa
segmentin. Historialliset/luonnonvireiset soinnut kuuluvat vastatesteihin.
Stereo analysoidaan kanavittain tai valitsemalla luotettavampi kanava;
±vaiheisten kanavien summausta ei käytetä oletuksena.

## Toteutusjärjestys

0: lähtöpiste ja dokumentit. 1: analyysikoe ja mitattu raportti.
2: Androidin audiorunko. 3: musiikkiominaisuudet. 4: tallennuskirjasto.
5: validoidun analyysin käyttöliittymä. 6: SoundFont/kielet/mainokset/julkaisu.
Vaiheen 1 todellisen kuoroaineiston puute ei oikeuta väittämään analyysiä
validoiduksi tai liittämään sitä luotettavana tuotanto-ominaisuutena.

## Lähteet

- https://developer.android.com/games/sdk/oboe/low-latency-audio
- https://developer.android.com/reference/android/media/AudioRecord
- https://developer.android.com/reference/android/media/AudioRouting
- https://developer.android.com/reference/android/media/MediaRecorder.AudioSource
