# Yhteenveto

Choir Master on iOS 17 -sovellus (versio 1.0.1, build 2). Kotinäyttö, päänäkymä ja Xcoden target, tuote ja scheme käyttävät tätä nimeä. Bundle ID on tarkoituksella `com.atte.tenkanen.ChoirConductor`, jotta päivitys ja puhelimeen jo tallennetut harjoitukset säilyvät. Sitä ei pidä muuttaa nimen vuoksi. Sovellus on kuoroharjoituksen työkalu: metronomi, piano, historialliset viritykset, jatkuva viritysääni, viritysmittari, paikalliset äänitteet ja niiden kokeellinen säveltasokäyrä. Mainosbanneri on vain asetuksissa, ja se ladataan vasta kun ääni ei ole käytössä.

Auditointi tehtiin 2026-11-16 ilman lähdekoodin muutoksia. 24 XCTest-testiä läpäisi iPhone 16 Pro -simulaattorissa (iOS 18.5). Erilliset tarkistukset temperoinnille, virittimelle, rendererille, soinnuille, ääniteindeksille ja 31 kielelle läpäisivät.

## Tulos

Ei CRITICAL- eikä HIGH-tason todistettua vikaa. Aiemmat vakavat epäilyt istunnosta, mittarin tasavireestä ja Bluetooth-puheluprofiilista on korjattu, ja testit pitävät korjaukset paikallaan.

Kaksi keskitasoista asiaa kannattaa korjata ennen kuin tempoon ja tilaan luotetaan harjoituksessa:

1. **6/8-vaihto ei säilytä tempoa**, kun luku ei mahdu välille, jossa jako kolmella ja 30–240-rajat ovat käänteisiä. Oletus 80 pistetahdissa säilyy. Tempo 96 ei: siitä tulee 240 ja takaisin 80. Valitsimen alla on yleinen kuvateksti, että alue voi rajoittaa muunnosta. Se ei näytä tulevaa lukua.
2. **Virittimen vertailuääni jättää päänäkymän viritysäänitilaan.** Ääni kyllä sammuu, mutta seuraava kosketin ei soita pianoa.

Lisäksi README on jäljessä näytön hereilläpidosta, äänen ja sointujen virheet voivat peittää toisensa, työtilassa on kaksi dokumenttipuuta, ja projektitason iOS-oletus on 27.0 vaikka sovellus on 17.0.

Kahden audioenginen yhtäaikaisuus ja mainoslomake ilman view controlleria ovat epäilyjä. Niitä ei toistettu.

## Mikä on kunnossa

Metronomin näytekello, temperoinnin A4-ankkuri, sointujen ja äänitteiden vioittumissuoja, tuonnin tiedostonimet, session palautus, virittimen kohdesävelet kaikissa järjestelmissä ja näytteiden metadatan tarkistus. Äänitteet pysyvät puhelimessa. Verkko tulee mukaan vain mainosten kautta. Näyttönimi Choir Master ei ole sidottu UserDefaults-avaimiin eikä äänitteiden kansioon, joten nimen vaihto ei tyhjennä vanhaa asennusta.

Vanhaa tuotenimeä Choir Conductor ei ole sovelluksen käyttöliittymässä. Se on jäljellä kehityskoneen kansiossa ja tyhjässä Xcode-projektihakemistossa. 26 kielen mikrofonilupa alkaa nimellä Choir Master ja jatkaa käännetyllä roolilla. Englanti ja suomi ovat selkeitä.

## Mitä tämä auditointi ei ole

Ei kuuntelutestiä, ei Bluetooth-koetta, ei App Store -tarkistusta eikä kaikkien käännösten kieliarviota. Analyysikäyrä on edelleen koko kuoron yhteinen arvio, ei stemmojen virhe. Se on kerrottu sovelluksessa, eikä sitä ole laskettu viaksi.

Tarkemmat sijainnit, toistot ja korjaukset ovat tiedostoissa `07-findings.md` ja `08-remediation-plan.md`. Kattavuuden rajat ovat tiedostossa `09-coverage.md`.
