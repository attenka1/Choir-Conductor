# Choir Master: Android-vaatimukset

Hyväksytty lähtösuunnitelma 16.10.2026. iOS-lähtöpiste: Git a45c5b7.
Tämä on tavoitespesifikaatio; toteutumisen seuranta: ANDROID_STATUS.md.

## Tuote ja rajaus

Natiivi Android-versio nykyisen iOS-version toiminnasta: metronomi (30–240 BPM,
osoittaja 1–16, nimittäjä 1/2/4/8/16, 6/8:n kaksi tulkintaa), moniääninen
C2–C6-piano, Pito, 12/24-EDO, A4 300–500 Hz, kaikki seitsemän
viritysjärjestelmää, nimistö, sointumuisti, paikallinen äänityskirjasto,
kuuntelu/nimeäminen/jakaminen/poisto, kielivalinnat ja saavutettavuus.
SoundFont-urut ja mainokset kuuluvat lopulliseen vastaavuusarvioon; niiden
kirjastot ja lisenssit ratkaistaan erikseen. Verkkoa ei tarvita harjoitteluun,
tallennukseen eikä analyysiin. Mainokset eivät saa estää näitä toimintoja.

Uusi ominaisuus: valmistuneen äänityksen paikallinen säveltason jälkianalyysi.
Ei tässä vaiheessa reaaliaikaista analyysiä, nuottivirheiden tunnistamista,
stemmojen erottelua, pilvipalvelua tai iOS:n ääniytimen vaihtoa.

## AKG Lyra ja USB-C

Ensisijainen kuoroäänityksen tulolaite on AKG Lyra USB:n kautta.
- Käyttö Androidin audiojärjestelmän kautta. USB-C-liitin ei yksin takaa
  USB-host-/OTG-toimintaa, riittävää virransyöttöä eikä äänireititystä.
- Käyttäjä näkee liitetyt mikrofonit ja valitun laitteen ennen tallennusta.
  Suositaan USB-lähdettä, mutta ei päätellä tuotteen identiteettiä pelkän
  nimen tai USB-laitetyypin perusteella. Toinen USB-laite ei saa tulla
  automaattisesti valituksi muistettuna Lyrana.
- USB-tallennustilassa sisäiseen mikrofoniin ei vaihdeta huomaamatta.
- setPreferredDevice-kutsun onnistuminen ei todista todellista reittiä.
  Reitti tarkistetaan tallennuksen käynnistyttyä ja reittimuutoksissa.
  Ennen varmistusta vastaanotetut näytteet eivät saa päätyä hyväksyttyyn
  kuoroäänitteeseen. Varmistuksella on aikaraja ja näkyvä virhetila.
- USB:n irrotus tai vaihtuminen pysäyttää tallennuksen, viimeistelee jo
  tallennetun osuuden ja ilmoittaa syyn. Uudelleenkytkentä ei aloita itsestään.
- Tallennuksen sulkeminen ja reitin vapautus tehdään myös virhetilanteissa.
- Tallenteeseen kirjataan toteutuva Android-asiakasvirran näytetaajuus,
  kanavamäärä, näytemuoto, tulolaitteen nimi/tyyppi ja audio source.
  Näitä ei väitetä USB:n fyysisen siirtoformaatin tai ADC-kellon mittauksiksi.
- Aloitustavoite 48 kHz PCM16; kokeillaan vain tuettuja formaatteja.
  Stereon säilytys on sallittu ja suositeltava Lyra-kokeessa. Analyysissä
  kanavia ei summata sokkona: vastavaihe voi kumota laulun. Kanavakohtaisten
  havaintojen yhdistämistä verrataan mono-downmixiin.
- Lyran suuntakuvio ja fyysinen gain ovat laitteen säätöjä. Sovellus ei lupaa
  ohjata niitä. Näytetään tasomittari ja leikkautumisilmaisin.
- Ei suoraa mikrofonimonitorointia puhelimen kaiuttimeen oletuksena.
- Laitetestit: Lyra kiinni ennen käynnistystä / liitetään sovelluksen aikana,
  irrotus, uudelleenkytkentä, USB-virran katkeaminen, puhelimen lataus
  soveltuvan hubin kautta, stereotilat, mykistys, gain ja pitkä tallennus.

Valmistajan ohjeet:
https://www.akg.com/on/demandware.static/-/Sites-masterCatalog_Harman/default/dw7e87dae2/pdfs/AKG-LYRA-QSG-Combined-091719.pdf
https://www.akg.com.sg/C44-USB.html
Androidin reititys:
https://developer.android.com/reference/android/media/AudioRouting

## Tallennuksen turvallisuus

PCM/WAV on toistettavan analyysin alkuperäinen aineisto; AAC-kopio tehdään
jakamiseen erikseen. 48 kHz PCM16 vaatii monona noin 346 MB/h ja stereona
691 MB/h (desimaalitavuina). Tilaa seurataan ennen tallennusta ja sen aikana.
WAVin kokoraja käsitellään ennen ylivuotoa; keskeneräiset tiedostot voidaan
palauttaa kokonaisista näytekehyksistä. Tallennus ei riipu analyysin onnistumisesta.
Mikrofonilupa pyydetään käyttötarpeessa. Taustalle siirtyminen lopettaa äänen
ja tallennuksen nykyisen iOS-käytännön mukaisesti; lupadialogi tai näkymän
kierto ei saa vastata taustalle siirtymistä. Puhelun/keskeytyksen jälkeen
ääntä ei käynnistetä itsestään.

## Analyysin merkitys

Tulos on suhteellinen, arvioitu yhteisen säveltason muutos ensimmäiseen
luotettavaan jaksoon nähden. Ei lupaus absoluuttisesta vireestä. Ensimmäinen
luotettava jakso on nollataso; epävarmat jaksot ovat aukkoja. Pitkän tauon
jälkeen uusi segmentti saa oman nollatason eikä sitä yhdistetä näennäisen
varmasti aiempaan. Käyrässä esitetään segmenttirajat. Oman piano-/viritysäänen
käyttöjaksot merkitään mahdollisiksi häiriölähteiksi.

Alle 50 sentin oletus on ajallinen ennakko-oletus, ei ehdoton mittausrajoite.
Yksittäistä harhasäveltä vaimennetaan robustisti. Jos yksi laulaja hallitsee
mikrofonisignaalia, koko kuoron virettä ei välttämättä voida päätellä.
Luonnonvireen ja vaihtuvan harmonian vaikutukset validoidaan erikseen.

## Hyväksyminen

Synteettisen analyysikokeen tavoitteet: vakaan vireen 95 % luotettavista
pisteistä ±5 c; 30 c laskun mediaanivirhe ≤5 c; 0…−120 c lasku ilman
100 c hyppyjä; lyhyen harhasävelen vaikutus ≤5 c tai kohta hylätään;
hiljaisuudelle ei luotettavaa arviota. Raportoidaan myös kattavuus ja
viive; kriteerejä ei saa saavuttaa hylkäämällä lähes kaikkea.
Synteettinen onnistuminen ei hyväksy tuotantokäyttöön. Tarvitaan luvallisia,
monipuolisia kuoroäänitteitä ja Lyra/Android-laitetesti. Mittausvirhettä ei
voi arvioida tuntemattomasta äänitteestä algoritmin omalla käyrällä.

Muut hyväksymiskriteerit: vastaavuustestit iOS:n musiikkilogiikalle,
näytekellon metronomitestit, ei soimaan jääviä säveliä, atomiset metatiedot,
korruptoituneen datan säilytys, vähintään tunnin tallennus/analyysi rajatulla
muistilla, keskeytys- ja palautumistestit, TalkBack/suuri teksti/RTL.
