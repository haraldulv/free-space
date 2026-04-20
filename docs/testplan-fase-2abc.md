# Testplan — Fase 2A/2B/2C ende-til-ende

**Build:** iOS 9
**Mål:** Verifisere non-instant booking, tovei reviews og host-dashboard før TestFlight-submit.
**Estimert tid:** ~90 min fokusert.

---

## 0. Forberedelser

- [ ] To kontoer klare: egen som host + test-gjest
- [ ] Test-annonse opprettet med `instant_booking = false`
- [ ] Test-annonsen har minst **2 plasser** (for 2C drill-down)
- [ ] Lav pris satt (f.eks. 50 kr/natt) for å spare Stripe-fees
- [ ] iOS build 9 installert på device via Xcode
- [ ] Andre device eller web åpen for gjest-rollen
- [ ] Stripe Dashboard åpent i **live mode**
- [ ] Supabase SQL editor åpen

---

## 1. Fase 2A — Non-instant booking

### 1A. Godkjenn-flyt

#### Steg 1 — Gjest oppretter booking
- [ ] Logg inn som gjest (annen device eller privat nettleser)
- [ ] Naviger til test-annonsen på `https://www.tuno.no/listings/[id]`
- [ ] Velg 2 netter i datovelger → **Book nå**
- [ ] Fullfør betaling med Stripe-test-kort `4242 4242 4242 4242` (eller ekte kort i live mode — refund etterpå)
- [ ] Gjest lander på bekreftelses-side som sier **"Forespørsel sendt, venter på godkjenning"** (IKKE "Booking bekreftet")

#### Steg 2 — Verifiser i Stripe
- [ ] Åpne **Stripe Dashboard → Payments** (`https://dashboard.stripe.com/payments`)
- [ ] Finn nyeste PaymentIntent (sortert på tid)
- [ ] Klikk inn på den → sjekk at **Status = "Uncaptured"** (gul badge)
- [ ] Under "Payment details": **Capture method = Manual**
- [ ] Noter PI-ID (`pi_...`) for referanse senere

#### Steg 3 — Verifiser i Supabase
- [ ] Supabase Dashboard → **Table Editor → bookings**
- [ ] Sorter på `created_at DESC`, åpne nyeste rad
- [ ] `status = 'requested'` ✓
- [ ] `payment_intent_id` matcher PI-ID fra Stripe
- [ ] Alternativt via SQL editor:
  ```sql
  select id, status, payment_intent_id, total_price, created_at
  from bookings order by created_at desc limit 1;
  ```

#### Steg 4 — Host mottar varsling
- [ ] Push-varsel popper opp på host-device innen ~10 sek
- [ ] Hvis ingen push: sjekk `POST /api/push/send`-logg i Vercel (`https://vercel.com/[team]/tuno/logs`), filtrer på "booking_request"
- [ ] E-post til host (sjekk innboks til kontoen som eier annonsen)

#### Steg 5 — Host åpner forespørsel i iOS
- [ ] Åpne Tuno-appen på host-device
- [ ] Nederste tab **Profil** (ikke Hjem/Søk)
- [ ] Rad med tekst **"Forespørsler"** — rød badge med `1`
- [ ] Trykk inn → `HostRequestsView` åpner
- [ ] Forespørselskortet viser: gjestens navn, plass/annonse-navn, datoer, totalpris, nedtelling (f.eks. "Utløper om 23t 58min")

#### Steg 6 — Gjest-rating
- [ ] Ved gjestens navn: stjerne + tall, eller "Ny gjest" hvis tomt
- [ ] Første booking = "Ny gjest" forventet (blir fylt inn etter 2B)

#### Steg 7 — Host godkjenner
- [ ] Trykk grønn **Godkjenn**-knapp på kortet
- [ ] Bekreftelses-alert → **Ja, godkjenn**
- [ ] Kortet forsvinner fra listen (eller viser "Godkjent")

#### Steg 8 — Verifiser capture i Stripe
- [ ] Refresh Stripe-PI-siden fra steg 2
- [ ] Status bytter fra "Uncaptured" → **"Succeeded"** (grønn badge)
- [ ] "Captured on" timestamp satt

#### Steg 9 — Verifiser status i Supabase
- [ ] Kjør samme SQL som steg 3
- [ ] `status` nå `'confirmed'`
- [ ] `confirmed_at` eller tilsvarende felt fylt ut (hvis feltet finnes)

#### Steg 10 — Gjest får beskjed
- [ ] Gjest-device: push med "Booking bekreftet"
- [ ] Gjest-innboks: bekreftelses-e-post med detaljer
- [ ] Hvis e-post mangler: Vercel-logg for `/api/email/*` eller Resend Dashboard (`https://resend.com/emails`)

#### Steg 11 — Web-verifisering
- [ ] Gjest logger inn på `https://www.tuno.no/dashboard`
- [ ] Tab **"Mine bestillinger"** → booking vises med status "Bekreftet"
- [ ] Klikk inn → detaljer matcher (datoer, annonse, totalpris)

### 1B. Avvis-flyt

- [ ] Ny booking fra gjest på samme annonse
- [ ] Host trykker **Avvis** i forespørsler-tab
- [ ] Stripe: PI `canceled`
- [ ] Supabase: `bookings.status = 'cancelled'`
- [ ] Gjest mottar `booking_declined`-push
- [ ] Gjest mottar avslags-e-post

### 1C. Auto-decline (valgfri, 24t-cron)

- [ ] Opprett en tredje booking
- [ ] SQL: flytt `bookings.created_at` 25 timer tilbake
- [ ] Trigg cron manuelt:
  ```bash
  curl -H "Authorization: Bearer $CRON_SECRET" \
    https://www.tuno.no/api/cron/auto-decline-bookings
  ```
  > ⚠️ Husk `www.tuno.no`, ikke `tuno.no` (redirect stripper Authorization)
- [ ] Status → `cancelled`
- [ ] PI cancelled i Stripe
- [ ] E-post + push sendt til gjest

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

- [ ] Xcode → Product → Archive (build 9)
- [ ] Upload til App Store Connect
- [ ] Legg til interne testere (meg + Kim)
- [ ] Røyktest: installer fra TestFlight
- [ ] Åpne appen → logg inn → kjør 1A + 3 på TestFlight-versjonen

---

## Blockere funnet under test

> Logg her mens du tester. **Ikke fiks midt i** — fullfør runden først.

- [ ]
- [ ]
- [ ]

---

## Etter fullført test

- [ ] Alle blockere triagert (kritisk / kan-vente)
- [ ] Commit-meldinger + SQL for fix dokumentert
- [ ] Build bump + ny xcodegen hvis iOS-fix
- [ ] Neste økt: prio 2 (rydd — /settings, konto-sletting, Sentry, payout-verif)
