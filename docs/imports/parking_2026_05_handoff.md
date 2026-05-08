# Handoff: Importer Hygglo + Finn parkering-annonser inn i Tuno

## Hva dette er

Vi har scrapet alle parkering/garasje-annonser fra de to største norske utleieplattformene:

- **Hygglo** (`https://www.hygglo.no/category/8959-parkering-garasje`) – 113 annonser. Hygglo selger primært dag- og ukesleie.
- **Finn** (`https://www.finn.no/realestate/lettings/search.html?property_type=6`) – 302 annonser. Finn selger primært månedsleie.

**Totalt: 415 annonser med beskrivelse, adresse, koordinater, pris-pakker, åpningstider (der oppgitt), bilder og selger-info.**

Disse skal inn i staging-databasen til Tuno – dels som test-data for utvikling, dels for at vi kan vise faktiske konkurrent-annonser i appen mens vi bygger volum av egne brukere. Dataformatet er allerede tilpasset Tuno-domenet, men databasen vår mangler noen felter for å støtte hele bredden i datasettet. Den viktigste oppgaven din er å:

1. Bygge en importør som leser `tuno_staging.json` og oppretter parkeringsplass-records i Tuno-staging.
2. Utvide databaseskjemaet med to nye felter (`parking_type` og `rental_period_type`) – og legge `rental_period_type` inn i søkefilteret på frontend.
3. Sørge for at allerede-eksisterende åpningstid-funksjonalitet brukes for de få annonsene som har dette spesifisert.

## Dataset

```
outputs/
├── tuno_staging.json          1.3 MB – 415 annonser i ferdigtygget skjema
├── images/                    184 MB – primærbilder (414 .jpg + 1 default .svg)
├── build_tuno_data.py         scraper/parser-koden (kjørbar – kan re-genere staging.json fra rå HTML)
├── hygglo/ads/                113 rå Hygglo HTML-filer (kildedata, kan slettes etter import)
└── finn/ads/                  302 rå Finn HTML-filer (kildedata, kan slettes etter import)
```

## Schema per annonse (`tuno_staging.json`)

```jsonc
{
  "source": "hygglo" | "finn",         // hvilken plattform den ble scrapet fra
  "source_id": "string",                // slug (Hygglo) eller finnkode (Finn) – stabil unik nøkkel
  "url": "string",                      // den originale annonse-URL-en

  "title":          "string",
  "description":    "string",           // fritekst, kan være tom (3 av 415 ads)
  "address":        "string",           // gate + postnummer + by
  "zip":            "string|null",
  "municipality":   "string|null",      // kommune
  "fylke":          "string|null",
  "lat":            number,             // EPSG:4326
  "lng":            number,

  "currency":       "NOK",
  "min_rental_days": number | null,     // f.eks. 1 (Hygglo) – Finn er null

  "price_packages": [                   // ALLTID ≥ 1, etter at HOUR ble filtrert ut
    {
      "period_type":  "DAY" | "WEEK" | "MONTH" | "YEAR",
      "period_value": number,           // f.eks. 1, 3, 7
      "price_nok":    number,
      "source":       "PLATFORM_TIER" | "DESCRIPTION_TEXT"
    }
  ],

  "opening_hours": [                    // bare for ~4 ads (de fleste er 24/7)
    {
      "days_of_week": [1, 2, 3, 4, 5],  // 1=mandag … 7=søndag
      "time_start":   "08:00",
      "time_end":     "16:00"
    }
  ],

  "parking_type": "GARAGE" | "OUTDOOR" | "PARKING_HOUSE" | null,

  "features": {
    "ev_charging":   bool,
    "heated":        bool,
    "indoor":        bool,
    "outdoor":       bool,
    "surveillance":  bool,
    "covered":       bool,
    "gated":         bool,
    "max_height_cm": number | null,
    "max_length_cm": number | null
  },

  "primary_image_url":   "string",      // ekstern URL (Finncdn / Imgix)
  "primary_image_local": "string",      // relativ sti i outputs/images/
  "primary_image_is_default": bool,     // true hvis vi måtte bruke fallback (1 ad)
  "image_urls": ["string", ...],        // alle bilder fra annonsen, ikke nedlastet

  "seller_type": "private" | "professional" | "wanted",
  "org_name":      "string|null",       // f.eks. "Time Park AS" – kun for finn-prof
  "org_id":         number | null,
  "org_homepage":  "string|null",
  "contact_name":  "string|null",
  "contact_email": "string|null",
  "contact_title": "string|null",

  // Finn-spesifikt (null for Hygglo)
  "deposit_nok":   number | null,
  "lease_period":  "string | null",     // "01.06.2026" eller "01.06.2026 - 01.06.2027"
  "floor":         "string | null"
}
```

## Påkrevde Tuno-skjema-endringer

### 1. `parking_type` (enum, **nytt felt** på Parkeringsplass-tabell)

Tre verdier + null:

| Verdi | Antall i datasettet | Beskrivelse |
|---|---:|---|
| `GARAGE` | 201 (48 %) | Privat eller felles innendørs garasje (borettslag, sameie, eneboliggarasje) |
| `OUTDOOR` | 68 (16 %) | Utendørs (gårdsplass, bakgård, hage, gateplan, grusplass, carport) |
| `PARKING_HOUSE` | 61 (15 %) | Kommersielt parkeringshus / P-anlegg / parkeringskjeller |
| `null` | 85 (21 %) | Utleier har ikke spesifisert. Behandle som "ikke oppgitt" – ikke gjett. |

Frontend-implikasjon: dette skal være valgbart ved opprettelse av ny parkeringsplass, og vises som chip/badge i listevisning. Ikke obligatorisk (null tillatt).

### 2. `rental_period_type` (enum, **nytt felt** – også i søkefilter)

Hver pris-pakke har én av disse typene:

| Verdi | Antall pakker | Forekomster |
|---|---:|---|
| `DAY` | 226 | "200 kr per dag", "550 kr for 3 dager" |
| `WEEK` | 108 | "1 000 kr for 7 dager" |
| `MONTH` | 333 | "1 968 kr per måned" |
| `YEAR` | 0 | (Mulig kategori, men ingen i nåværende datasett – behold for framtidssikring) |

**Kritisk: dette skal også inn i søkefilteret** slik at brukere kan filtrere "vis kun parkeringsplasser med dagsleie" / "vis kun månedsleie". Samme for kart-visning.

Sannsynligvis betyr dette en ny kolonne på `PricePackage`-tabellen (eller hva pris-modellen heter i Tuno) + en filter-prop i `SearchParams` + et UI-element i FilterPanel. Søk i kodebasen etter eksisterende filter-implementasjoner som inspirasjon.

### 3. `opening_hours` (eksisterende funksjonalitet, populeres for 4 ads)

Bare 4 av 415 annonser har strukturerte åpningstider. Dette er sannsynligvis allerede støttet i Tuno (du sier dere har funksjonalitet for "parkeringsplasser med åpningstid"). Bare bruk den eksisterende mekanismen og populere disse 4 records:

- `b03-garasjeplass-naer-oslo-soperaen` (Hygglo): annenhver uke 08:00–16:00 / 10:00–20:00
- `406383704` (Finn, Løkkeveien 10): mandag–fredag 08:00–17:00
- `431837198` (Finn, Bjørvika): alle dager 07:00–20:00
- `451469280` (Finn, Svoldersgate): mandag–fredag 06:00–17:00

Hvis åpningstid-tabellen ikke støtter `days_of_week`-array (men f.eks. 7 separate kolonner eller én record per dag), må du transformere strukturen i importøren.

## Data-kvalitet (verdt å vite før import)

- **3 annonser har tom beskrivelse** (`description: ""`) — ikke en bug i parseren, utleier har faktisk postet uten tekst på Finn. Importen bør tillate tom beskrivelse.
- **1 annonse har ingen bilder** — `primary_image_local: "images/default_parking.svg"` og `primary_image_is_default: true`. Hvis Tuno krever raster (PNG/JPG), må importøren rasterisere SVG-en.
- **Hygglo har ikke selger-skille** – alle 113 har `seller_type: "private"` eller `"wanted"`. Bare Finn har riktig `professional` (103 av 302). Hvis Tuno vil ha en samlet "verifisert utleier"-flagg, kan dere bruke `seller_type === "professional" && org_id !== null` som signal.
- **5 Hygglo-annonser er etterspørsel ("Søker parkeringsplass …")** – `seller_type: "wanted"`. Disse skal nok IKKE importeres som tilbudte plasser; vurder å filtrere dem ut eller importere dem som "rental requests" hvis Tuno har en slik modell.
- **`source` + `source_id` er den primærnøkkelen for dedupe.** Hvis du re-kjører importøren skal en eksisterende rad oppdateres, ikke duplikateres.

## Forslag til implementasjons-trinn

1. **Sett opp database-migrasjoner** – legg til `parking_type` enum og `rental_period_type` enum + nullable kolonner.
2. **Skriv en importer-script** (f.eks. en CLI-kommando) som leser `tuno_staging.json`, mapper hver record til Tuno-modellen, og opserer/oppdaterer i database. Bruk `(source, source_id)` som unike nøkkel.
3. **Kopier images/-mappen** til Tunos asset-storage (S3/blob/etc), oppdater `primary_image_url` til den hostede URL-en.
4. **Oppdater søkefilter-UI** for å støtte `rental_period_type` (multi-select chip).
5. **Oppdater listing-UI** for å vise `parking_type` som badge/ikon.
6. **Populere åpningstider** for de 4 ads via eksisterende åpningstid-modell.
7. **Test:** kjør importeren mot tom staging-database, verifiser at alle 415 (eller 410 om vi dropper "wanted") records havner korrekt med pris-pakker og bilder.

## Forslag til første prompt for Claude Code

Her er en prompt du kan starte Claude Code-økten med (klipp og lim):

```
Jeg har scrapet 415 parkering-annonser fra Hygglo (113) og Finn (302) som
skal importeres til Tuno-staging. Dataen ligger i ./tuno_staging.json med
ferdigtygget skjema beskrevet i HANDOFF_TO_CLAUDE_CODE.md.

Vi vil tilpasse Tuno-modellen til dette datasettet. To viktige endringer:

1. Nytt felt `parking_type` på Parkeringsplass: enum
   GARAGE | OUTDOOR | PARKING_HOUSE | NULL.

2. Nytt felt `rental_period_type` på pris-pakker: enum
   DAY | WEEK | MONTH | YEAR. Dette skal også inn i søkefilteret
   slik at brukere kan filtrere etter pris-periode.

I tillegg har 4 av annonsene strukturerte åpningstider som skal inn via
eksisterende åpningstid-modell.

Begynn med å:
1. Lese HANDOFF_TO_CLAUDE_CODE.md fullt ut.
2. Utforske kodebasen for å finne (a) hvor Parkeringsplass-modellen er
   definert, (b) hvordan pris-pakker er modellert i dag, (c) hvordan
   søkefilteret er bygget, (d) hvordan eksisterende åpningstid-funksjonalitet
   ser ut.
3. Komme tilbake med en plan før du gjør endringer.

Datafiler:
- tuno_staging.json (1.3 MB, 415 records)
- images/ (414 .jpg + 1 .svg, 184 MB)
- build_tuno_data.py (scraper-koden – ikke trengs for import, men kan
  re-kjøres om vi vil oppdatere kildedataene fra Hygglo/Finn senere)
```

## Filer som skal flyttes inn i Tuno-repo

| Fra (cowork outputs) | Til (Tuno-repo, foreslått) |
|---|---|
| `tuno_staging.json` | `data/external_imports/parking_2026_05.json` |
| `images/` | `data/external_imports/images/` |
| `HANDOFF_TO_CLAUDE_CODE.md` | `docs/imports/parking_2026_05_handoff.md` |
| `build_tuno_data.py` | `scripts/scrape_parking.py` (valgfritt – beholdes hvis re-scrape ønskes) |

## Andre endringer du sannsynligvis kommer med

Du nevnte at det kommer flere relaterte endringsforespørsler. Det viktigste for Claude Code er å forstå **at dette datasettet er kilden** – så når neste ønske kommer ("legg til en `surveillance`-filter"; "vis EV-lader-symbol"; "highlight profesjonelle utleiere") så kan Claude Code se at feltet allerede finnes i `tuno_staging.json`, og bruke det som test-data uten å måtte mocke noe.
