# Testplan — Kim-call 2026-04-20

**Build:** iOS 12 (nyeste: commit `c52ff20`)
**Tid:** ~45 min demo + røyktest
**Mål:** Demo av alle dagens endringer + avdekke neste punch-list før TestFlight-submit.

**Dekker:**
- Build 10–12 regresjon (push-routing, Se gjennom, avatar, Meldinger-perf, språk)
- 1B Avvis-flyt, 1C Auto-decline, 1D Instant-regresjon
- Fase 2B (reviews), Fase 2C (host-dashboard)

---

## 0. Før Kim ringer — 5 min

### 0.1 APNs-konfigurasjon
Velg én av to moduser under, og **sørg for at entitlement og Vercel env matcher**:

**Xcode-dev-build (raskeste for iterasjon):**
- [ ] `APNS_PRODUCTION=false` i Vercel → redeploy
- [ ] `project.yml`: `aps-environment=development`
- [ ] Kjør fra Xcode på device

**TestFlight (mer demo-realistisk):**
- [ ] `APNS_PRODUCTION=true` i Vercel → redeploy
- [ ] `project.yml`: `aps-environment=production`
- [ ] Bygg build 12 Archive + Distribute → App Store Connect → TestFlight
- [ ] Kim installerer fra TestFlight-link

> ⚠️ Mismatch = silent push-drop på device. Se `feedback_apns_environments.md`.

### 0.2 Oppsett
- [ ] Host-konto klar (Harald), gjest-konto klar (Kim eller egen test-gjest)
- [ ] Test-annonse: `instant_booking=false`, minst 2 plasser, pris 3–5 kr (unngå unødvendige Stripe-fees)
- [ ] Supabase SQL-editor + Stripe Dashboard + Vercel Logs åpen i parallelle fanevinduer
- [ ] Force-quit appen på host-device, vent 10 sek (clear in-memory state)

---

## 1. Demo: Booking ende-til-ende — 10 min

Hovedflyten vi har bygget i dag. Alt skal funke smooth.

### 1.1 Gjest booker
- [ ] Kim (eller test-gjest) åpner `https://www.tuno.no/listings/[id]`
- [ ] Velger 1 natt → **Book nå** → betaler med kort
- [ ] Bekreftelses-side sier **"Forespørsel sendt, venter på godkjenning"**

### 1.2 Host får push + e-post
- [ ] Push innen ~10 sek: "Ny booking-forespørsel" — med gjestens navn + annonse
- [ ] E-post til host-innboks (branded Tuno, via Resend)
- [ ] Profil-tab badge viser rød `1` ← **build 11 R7**
- [ ] Rød badge også på "Forespørsler"-raden inne i Profil

### 1.3 Trykk push → Forespørsler
- [ ] Tap på push-varselet → appen åpner rett i **HostRequestsView** (ikke "Bestillinger"-tab) ← **build 10 R1**
- [ ] Ved kald start: samme oppførsel

### 1.4 Forespørselskortet
- [ ] Gjestens avatar (eller initial-fallback) øverst til venstre ← **build 10 R3**
- [ ] Hvis første booking: **"Ny gjest"**-pill ← **build 10 R3**
- [ ] Annonse-bilde + tittel + datoer + totalpris
- [ ] Orange nedtelling: "Utløper om X t Y min"
- [ ] Hvis flere forespørsler: **nyeste øverst** ← **build 10 R2**

### 1.5 "Se gjennom"-sheet
- [ ] Trykk hvor som helst på kortet → bottom-sheet åpner ← **build 10 R4**
- [ ] Sheet viser:
  - Stort avatar, navn, rating / "Ny gjest", "X turer", "Gjest siden YYYY"
  - Oppholdet: annonse-bilde, by, ankomst, avreise, frist
  - Pris: **"Gjesten betaler X kr"** + **"Din andel Y kr"** (tydelig skilt) ← **build 11 R9**
  - Policy: 3 bullet points
- [ ] Sticky action-bar i bunnen: rød "Avvis" + grønn "Godkjenn"

### 1.6 Godkjenn
- [ ] Trykk **Godkjenn** → alert "Godkjenn forespørselen?" ← **build 10 R5**
- [ ] "Avbryt" → ingenting skjer
- [ ] "Godkjenn" → sheet lukkes, kortet forsvinner, Profil-badge blir 0
- [ ] **Kim-device:** push "Forespørselen er godkjent!" innen ~10 sek
- [ ] **Kim-innboks:** bekreftelses-e-post ← **build 9 R6 (await-fiks)**
- [ ] **Kim-web:** `tuno.no/dashboard` → "Kommende"-seksjon viser bookingen som "Bekreftet"

### 1.7 Stripe + DB verifisering
- [ ] Stripe Dashboard: PI → **Succeeded** (grønn), "Captured on" timestamp
- [ ] Supabase SQL:
  ```sql
  select id, status, payment_status, host_responded_at from bookings
  order by created_at desc limit 1;
  ```
  Forventet: `confirmed`, `paid`, timestamp satt

---

## 2. Meldinger + bildecache — 5 min

### 2.1 Meldinger-perf
- [ ] Tab **Meldinger** (tab 3) → listen skal vises innen ~1 sek ← **build 12 R11**
- [ ] Force-quit appen → åpne → trykk Meldinger **direkte** → fortsatt < 1 sek
- [ ] Unread-counter på bjellen (rød badge på tab 3) matcher faktisk antall uleste
- [ ] Åpne en samtale → sender melding → Kim ser den i realtime

### 2.2 Bildecache
- [ ] Forsiden: scroll gjennom alle seksjoner (Populære, Utvalgte, Tilgjengelige i dag)
- [ ] Scroll tilbake → bildene vises momentant (ingen flicker / re-load) ← **build 12 R12**
- [ ] Force-quit + åpne → forsiden rendrer nesten umiddelbart (disk-cache)

---

## 3. Profil + avatar — 3 min

- [ ] Profil → **Rediger profil**
- [ ] Avatar-sirkel øverst med kamera-badge nederst til høyre (IKKE kuttet av sirkelen) ← **build 12 fix `7977c31`**
- [ ] Trykk på sirkelen → PhotosPicker → velg bilde → kort spinner → nytt bilde vises ← **build 11 R8**
- [ ] Gå ut og inn igjen → persisterer
- [ ] Hvis Kim booker etter Harald har byttet avatar: Kim ser nye bildet på forespørselskortet

---

## 4. Språkbytte + tysk — 3 min

- [ ] Profil → Innstillinger → trykk **Deutsch 🇩🇪**
- [ ] **Spinner-overlay vises ~250 ms** med "Bytter språk…" ← **build 12 R14**
- [ ] Knappene disabled mens spinner vises
- [ ] Etter bytte: navigate til forespørsler, booking-detalj, sheet
- [ ] Ingen norske ord (tidligere blanding av nb/de) ← **build 12 R14**
- [ ] Spesifikke strenger: "Ny gjest" → **"Neuer Gast"**, "Se gjennom" → **"Überprüfen"**, "kr/natt" → **"kr/Nacht"**
- [ ] Bytt tilbake til **Norsk** — samme smooth overgang

---

## 5. Utvidet Innstillinger — 2 min

- [ ] Profil → Innstillinger → scroll gjennom alle seksjoner ← **build 12 R13**
- [ ] Synlige seksjoner:
  - Språk (nb/en/de)
  - Varsler → "Push-varslinger" (åpner iOS-innstillinger)
  - Hjelp → "Kontakt support" (mailto:support@tuno.no) + "Retningslinjer"
  - Juridisk → "Brukervilkår" / "Utleiervilkår" / "Personvernerklæring" (åpner Safari til tuno.no)
  - Om appen → "Versjon 1.0.0 (12)"
- [ ] Trykk "Brukervilkår" → Safari åpner tuno.no/vilkar

---

## 6. Avvis-flyt — 5 min

- [ ] Kim lager ny booking
- [ ] Host åpner Forespørsler, trykk kort → detail-sheet → **Avvis**
- [ ] Alert "Avvise forespørselen?" → Avvis
- [ ] Supabase: `status=cancelled`, `cancellation_reason=host_declined`
- [ ] Stripe: PI canceled (grå)
- [ ] **Kim-device:** push "Forespørselen ble avvist"
- [ ] **Kim-innboks:** avslags-e-post ← **build 9 R6 (decline-e-post await-fiks)**

---

## 7. Auto-decline (valgfri) — 3 min

- [ ] Kim lager ny booking
- [ ] SQL: sett deadline tilbake i tid
  ```sql
  update bookings set approval_deadline = now() - interval '1 hour'
  where id = '<booking-id>';
  ```
- [ ] Trigg cron manuelt (bruk `www`-domene):
  ```bash
  curl -H "Authorization: Bearer $CRON_SECRET" \
    https://www.tuno.no/api/cron/auto-decline-bookings
  ```
- [ ] Verifiser: `status=cancelled`, `cancellation_reason=auto_declined_timeout`
- [ ] Kim får push + e-post

---

## 8. Instant-booking regresjon — 3 min

- [ ] Lag (eller gjenbruk) annonse med `instant_booking=true`
- [ ] Kim booker denne
- [ ] Status går rett til `confirmed` (ingen forespørsel)
- [ ] PI captured umiddelbart
- [ ] Bookingen vises **ikke** i host sin Forespørsler-tab
- [ ] Kim får "Booking bekreftet"-push + e-post med en gang

---

## 9. Reviews (Fase 2B) — 5 min

Bruker godkjent booking fra seksjon 1.

- [ ] SQL: flytt `check_out` til i går for å simulere fullført opphold
  ```sql
  update bookings set check_out = current_date - interval '1 day'
  where id = '<booking-id>';
  ```
- [ ] Kim → dashboard → "Anmeld" på bookingen → skriver guest-review
- [ ] Supabase `reviews`: rad med `reviewer_role='guest'`
- [ ] Host ser IKKE reviewen ennå (blind til begge har levert)
- [ ] Host → **web** `tuno.no/dashboard` → booking-kort → "Anmeld gjesten" → skriver host-review
  - Merk: host-review mangler fortsatt i iOS, kommer i senere sprint
- [ ] Etter begge har skrevet:
  - Begge ser hverandres
  - `profiles.rating` + `review_count` oppdateres
  - `listings.rating` oppdateres (kun guest-reviews teller)
- [ ] Kim booker på nytt → host ser Kim sin rating (ikke "Ny gjest") på forespørselskortet

---

## 10. Host-dashboard drill-down (Fase 2C) — 5 min

### Web
- [ ] `tuno.no/dashboard` → Mine annonser → klikk test-annonsen
- [ ] `/dashboard/annonse/[id]` laster
- [ ] Stats: belegg 30d + 90d, inntekt 30d + 90d
- [ ] Inntekt = host-andel (korrekt formel etter build 11 payout-fiks, ikke `total*0.9`) ← **build 11 R10**
- [ ] Tabell med kommende bookinger
- [ ] Per-plass-grid
- [ ] Klikk en plass → `/dashboard/annonse/[id]/plass/[spotId]`
- [ ] Kalender: grønn = booket, grå = blokkert
- [ ] Marker noen datoer → **Lagre blokkering**
- [ ] Reload → datoer fortsatt blokkert
- [ ] Kim: prøv å booke de blokkerte datoene → blokkert

### iOS
- [ ] Host → Mine annonser → klikk annonse → HostListingStatsView
- [ ] Samme tall som web
- [ ] Per-plass-grid speiler web
- [ ] Drill ned → HostSpotDetailView → blokker datoer via iOS
- [ ] Verifiser: datoer reflekteres på web

---

## Blockere funnet under demo

> Logg her mens dere tester. Fikser etter demoen, ikke midt i.

- [ ]
- [ ]
- [ ]

---

## Etter demoen

- [ ] Triagering: kritisk / kan-vente / ikke-blocker
- [ ] Hvis TestFlight: Archive build 12 + push til Kim + andre testere
- [ ] Hvis blockere: fiks → ny build → re-invite
- [ ] Hvis alt grønt: **klar for App Store-submit** (avhengig av launch-scope: payments, admin, osv.)

---

## Quick-recap: alle dagens fiks

| Commit | Hva |
|---|---|
| `2e17590` | fix: webhook host-push await |
| `b9c1a24` | fix: fire-and-forget await overalt (4 filer) |
| `cd41876` | ios build 10: Airbnb-paritet, Se gjennom-sheet, sort, push-routing |
| `96c9f23` | fix: payout-formel (`split_host_and_fee` helper) |
| `522a052` | ios build 11: Profil-badge + avatar-upload + pris-oppdeling |
| `2bc4211` | ios build 12: Meldinger-perf + bildecache + språk-UX + Innstillinger |
| `7977c31` | fix: kamera-badge ikke kuttet av avatar-sirkel |
| `c52ff20` | ios: Xcode-reformat xcstrings |
