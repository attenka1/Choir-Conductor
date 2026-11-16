# 02 — Arkkitehtuuri ja tietovirrat

## Kuva

```
ChoirMasterApp
  ContentView
    ConductorModel
      AudioSessionCoordinator  ---- AVAudioSession
      ChoirAudio
        AudioRenderer          ---- pianonäytteet + metronomi
        ReferenceTone
          ReferenceOscillator
          AVAudioUnitSampler   ---- SoundFont, valinnainen
      LiveTuner
        oma AVAudioEngine + tap
        TunerTap -> TunerInputProcessor -> PitchDetector
      RecordingManager
        AVAudioRecorder / AVAudioPlayer
        RecordingStore (index.json)
        tuonti: security-scoped kopio
    ChordLibraryView -> SavedChord / ChordStore
    TunerView
    RecordingView
      RecordingAnalysisView
        RecordingAnalysisStore -> RecordingPitchAnalysis
    SettingsBanner -> AdsConsent -> UMP + Google Mobile Ads
```

## Sessionin asiakkaat

`AudioSessionCoordinator.Client`: `sound`, `recording`, `playback`, `tuner`.

`begin` (`AudioSessionCoordinator.swift` rivit 36–55):

- Keskeytystila hylkää aloituksen, paitsi `userInitiated: true`, jota käyttää vain `RecordingManager.playRecording`.
- Viritin saa käynnistyä, jos muita asiakkaita ei ole tai ainoa muu on `sound`.
- `sound` saa liittyä virittimen rinnalle.
- Äänitys ja tallenteen toisto eivät saa käynnistyä virittimen aikana (`AudioSessionError.tunerBusy`).

`reconcile` (rivit 72–97): tyhjä asiakasjoukko deaktivoi session ja palauttaa kategorian `.playback` + `.mixWithOthers`. Mikrofoniasiakas vaihtaa kategorian `.playAndRecord` valinnoilla `.defaultToSpeaker`, `.allowBluetoothA2DP`, `.mixWithOthers`. `.allowBluetoothHFP` ei ole joukossa. XCTest `testTunerSharesOnlyReferenceOutputAndRestoresPlaybackCategory` vahvisti tämän simulaattorin tuplakohteella, ei fyysisellä Bluetooth-laitteella.

## Äänen ohjaus

Käyttöliittymä ei kirjoita rendererin äänitilaa suoraan. `AudioRenderer.configure`, `setMetronome`, `startNotes`, `releaseNote` ja `clear` lukitsevat postilaatikon. Audiokutsu tekee `lock.try()`. Jos lukko on varattu, edellinen tila soitetaan. Sama malli on `ReferenceOscillator.consumeControls`.

Iskun indeksi julkaistaan `displayedBeat`-kenttään. Ajastin 30 Hz lukee sen vain metronomin soidessa (`ConductorModel.updateBeatTracking`).

Engine pysäytetään `scheduleIdleStop`-tehtävällä 300 ms sen jälkeen, kun metronomi on pois ja `sounding` on tyhjä. Uusi ääni peruu tehtävän.

## Tietovirrat

| Tieto | Kirjoitus | Luku |
| --- | --- | --- |
| Tempo, tahtilaji, viritys, nimet, äänenvoimakkuus | UserDefaults. Äänenvoimakkuus viivästetään 300 ms (`scheduleSettingsSave`). Muut `save()` heti. Taustalle meno kutsuu `flushSettings` | `ConductorModel.init` |
| Soinnut | `ChordStore`, avain `savedChords.v1`. Rikkinäistä arvoa ei korvata; kopio avaimessa `.unreadableBackup` | sama |
| Äänitteet | `Documents/Recordings/<uuid>.<ext>` ja `index.json`, atominen kirjoitus | `loadLibrary` taustalla |
| Analyysi | `Recordings/Analysis/<uuid>.json`, kelpaa vain jos SHA-256, A4, formaatti ja versio täsmäävät | `RecordingAnalysisStore.resolve` |
| Kieli | UserDefaults `appLanguage` | `Localization.localizedText` |
| Mainokset | Verkko, vain asetuksissa ja kun `audioBusy == false` | `SettingsBanner` |

## Käyttäjälle näkyvät ominaisuudet ja koodipolku

| Ominaisuus | Polku |
| --- | --- |
| Metronomi 30–240 BPM, tahtilaji 1–16 / 1,2,4,8,16, 6/8-tulkinta | `ContentView` → `setTempo` / `setCompound` / `toggleMetronome` → `AudioRenderer.render` |
| Piano C2–C6, pito, 12/24 | `PianoKeyboard` → `noteDown` / `noteUp` / `noteCancelled` |
| Viritysääni, tarkka tai SoundFont | `soundMode`, `ReferenceTone.play` |
| Seitsemän temperointia, A4 300–500, H/B-nimet | `Temperament`, `NoteNaming`, asetukset |
| Aloitussoinnut | `ChordLibraryView`, `playChord` |
| Äänitys, enintään 2 h | `RecordingManager.start`, `record(forDuration:)` |
| Tuonti Tiedostoista | `importRecording` → `copyImport` |
| Toisto ja analyysikäyrä | `playRecording`, `RecordingAnalysisView` |
| Viritysmittari ja valinnainen vertailuääni | `LiveTuner`, `TunerView`, `playTunerReference` |
| 31 kieltä | `AppLanguage`, `.lproj` |
| Mainosbanneri asetuksissa | `SettingsBanner` |

## Elinkaari

`ContentView` rivi 65: `.background` tallentaa asetukset ja kutsuu `stopAll`. `.inactive` ei sammuta harjoitusta. Keskeytyksen alku kutsuu `interruptionBegan` ja `stopAll`. Keskeytyksen loppu ei käynnistä ääntä uudelleen. Kuulokkeiden katoaminen (`oldDeviceUnavailable`) kutsuu `stopAll`.

Näytön lukitus pidetään pois päältä, kun metronomi soi, äänitys tai viritin on asiakkaana, tai `sounding` ei ole tyhjä (`refreshIdleTimer`, rivit 266–267). XCTest `testCompoundConversionAndHeldChordKeepScreenAwake` tarkisti pidetyn soinnun.

## Kaksi engineä

Piano käyttää `ChoirAudio.engine`. Viritin luo toisen `AVAudioEngine`n (`LiveTuner.start`, rivi 116). Vertailuääni käynnistää ensimmäisen enginen virittimen enginen rinnalle (`playTunerReference` → `noteDown` → `ensureAudio`). Tätä yhdistelmää ei ajettu laitteella. Katso havainto F-007.
