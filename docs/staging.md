# Tuno staging-miljø

Eget speil av prod for trygg testing — ingen ekte penger, ingen
ekte brukere, ingen risiko for å forstyrre live-kunder.

## Oppsummering

| Komponent | Prod | Staging |
|---|---|---|
| Web-domene | tuno.no | staging.tuno.no |
| Git-branch | master | staging |
| Vercel env | Production | Preview (staging-branch override) |
| Supabase-prosjekt | mqyeptwrfrhwxtysccnp | egen branch fra Dashboard |
| Stripe | Live mode | Test mode |
| iOS-bundle | no.tuno.app | no.tuno.app.staging |
| iOS-scheme | Tuno | Tuno-Staging |
| iOS-ikon | Grønt pin | Grønt pin + oransje "STG" hjørne |
| TestFlight-gruppe | Gutta | Staging |
| APNs | production | development |

## Hvordan deploye en endring til staging

```bash
git checkout staging
git merge master            # eller cherry-pick spesifikke commits
git push origin staging     # Vercel deployer automatisk til staging.tuno.no
```

For å pushe en ny iOS staging-build til TestFlight:

```bash
cd TunoApp
xcodegen generate
open Tuno.xcodeproj
# I Xcode: Product → Scheme → Tuno-Staging
#         Product → Archive → Distribute → TestFlight
```

## Hvordan sette opp staging fra null (en gang)

Gjøres bare første gang. Når disse er på plass kan både Harald og
Claude jobbe mot staging via vanlige git-pushes.

### 1. Supabase branching
- Logg inn https://supabase.com/dashboard/project/mqyeptwrfrhwxtysccnp
- Settings → Branching → "Enable Branching"
- Branches → "+ New Branch" → navn: `staging`
- Vent 1–2 min på at branchen provisjones
- Kopier den nye URL-en (https://<staging-ref>.supabase.co) + anon-key + service-role-key

### 2. DNS for staging.tuno.no
- Logg inn Uniweb
- Legg til DNS-record:
  - Type: CNAME
  - Navn: `staging`
  - Verdi: `cname.vercel-dns.com`
  - TTL: default
- Vent 5–60 min på propagering

### 3. Vercel preview-environment
- Vercel Project (free-space) → Settings → Domains → "Add"
- `staging.tuno.no` → "Assign to Git Branch: staging"
- Settings → Environment Variables — legg til OVERRIDE for "Preview" (Branch: staging):

| Variabel | Verdi |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | staging-Supabase-URL fra steg 1 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | staging-anon |
| `SUPABASE_SERVICE_ROLE_KEY` | staging-service-role |
| `STRIPE_SECRET_KEY` | sk_test_... fra Stripe (steg 4) |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | pk_test_... |
| `STRIPE_WEBHOOK_SECRET` | whsec_... (test-webhook fra steg 4) |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | whsec_... (test-Connect-webhook) |
| `APNS_BUNDLE_ID` | `no.tuno.app.staging` |
| `APNS_PRODUCTION` | `false` (sandbox) |
| `CRON_SECRET` | (ny tilfeldig streng, ikke samme som prod) |
| `RESEND_API_KEY` | (samme — vi gjenbruker Resend-konto) |
| `GOOGLE_CLOUD_VISION_API_KEY` | (samme — bildemoderering kjører likt) |

### 4. Stripe test mode
- Stripe Dashboard → toggle "Viewing test data" (knapp øverst)
- Developers → API keys → kopier `pk_test_...` og `sk_test_...`
- Developers → Webhooks → "+ Add endpoint":
  - URL: `https://staging.tuno.no/api/webhooks/stripe`
  - Events: `payment_intent.amount_capturable_updated`,
    `payment_intent.succeeded`, `payment_intent.payment_failed`,
    `account.updated`
  - Kopier signing secret → STRIPE_WEBHOOK_SECRET
- Lag enda en webhook for Connect:
  - Samme URL, type "Connect"
  - Events: `account.updated`
  - Kopier signing secret → STRIPE_CONNECT_WEBHOOK_SECRET

### 5. Apple Developer Console
- developer.apple.com → Certificates, Identifiers & Profiles → Identifiers
- "+" → App IDs → App
  - Description: "Tuno Staging"
  - Bundle ID: explicit, `no.tuno.app.staging`
  - Capabilities: Sign in with Apple, Push Notifications, Apple Pay,
    Associated Domains
- Lag provisioning profile (eller la Xcode auto-manage)

### 6. App Store Connect
- App Store Connect → My Apps → "+" → New App
  - Platform: iOS
  - Bundle ID: `no.tuno.app.staging`
  - Name: "Tuno Staging" (kun synlig internt — ikke i App Store)
  - SKU: `tuno-staging`
- TestFlight → "+ Add External Group" → "Staging"
- Inviter deg + Kim

### 7. Oppdater iOS-konfigurasjon
Etter at Supabase staging-branch er klar (steg 1):

```swift
// TunoApp/Tuno/Services/SupabaseService.swift
#if STAGING
static let supabaseURL = URL(string: "https://<staging-ref>.supabase.co")!  // ← oppdater
static let supabaseAnonKey = "<staging-anon-key>"  // ← oppdater
#endif
```

Commit + push til staging-branch.

### 8. Universal Links — verifiser
- Apple cacher AASA aggressivt. Etter at staging er live, sjekk:
  ```
  curl -I https://staging.tuno.no/.well-known/apple-app-site-association
  ```
  Skal returnere 200 + Content-Type application/json
- Trigger Apple's CDN-refresh ved å åpne en universal link på en
  staging-installert iOS-enhet

## Test-data

### Stripe test-kort (Stripe har faste test-numre)
| Scenario | Kortnummer |
|---|---|
| Suksess | `4242 4242 4242 4242` |
| Krever 3D Secure | `4000 0027 6000 3184` |
| Insufficient funds | `4000 0000 0000 9995` |
| Card declined | `4000 0000 0000 0002` |

CVV: hvilket som helst 3-sifret. Utløpsdato: hvilken som helst fremtidig.

### Stripe Connect test-onboarding
- Test-personnummer: `30099999700` (godkjennes alltid)
- Test-IBAN (NO): `NO9386011117947`
- Test-telefon: `+4799999999`

### Reset staging-DB
Hvis test-data blir rotete:
```bash
supabase db reset --linked  # nullstiller staging-branch til seneste migration
```
Eller via Dashboard → Branches → Reset.

## Hva som er felles mellom prod og staging

- **Resend (e-post)**: vi gjenbruker samme API-key. Mail som sendes
  fra staging kommer fra `noreply@tuno.no` (samme avsender som prod).
  Til testing er det helt OK.
- **Google Maps key**: samme key, men Cloud Console må whiteliste
  begge bundles (no.tuno.app + no.tuno.app.staging).
- **Apple Pay merchant-ID**: deler `merchant.no.tuno.app` mellom prod
  og staging. Apple aksepterer dette; testmodus styres av Stripe-keys.
- **Supabase Auth-providers**: må konfigureres separat per branch
  (Google OAuth-credentials kan trenge ny redirect-URI for
  staging.tuno.no).
