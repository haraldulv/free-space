# Staging-oppsett — manuell sjekkliste for Harald

Det meste av kode-arbeidet er gjort. Disse stegene kan KUN du gjøre
fordi de krever innlogging i ulike dashboards. Følg i rekkefølge —
hvert steg gir output som brukes i neste.

Estimat for å gjøre denne lista: ca. 1–1,5 time + venting på DNS.

---

## ☐ 1. Supabase login (lokalt) — 1 minutt

I terminalen:
```bash
supabase login
```
Browser åpnes, logg inn med din Supabase-konto. Når dette er gjort kan
Claude kjøre `supabase db pull` neste gang for å lage migrations-baseline.

---

## ☐ 2. Supabase: Aktiver branching + lag staging-branch — 5 min

1. https://supabase.com/dashboard/project/mqyeptwrfrhwxtysccnp
2. Settings → Branching → "Enable Branching"
   (krever Pro-plan, du har det)
3. Branches (sidebar) → "+ New Branch"
   - Branch name: `staging`
   - Source branch: `main` (production)
4. Vent 1–2 min på at branchen provisjones
5. Når klar, klikk inn på branchen og kopier:
   - **Project URL** (ser ut som `https://abc123def.supabase.co`)
   - **anon (public) key**
   - **service_role key**

Disse bruker vi i steg 4 (Vercel env vars).

---

## ☐ 3. Stripe: Test-mode webhook setup — 10 min

1. https://dashboard.stripe.com/test (sørg for at "Viewing test data" er PÅ)
2. Developers → API keys
   - Kopier `Publishable key` (pk_test_...)
   - Reveal + kopier `Secret key` (sk_test_...)
3. Developers → Webhooks → "+ Add endpoint" (PLATFORM type)
   - Endpoint URL: `https://staging.tuno.no/api/webhooks/stripe`
   - Events to send (velg disse):
     - `payment_intent.amount_capturable_updated`
     - `payment_intent.succeeded`
     - `payment_intent.payment_failed`
   - Etter opprettelse: kopier "Signing secret" (whsec_...)
4. Developers → Webhooks → "+ Add endpoint" (CONNECT type)
   - Toggle "Listen to events on Connected accounts"
   - Endpoint URL: `https://staging.tuno.no/api/webhooks/stripe` (SAMME URL)
   - Events to send: `account.updated`
   - Kopier "Signing secret"

Du har nå:
- pk_test_...
- sk_test_...
- whsec_... (platform)
- whsec_... (connect)

---

## ☐ 4. DNS: staging.tuno.no — 5 min + venting

1. Logg inn på Uniweb (eller hvor enn du administrerer tuno.no DNS)
2. Legg til DNS-record:
   - Type: **CNAME**
   - Navn: `staging`
   - Verdi: `cname.vercel-dns.com`
   - TTL: default (3600 eller lavere)
3. DNS-propagering tar 5–60 min. Du kan gå videre — Vercel detekterer
   når DNS er klar.

---

## ☐ 5. Vercel: Domene + env vars — 15 min

### 5a. Legg til staging-domenet
1. https://vercel.com/haralds-projects-65742e31/free-space/settings/domains
2. "Add Domain" → `staging.tuno.no`
3. Når Vercel spør: "Assign to Git Branch" → velg `staging`
4. Vercel verifiserer DNS automatisk (kan trenge refresh hvis du nettopp
   la inn CNAME)

### 5b. Sett environment variables
Gå til Settings → Environment Variables. For HVER variabel under
oppretter du en NY entry hvor du:
- Setter "Environments" til **kun "Preview"**
- Trykker "Configure" og spesifiserer Branch = `staging`

(Vercel støtter "Branch-spesifikke env-overrides under Preview" — det er
det vi ønsker.)

| Variabel | Verdi |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | staging-URL fra steg 2 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | staging anon-key fra steg 2 |
| `SUPABASE_SERVICE_ROLE_KEY` | staging service-role fra steg 2 |
| `STRIPE_SECRET_KEY` | sk_test_... fra steg 3 |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | pk_test_... fra steg 3 |
| `STRIPE_WEBHOOK_SECRET` | whsec_... (platform) fra steg 3 |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | whsec_... (connect) fra steg 3 |
| `APNS_BUNDLE_ID` | `no.tuno.app.staging` |
| `APNS_PRODUCTION` | `false` |
| `CRON_SECRET` | Generer ny tilfeldig (åpne et terminal-vindu og kjør `openssl rand -hex 32`) |
| `RESEND_API_KEY` | Kopiér fra Production (samme verdi) |
| `GOOGLE_CLOUD_VISION_API_KEY` | Kopiér fra Production |
| `APNS_KEY_P8` | Kopiér fra Production (samme APNs-key, fungerer for både dev og prod env) |
| `APNS_KEY_ID` | Samme som Production |
| `APNS_TEAM_ID` | Samme som Production (3VD2DMBJ6M) |

### 5c. Trigger første staging-deploy
```bash
git push origin staging      # I terminalen, fra repo-roten
```
Vercel deployer automatisk til staging.tuno.no.

---

## ☐ 6. Apple Developer Console: Ny App ID — 10 min

1. https://developer.apple.com/account/resources/identifiers/list
2. "+" → App IDs → App
3. Description: `Tuno Staging`
4. Bundle ID: explicit, `no.tuno.app.staging`
5. Capabilities (kryss av):
   - ☑ Sign in with Apple
   - ☑ Push Notifications
   - ☑ Apple Pay Payment Processing (legg til samme merchant: `merchant.no.tuno.app`)
   - ☑ Associated Domains
6. Continue → Register

(Provisioning profile lager Xcode automatisk når du archiver.)

---

## ☐ 7. App Store Connect: Ny app + TestFlight-gruppe — 10 min

1. https://appstoreconnect.apple.com/apps → "+"
2. New App
   - Platforms: iOS
   - Name: `Tuno Staging` (kan endres senere, kun synlig internt)
   - Primary Language: Norwegian (Bokmål)
   - Bundle ID: `no.tuno.app.staging` (vises i dropdown etter steg 6)
   - SKU: `tuno-staging`
3. Etter opprettelse: TestFlight (tab) → Internal Testing
   - "+" → External Testing → New Group
   - Group Name: `Staging`
   - Legg til testere: deg + Kim
4. Når første staging-build er archived og pushet, vil den dukke opp her
   for godkjenning til ekstern testing

---

## ☐ 8. Oppdater iOS-koden med faktiske staging-keys

Etter at steg 2 er gjort, skal du eller jeg oppdatere
`TunoApp/Tuno/Services/SupabaseService.swift`:

```swift
#if STAGING
static let supabaseURL = URL(string: "https://STAGING-REF.supabase.co")!  // ← bytt
static let supabaseAnonKey = "STAGING_ANON_KEY_PLACEHOLDER"  // ← bytt
static let siteURL = "https://staging.tuno.no"
#endif
```

Gi beskjed om de faktiske verdiene, så committer Claude.

---

## ☐ 9. Første staging-build til TestFlight

1. `cd TunoApp && xcodegen generate`
2. `open Tuno.xcodeproj`
3. Velg scheme `Tuno-Staging` (toppen ved Play-knappen)
4. Product → Archive
5. Distribute App → TestFlight & App Store
6. Vent på prosessering på App Store Connect
7. Tildel build til Staging-gruppen

---

## ☐ 10. Verifiser end-to-end

- [ ] Åpne staging.tuno.no i nettleser → side laster
- [ ] Registrer ny test-bruker → e-post-verifisering kommer
- [ ] Opprett test-listing (host) → ser den i søk
- [ ] Som annen test-bruker, book med Stripe test-kort `4242 4242 4242 4242`
- [ ] Sjekk Stripe Dashboard test mode → PaymentIntent + Connect transfer
- [ ] iOS staging-app installert via TestFlight → push fungerer
- [ ] Test cron: `curl -H "Authorization: Bearer $STAGING_CRON_SECRET" https://staging.tuno.no/api/cron/process-payouts`

---

## Når alt er klart

Si fra til Claude — vi flytter videre med web-paritet eller andre punch-list-saker.
Heretter kan vi cherry-picke til staging først (`git checkout staging && git
cherry-pick <sha> && git push`) for å teste, så merge til master når
bekreftet OK.
