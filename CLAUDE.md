@AGENTS.md

# Free Space — Prosjektkontekst

## Visjon
"Free Space" — Airbnb for parkering og camping/bobilplasser i Norge.
Løser parkeringsmangel for pendlere (f.eks. Oslo) og camping/bobil-turisme (f.eks. Nord-Norge) ved å la private og profesjonelle utleiere leie ut plasser.

**Fase:** PoC — må se polert og profesjonelt ut, Airbnb-inspirert design.
**Mål:** Også lage en app (mobil) ut av dette.

## Eier
- Harald (GitHub: haraldulv, e-post: harald.ulvestad.salvesen@gmail.com)
- Kommuniserer på norsk, foretrekker norske svar
- Visuelt orientert — bruker screenshots som referanse (Airbnb)
- Foretrekker raske resultater og korte iterasjoner

## Deployment
- **GitHub:** https://github.com/haraldulv/free-space (public, master branch)
- **Vercel:** auto-deploys on push
- **Env vars:** NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
- **Google Cloud:** Maps JavaScript API + Places API + OAuth (project "Free Space")
- **Password gate:** sessionStorage, passord "kimharald" (PasswordGate.tsx wraps root layout)

## Tech Stack
- Next.js 16 (App Router) + TypeScript
- Tailwind CSS v4 (CSS-basert config i globals.css)
- Supabase (auth + PostgreSQL + RLS + Storage)
- Google Maps (@googlemaps/js-api-loader v2, warm Airbnb-style, OverlayView price bubbles)
- DM Sans font (Google Fonts)
- react-day-picker v9, date-fns, zod v4, lucide-react

## Supabase
- **Prosjekt:** mqyeptwrfrhwxtysccnp.supabase.co (Region: West EU / Frankfurt)
- **Auth:** Google OAuth + email/password. Auto-profile creation i createListing om profil mangler.
- **Tabeller:** profiles, listings (med instant_booking, spot_markers jsonb, hide_exact_location bool, is_active bool, blocked_dates jsonb, vehicle_type text), bookings, favorites — alle med RLS
- **Storage:** `listing-images` bucket (public, 5MB limit, jpg/png/webp)
- **524+ listings** seeded (alle vehicle_type='motorhome') + bruker-opprettede

## Design-preferanser
- **Fargepalett:** Ren blå (#1a4fd6 primary-600, #3366ff primary-500)
- DM Sans font, logo: "free*space*" (extralight + bold italic, svart)
- Alt UI-tekst på norsk (lang="nb")
- **Ikke bruk:** grønn ("kjedelig"), charcoal ("for kjedelig"), coral/rød, sage, jord-toner
- Blått skal være moderne og rent, ikke corporate
- Logo: kun tekst, ingen ikoner, ingen to-farget tekst. "Hip and modern, Grünerløkka vibes"
- Kort skal alltid ha synlig border, subtil hover-effekt, ikke "hjemmesnekra"
- Glassmorphism navbar kun på forsiden, solid hvit ellers
- "Bli utleier" ikke "Bli vert"
- Navbar: ingen stor avatar i hamburgermenyen
- Søkefelt: må ikke hoppe/endre høyde ved klikk. Aktiv segment: Airbnb-stil (hvit bg + shadow, resten grå)

## Tekniske regler og gotchas
- **Test lokalt** (npm run dev) før commit og push. Ikke push utestet kode.
- **Server actions i Next.js 16:** Ikke throw fra server actions — returnerer `{ error?: string }` objekter. Client sjekker result.error.
- **Post-action navigasjon:** Bruk `window.location.href` istedenfor `router.push` etter server actions.
- **Kalendere:** weekStartsOn=1 (mandag først)
- **Søk-navigasjon:** window.location.href for pålitelig full-page refresh

## Implementert (per 2026-03-26)

### Søk
- Google Places Autocomplete i søkefelt (custom dropdown, restricted to Norway)
- Radius-søk: geocode → Haversine filter (20km default), sortert etter avstand
- Datofilter: checkIn/checkOut via URL params, ekskluderer listings med blocked_dates
- Kjøretøytype-filter: Bobil (default), Campingbil, Personbil. Hierarki: Bobil-plasser tar alle, Campingbil tar campervan+bil, Personbil kun bil
- Kjøretøyikon ved valgt type i søkefelt
- **Søkekort:** border, image carousel, ⚡ grønn instant booking badge, bil/plasser count, hjerte-favorittknapp øverst til høyre

### Kart
- Warm Airbnb-style Google Maps
- **Bobler:** hvite pills med fet pris, hvit glow ring, ⚡ grønn for instant booking, "Xp" for plasser, svart on hover
- **Popup:** custom kort med image carousel, tittel, rating, pris, klikkbar til annonse

### "Bli utleier" (/bli-utleier)
- Auth-guarded via middleware (redirects tilbake etter login)
- **8-stegs wizard:** Kategori + Kjøretøy → Detaljer → Lokasjon (Places Autocomplete + spot markers + privacy toggle) → Bilder (Supabase Storage drag&drop) → Fasiliteter → Pris → Tilgjengelighetskalender → Gjennomgang
- Lokasjon: satellittkart, "Marker plasser"-modus med nummererte draggable pins, "Skjul eksakt adresse"-toggle
- Server actions: createListingAction, updateListingAction, deleteListingAction, toggleListingActiveAction, updateBlockedDatesAction i actions.ts

### Rediger annonse (/bli-utleier/rediger/[id])
- Tab-basert layout (ikke wizard): Detaljer, Lokasjon, Bilder, Fasiliteter, Pris, Tilgjengelighet
- "Lagre endringer"-knapp

### Favoritter
- Hjerte-ikon på søkekort og detalj-side
- Toggle via lib/supabase/favorites.ts
- Optimistic UI
- Dashboard "Favoritter"-tab

### Dashboard (/dashboard)
- Tre tabs: "Mine bestillinger", "Favoritter", "Mine annonser"
- HostListingCard: bilde + info klikkbar, toggle aktiv/inaktiv (øyeikon), rediger (blyant), slett (søppel)
- Inaktive annonser: overlay + redusert opacity, skjult fra søk

### Navbar
- Innlogget: Mine bestillinger, Favoritter, Mine annonser (om host), Bli utleier (om ikke host), Innstillinger, Logg ut — alle med ikoner
- Ikke innlogget: Logg inn, Registrer deg, Bli utleier
- "Bli utleier" desktop-lenke kun for ikke-hosts

### Annonse-detaljside (/listings/[id])
- Bildegalleri, badges, beskrivelse, fasiliteter, utleier-kort, BookingForm
- Google Maps med nummererte spot markers (satellitt) eller sirkel om lokasjon skjult
- Favorittknapp ved tittel

### Auth
- Google OAuth + email/password
- Middleware: ?redirectTo= på beskyttede ruter
- Login/Register: preserverer redirectTo mellom seg
- OAuth callback håndterer ?next= param

## Filstruktur
```
app/layout.tsx                     — Root: DM Sans, PasswordGate
app/globals.css                    — Tailwind v4 theme, animasjoner, Google Maps overrides
app/(main)/layout.tsx              — Auth state + isHost → Navbar, skjuler footer på /search
app/(main)/page.tsx                — Forside
app/(main)/search/page.tsx         — Søk med Google Maps + filtre
app/(main)/dashboard/page.tsx      — Bestillinger + favoritter + annonser tabs
app/(main)/bli-utleier/page.tsx    — Opprett annonse wizard
app/(main)/bli-utleier/actions.ts  — Server actions for CRUD + toggle + blocked dates
app/(main)/bli-utleier/rediger/[id]/page.tsx — Rediger annonse (tab-basert)
app/(main)/listings/[id]/page.tsx  — Annonse-detalj + kart + favoritt
app/(auth)/                        — Login, register, forgot/reset password
app/auth/callback/route.ts         — OAuth callback med ?next= redirect
lib/supabase/client.ts             — Browser Supabase client
lib/supabase/server.ts             — Server Supabase client
lib/supabase/listings.ts           — Queries + CRUD + Haversine avstandssøk
lib/supabase/favorites.ts          — getUserFavorites, toggleFavorite
lib/supabase/storage.ts            — Image upload/delete
lib/supabase/middleware.ts         — Auth middleware med redirectTo
components/features/listing-form/  — ListingFormWizard (8 steps), StepIndicator, AvailabilityEditor
components/features/Navbar.tsx     — Auth-aware, ikoner, isHost-logikk
components/features/SearchBar.tsx  — Google Places, datepicker, kjøretøyfilter
components/features/FavoriteButton.tsx     — Hjerte-toggle (søkekort)
components/features/ListingFavoriteButton.tsx — Hjerte-toggle (detaljside)
components/features/ListingMap.tsx  — Google Maps for annonse-detalj
components/features/BookingForm.tsx — Datovelger med blocked dates
components/features/search/        — SearchResultsView, SearchListingCard, SearchMap
components/features/HostListingCard.tsx — Dashboard-kort med toggle, rediger, slett
types/index.ts                     — Listing, SpotMarker, Amenity, VehicleType, vehicleFitsIn
```

## Neste steg (prioritert)
1. **App-versjon** — React Native / Expo for mobil
2. **Betalingsløsning** — Stripe eller Vipps?
3. **Innstillinger-side** — /settings (lenket fra hamburgermenyen, gir 404 nå)
4. **Responsive audit, mobile polish**
5. **Reviews/ratings system**
6. **Booking availability** — vis X/Y plasser tilgjengelig basert på aktive bookinger
