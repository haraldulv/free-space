# Testplan — Fase 2A/2B/2C ende-til-ende

**Build:** iOS 12 (re-testes etter build 12-fix'er)
**Mål:** Verifisere non-instant booking, tovei reviews og host-dashboard før TestFlight-submit.
**Estimert tid:** ~90 min fokusert.

**Build 12-endringer (nyeste) å re-verifisere i Fase 2A.3 under:**
- Meldinger-fanen laster raskt (4 batch-queries istedenfor 4·N waterfall)
- Bildecache (CachedAsyncImage) — listing-bilder + avatarer persisterer mellom app-launches
- Språkbytte-UX (loading-overlay + tyske strenger 100% komplett)
- Utvidet SettingsView (varsler, support, juridiske lenker, versjon)

**Build 11-endringer å re-verifisere i Fase 2A.2:**
- Profil-tab badge (pending host requests vises på selve tab'en)
- Avatar-upload i iOS (`Rediger profil` — bruker kan laste opp eget bilde)
- Pris-oppdeling i detail-sheet ("Gjesten betaler" + "Din andel" tydelig skilt)
- Payout-formel fikset (host får nå full listed pris, ikke ~1% mindre)

**Build 10-endringer (fortsatt relevant):**
- Push-routing for `booking_request` (P0-bug fikset)
- Descending sort (nyeste forespørsel øverst)
- "Ny gjest"-label
- Airbnb-paritet på kortet (avatar, rating, tidl. turer, "Gjest siden")
- Detail-sheet med "Se gjennom" + bekreftelses-alerts
- Await på alle push + e-post (decline-e-post fungerte ikke i build 9)

---

## 0. Forberedelser

- [x] To kontoer klare: egen som host + test-gjest
- [x] Test-annonse opprettet med `instant_booking = false`
- [x] Test-annonsen har minst **2 plasser** (for 2C drill-down)
- [x] Lav pris satt (f.eks. 50 kr/natt) for å spare Stripe-fees
- [ ] iOS build 12 installert på device via Xcode (`cd TunoApp && xcodegen generate`, bygg via Xcode på device)
- [x] Andre device eller web åpen for gjest-rollen
- [x] Stripe Dashboard åpent i **live mode**
- [x] Supabase SQL editor åpen

---

## 1. Fase 2A — Non-instant booking

### 1A. Godkjenn-flyt

#### Steg 1 — Gjest oppretter booking
- [x] Logg inn som gjest (annen device eller privat nettleser)
- [x] Naviger til test-annonsen på `https://www.tuno.no/listings/[id]`
- [x] Velg 2 netter i datovelger → **Book nå** (valgte 1 natt bare)
- [x] Fullfør betaling med Stripe-test-kort `4242 4242 4242 4242` (eller ekte kort i live mode — refund etterpå)
- [x] Gjest lander på bekreftelses-side som sier **"Forespørsel sendt, venter på godkjenning"** (IKKE "Booking bekreftet")

#### Steg 2 — Verifiser i Stripe
- [x] Åpne **Stripe Dashboard → Payments** (`https://dashboard.stripe.com/payments`)
- [x] Finn nyeste PaymentIntent (sortert på tid)
- [x] Klikk inn på den → sjekk at **Status = "Uncaptured"** (gul badge)
- [x] Under "Payment details": **Capture method = Manual**
- [x] Noter PI-ID (`pi_...`) for referanse senere


#### Steg 3 — Verifiser i Supabase
- [x] Supabase Dashboard → **Table Editor → bookings**
- [x] Sorter på `created_at DESC`, åpne nyeste rad
- [x] `status = 'requested'` ✓
- [x] `stripe_payment_intent_id` matcher PI-ID fra Stripe
- [x] Alternativt via SQL editor:
  ```sql
  select id, status, stripe_payment_intent_id, created_at
  from bookings order by created_at desc limit 1;
  ```

#### Steg 4 — Host mottar varsling
- [x] Push-varsel popper opp på host-device innen ~10 sek
- [x] Hvis ingen push: sjekk `POST /api/push/send`-logg i Vercel (`https://vercel.com/[team]/tuno/logs`), filtrer på "booking_request"
- [x] E-post til host (sjekk innboks til kontoen som eier annonsen)

#### Steg 5 — Host åpner forespørsel i iOS
- [x] Åpne Tuno-appen på host-device
- [x] Nederste tab **Profil** (ikke Hjem/Søk)
- [x] Rad med tekst **"Forespørsler"** — rød badge med `1`
- [x] Trykk inn → `HostRequestsView` åpner
- [x] Forespørselskortet viser: gjestens navn, plass/annonse-navn, datoer, totalpris, nedtelling (f.eks. "Utløper om 23t 58min")

#### Steg 6 — Gjest-rating
- [x] Ved gjestens navn: stjerne + tall, eller "Ny gjest" hvis tomt
- [x] Første booking = "Ny gjest" forventet (blir fylt inn etter 2B)

#### Steg 7 — Host godkjenner
- [x] Trykk grønn **Godkjenn**-knapp på kortet
- [x] Bekreftelses-alert → **Ja, godkjenn**
- [x] Kortet forsvinner fra listen (eller viser "Godkjent")

#### Steg 8 — Verifiser capture i Stripe
- [x] Refresh Stripe-PI-siden fra steg 2
- [x] Status bytter fra "Uncaptured" → **"Succeeded"** (grønn badge)
- [x] "Captured on" timestamp satt

#### Steg 9 — Verifiser status i Supabase
- [x] Kjør samme SQL som steg 3
- [x] `status` nå `'confirmed'`
- [x] `confirmed_at` eller tilsvarende felt fylt ut (hvis feltet finnes)

#### Steg 10 — Gjest får beskjed
- [x] Gjest-device: push med "Booking bekreftet"
- [x] Gjest-innboks: bekreftelses-e-post med detaljer
- [x] Hvis e-post mangler: Vercel-logg for `/api/email/*` eller Resend Dashboard (`https://resend.com/emails`)

#### Steg 11 — Web-verifisering
- [x] Gjest logger inn på `https://www.tuno.no/dashboard`
- [x] Tab **"Mine bestillinger"** → booking vises med status "Bekreftet"
- [x] Klikk inn → detaljer matcher (datoer, annonse, totalpris)

### 1A.1 — Build 10 regresjonsverifikasjon

> Kjør på en ny test-booking. Bruk ny, liten sum (3–5 kr) for å unngå Stripe-fees.

#### R1 — Push-routing for booking_request (P0-fix)
- [x] Lag ny booking som gjest, lukk appen helt på host-device (swipe vekk)
- [x] Trykk på push-varselet "Ny booking-forespørsel"
- [x] App åpner direkte i `HostRequestsView` — IKKE "Bestillinger"-tab
- [x] Hvis app var i bakgrunnen: samme oppførsel (åpner riktig tab + navigerer)

#### R2 — Descending sort
- [x] Lag minst to forespørsler (to separate bookinger fra gjest)
- [x] Åpne Forespørsler — nyeste booking skal være ØVERST (ikke nederst som i build 9)

#### R3 — Airbnb-paritet på kortet
- [x] Gjestens avatar vises som sirkel øverst til venstre på kortet
- [x] Hvis gjesten ikke har avatar: fallback-sirkel med gjestens initial vises
- [x] Kort viser "Ny gjest"-pill når `reviewCount = 0` (ikke tomt felt)
- [x] Kort viser "X turer" hvis gjesten har tidligere confirmed bookinger
- [x] Kort viser "Gjest siden {år}" hvis `joined_year` er satt i profil

#### R4 — Detail-sheet ("Se gjennom")
- [x] Trykk hvor som helst på forespørselskortet → detail-sheet åpner som bottom-sheet
- [x] Sheet viser: stort avatar, navn, rating/Ny gjest, turer, "Siden {år}"
- [x] Oppholdet-seksjon: annonse-bilde, tittel, by, ankomst, avreise, frist
- [x] Pris-seksjon: totalbeløp + forklaring om utbetaling
- [x] "Hva skjer nå?"-seksjon med tre bullet points (policy)
- [x] I bunnen: **Avvis** (rød outline) + **Godkjenn** (grønn) som sticky action-bar

#### R5 — Bekreftelses-alert før godkjenn/avvis
- [x] Trykk **Godkjenn** → alert "Godkjenn forespørselen?" med forklaring om belastning
- [x] "Avbryt" → sheet forblir åpen, ingenting skjer
- [x] "Godkjenn" → kallet går gjennom, sheet lukkes, kortet forsvinner fra listen
- [x] Samme prinsipp for Avvis: alert "Avvise forespørselen?" → Avbryt/Avvis

#### R6 — Decline-e-post (await-fiks)
- [x] Avvis en forespørsel via sheet
- [x] **Gjest-innboks:** e-posten "Forespørselen ble ikke godkjent" kommer fram innen ~15 sek (i build 9 ble denne kuttet av Vercel-lambda)

---

### 1A.2 — Build 11 regresjonsverifikasjon

> Nye fiks etter build 10-testen. Kjør med samme test-annonse.

#### R7 — Profil-tab badge
- [ ] Lag ny booking som gjest
- [ ] Host-device: se på bunnen av skjermen — **Profil**-tab har rød badge med `1` (telleren for pending forespørsler)
- [ ] Bytt til andre tabs og tilbake — badge vises fortsatt
- [ ] Godkjenn eller avvis forespørselen → badge forsvinner fra Profil-tab
- [ ] Verifiser også at ved 0 pending forespørsler: ingen badge
- [ ] Merk: badge på "Forespørsler"-raden INNE i Profil-siden skal fortsatt virke (uendret)

#### R8 — Avatar-upload (iOS)
- [ ] Profil → **Rediger profil**
- [ ] Øverst vises profilbilde-sirkel med kamera-ikon
- [ ] Trykk på sirkelen → PhotosPicker åpner
- [ ] Velg et bilde → lastes opp (spinner vises)
- [ ] Sirkelen viser nytt bilde etter få sekunder
- [ ] Gå ut av "Rediger profil" og inn igjen — bildet persisterer
- [ ] **Verifiser at gjest-siden også ser bildet:** kjør ny booking der denne gjesten er gjest → host ser gjestens nye avatar på forespørselskortet
- [ ] **Web:** gjesten går til `tuno.no/dashboard?tab=settings` (Innstillinger) → samme avatar vises → kan byttes derfra også (eksisterende flyt)

#### R9 — Pris-oppdeling i detail-sheet
- [ ] Åpne en forespørsel → detail-sheet
- [ ] Pris-seksjon viser nå:
  - "Gjesten betaler: {X} kr" (liten, grå)
  - "Din andel: {Y} kr" (stor, grønn, fet)
- [ ] Forklarings-tekst: "Du får utbetalt din pris. Tunos servicegebyr betales av gjesten på toppen."
- [ ] For små testbeløp (3 kr): begge tallene kan være like fordi fee rundes til 0. For større beløp (f.eks. 110 kr-booking): "Gjesten betaler 110", "Din andel 100"

#### R10 — Payout-formel (web + backend)
- [ ] Sjekk SQL: finn en `confirmed + paid + transfer_status=pending`-booking
  ```sql
  select id, total_price from bookings
  where status='confirmed' and payment_status='paid' and transfer_status='pending'
  order by check_in desc limit 5;
  ```
- [ ] Trigg payout-cron manuelt (bruk `www`-domene):
  ```bash
  curl -H "Authorization: Bearer $CRON_SECRET" \
    https://www.tuno.no/api/cron/process-payouts
  ```
- [ ] Verifiser i Stripe Dashboard → Connected Accounts → host → Transfers: beløpet matcher `total_price - round(total_price * 0.1 / 1.1)` (ikke `total_price * 0.9` som før)
- [ ] Sjekk `notifications`-rad i Supabase + push/e-post til host: "X kr overført" der X er korrekt host-andel
- [ ] Sjekk host-dashboard `/dashboard/annonse/[id]` → inntekts-widget bruker samme korrekte formel

---

### 1A.3 — Build 12 regresjonsverifikasjon (perf + i18n + settings)

> Etter at bygget er installert, kjør disse før du fortsetter med 1B/1C/1D.

#### R11 — Meldinger-fanen lasting
- [ ] Logg inn og vent til appen er fullastet (Forsiden vises)
- [ ] Trykk **Meldinger**-tab → listen skal vises innen 1 sekund (helst momentant)
- [ ] Kald start: force-quit appen, re-åpne, gå direkte til Meldinger — fortsatt < 1 sek
- [ ] Pull-to-refresh skal fortsatt fungere (re-laster samme batch)
- [ ] Marker en samtale som lest (åpne + les) — unread-counter i tab-bar + bjellen oppdateres
- [ ] **Måling (valgfri):** I Xcode Debug-konsoll, se etter "Failed to load conversations" — skal ikke forekomme

#### R12 — Bildecache
- [ ] Forsiden: scroll gjennom alle seksjoner (Populære, Utvalgte, Tilgjengelige i dag)
- [ ] Scroll tilbake — bildene vises momentant (ingen re-load-flicker)
- [ ] Force-quit appen og åpne på nytt → bildene på forsiden skal vises nesten umiddelbart (fra disk-cache, ikke nytt nettkall)
- [ ] Meldinger-avatarer: scroll listen → ingen flicker
- [ ] **Måling (valgfri):** I Xcode → Debug Navigator → Network — total bytes bør være lavere etter fix (Vi har 50 MB RAM + 500 MB disk allokert i `TunoApp.init()`)

#### R13 — Utvidet SettingsView
- [ ] Profil-tab → Innstillinger
- [ ] Seksjoner synlige (i rekkefølge):
  - **Språk** (nb/en/de — som før)
  - **Varsler** — "Push-varslinger" → åpner iOS-innstillinger
  - **Hjelp** — "Kontakt support" (mailto:support@tuno.no) + "Retningslinjer"
  - **Juridisk** — "Brukervilkår", "Utleiervilkår", "Personvernerklæring" (alle åpner Safari til tuno.no)
  - **Om appen** — versjonsnummer ("1.0.0 (12)")

#### R14 — Språkbytte-UX + tysk completeness
- [ ] Innstillinger → velg **Deutsch 🇩🇪**
- [ ] **Spinner-overlay vises i ~250 ms** med teksten "Bytter språk…" (ny feedback i build 12)
- [ ] Liste-knappene er disabled mens spinneren vises
- [ ] Etter bytte: tab-titler, knapper, labels skal være på tysk
- [ ] Gå inn på en annonse-detaljside, book-flow, og forespørsler-sheet — ingen norske ord igjen (tidligere blanding av norsk og tysk)
- [ ] Konkrete strings å sjekke: "Ny gjest" → "Neuer Gast", "Se gjennom" → "Überprüfen", "Forespørsel" → "Anfrage", "kr/natt" → "kr/Nacht"
- [ ] Bytt tilbake til **Norsk** — samme spinner-oppførsel, ingen engelske strings igjen

---

### 1B. Avvis-flyt (med ny detail-sheet)

- [ ] Ny booking fra gjest på samme annonse
- [ ] Host åpner Forespørsler (via push eller manuelt)
- [ ] Trykk på kortet → detail-sheet
- [ ] Trykk **Avvis** → alert → **Avvis**
- [ ] Sheet lukkes, kortet forsvinner fra listen
- [ ] Stripe: PI `canceled`
- [ ] Supabase: `bookings.status = 'cancelled'`, `cancellation_reason = 'host_declined'`
- [ ] Gjest mottar `booking_declined`-push
- [ ] **Gjest mottar avslags-e-post** (re-verifisering etter build 9-bug)

### 1C. Auto-decline (valgfri, 24t-cron)

- [ ] Opprett en tredje booking
- [ ] SQL: flytt `bookings.approval_deadline` til i går (deadline passert)
  ```sql
  update bookings set approval_deadline = now() - interval '1 hour'
  where id = '<booking-id>';
  ```
- [ ] Trigg cron manuelt:
  ```bash
  curl -H "Authorization: Bearer $CRON_SECRET" \
    https://www.tuno.no/api/cron/auto-decline-bookings
  ```
  > ⚠️ Husk `www.tuno.no`, ikke `tuno.no` (redirect stripper Authorization)
- [ ] Status → `cancelled`, `cancellation_reason = 'auto_declined_timeout'`
- [ ] PI cancelled i Stripe
- [ ] E-post + push sendt til gjest (etter await-fiks i b9c1a24)

### 1D. Regresjon — instant booking

- [ ] Lag en annonse med `instant_booking = true`
- [ ] Book den som gjest
- [ ] Status går rett til `confirmed` (ingen forespørsel)
- [ ] PI captured umiddelbart
- [ ] Booking vises **ikke** i host sin forespørsler-tab

---

## 2. Fase 2B — Tovei blind reviews

Bruker den godkjente bookingen fra **1A**.

### Forberedelse

- [ ] SQL: sett `bookings.check_out` til i går (simuler fullført opphold)

### Gjest skriver først

- [ ] Gjest skriver review (web eller iOS) → Mine bestillinger → Anmeld
- [ ] Supabase `reviews`: rad med `reviewer_role='guest'`, `reviewee_id=host`
- [ ] Host ser **IKKE** gjest-reviewen ennå (blind til begge har levert eller 14d)

### Host skriver fra web (iOS-gap)

- [ ] Web: `/dashboard` → booking-kort → **Anmeld gjesten**
- [ ] Supabase `reviews`: rad med `reviewer_role='host'`

### Etter begge har levert

- [ ] Begge ser hverandres reviews
- [ ] Banner + visning rendrer korrekt
- [ ] `profiles.rating` + `review_count` oppdatert på begge profilene (trigger)
- [ ] `listings.rating` oppdatert — **kun guest-reviews** teller
- [ ] Book på nytt med samme gjest → host ser gjest-rating i forespørsler-tab

### iOS-gap dokumenteres

- [ ] Bekreftet: host-review-skriving finnes **ikke** i iOS ennå (på kø som prio 5)

---

## 3. Fase 2C — Host-dashboard per plass

### Web

- [ ] `/dashboard` → Mine annonser → klikk test-annonsen
- [ ] `/dashboard/annonse/[id]` laster
- [ ] Stats: belegg 30d + 90d vises
- [ ] Stats: inntekt 30d + 90d vises
- [ ] Tabell med kommende bookinger
- [ ] Per-plass-grid vises
- [ ] Klikk en plass → `/dashboard/annonse/[id]/plass/[spotId]`
- [ ] Kalender viser **booket** (grønn) korrekt
- [ ] Kalender viser **blokkert** (grå) korrekt
- [ ] Marker noen datoer → **Lagre blokkering**
- [ ] Reload → datoer fortsatt blokkert
- [ ] Som gjest: prøv å booke de blokkerte datoene → skal feile

### iOS

- [ ] Host → Mine annonser → klikk annonse → `HostListingStatsView` åpner
- [ ] Samme tall som web (belegg, inntekt)
- [ ] Per-plass-grid speiler web
- [ ] Drill ned → `HostSpotDetailView`
- [ ] Blokker datoer via app (treffer `/api/host/spot-blocked-dates`)
- [ ] Verifiser: samme datoer reflekteres på web

---

## 4. TestFlight

- [ ] Xcode → Product → Archive (build 12)
- [ ] Upload til App Store Connect
- [ ] Legg til interne testere (meg + Kim)
- [ ] Røyktest: installer fra TestFlight
- [ ] Åpne appen → logg inn → kjør 1A + 3 på TestFlight-versjonen

---

## Blockere funnet under test

> Logg nye blockere her mens du tester. **Ikke fiks midt i** — fullfør runden først.

- [ ]
- [ ]
- [ ]

---

## Løst i build 10 (verifiser via Fase 2A.1)

- [x] **P0 — Push-routing (booking_request):** Fikset. Type settes nå før id i `PushNotificationManager`, og `ProfileView` fanger initial pending-state ved `onAppear`.
- [x] **Sortering av forespørsler:** `HostRequestsView` sorterer nå på `created_at descending` (nyeste øverst).
- [x] **"Ny gjest"-label:** Pill med "Ny gjest" vises nå for gjester uten reviews, både på kortet og i detail-sheeten.
- [x] **`HostRequestsView` — Airbnb-paritet:** Avatar, rating, "X turer", "Gjest siden {år}" på kortet. Full oppsummering i detail-sheet.
- [x] **"Se gjennom"-steg før godkjenn:** Ny `HostRequestDetailSheet` med policy-info og bekreftelses-alerts på Godkjenn og Avvis. Inline-knappene er borte.
- [x] **Fire-and-forget push/e-post:** Alle sendinger er nå await'et før serverless-return. Gjelder respond-route, cron/process-payouts, reviews-actions, og book/actions (commit b9c1a24).

## Løst i build 11 (verifiser via Fase 2A.2)

- [x] **Profil-tab badge:** `CustomTabBar` viser nå rød badge på Profil-tab med antall pending forespørsler. `MainTabView` holder state og refresher ved push + tab-switch.
- [x] **Avatar-upload iOS:** `EditProfileView` har nå PhotosPicker-basert opplasting til Supabase Storage (`avatars`-bucket). Komprimering via felles `ImageCompression.compressForUpload`. Web har fra før `SettingsPanel.handleAvatarChange`.
- [x] **Pris-oppdeling "Se gjennom":** Sheet viser nå "Gjesten betaler" + "Din andel" tydelig skilt. Host-andel beregnes lokalt med samme formel som `lib/cancellation.ts`.
- [x] **Payout-formel bug:** `process-payouts`, `stats.ts`, `lib/email.ts` brukte `total * 0.9` — feil fordi fee legges på toppen (`total = subtotal * 1.1`), så riktig formel er `total - round(total * 0.1 / 1.1)`. Underbetalte host ~1%. Fikset via ny `splitHostAndFee`-helper i `lib/config.ts`.

## Løst i build 12 (verifiser via Fase 2A.3)

- [x] **Meldinger-fanen lasting:** `ChatService.loadConversations` rewrote fra 1 + 4·N waterfall (8–20 sek for 10 samtaler) til 4 batch-queries parallelt (~300–800 ms uansett antall). `markAsRead` tilsvarende: én UPDATE i stedet for N.
- [x] **ChatService deles:** `MessagesListView` brukte eget `@StateObject` — doble-laste queries. Nå delt via `EnvironmentObject` fra `MainTabView`, som forhåndslaster ved app-start.
- [x] **Bildecache:** Ny `CachedAsyncImage`-komponent bruker `URLCache.shared` (50 MB RAM + 500 MB disk, konfigurert i `TunoApp.init()`). Byttet ut `AsyncImage` i `ListingCard`, `MessagesListView`, `HostRequestsView`, `ProfileView`.
- [x] **Språkbytte-UX:** `LocalizationManager.isChangingLanguage` med 250 ms spinner-overlay i `SettingsView`.
- [x] **Tysk i18n completeness:** 57 manglende strenger lagt til i `Localizable.xcstrings`. 406/406 strings har nå tysk (var 349/406).
- [x] **SettingsView utvidet:** Språk + Varsler (iOS-innstillinger) + Hjelp (support + retningslinjer) + Juridisk (vilkår + personvern) + Om appen (versjon + build). Tidligere var det bare språk.

---

## Etter fullført test

- [ ] Alle blockere triagert (kritisk / kan-vente)
- [ ] Commit-meldinger + SQL for fix dokumentert
- [ ] Build bump + ny xcodegen hvis iOS-fix
- [ ] Neste økt: prio 2 (rydd — /settings, konto-sletting, Sentry, payout-verif)
