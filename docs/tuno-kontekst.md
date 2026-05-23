# Tuno — felles kontekst

Sist oppdatert: 2026-05-22

Dette dokumentet er en felles arbeidskontekst for Harald og Kim. Tanken er at vi laster det opp i den delte Google Drive-mappen "tuno" slik at begge sine Claude-instanser kan hente det ned og jobbe ut fra samme grunnlag — spesielt nå som vi starter ringerunden mot potensielle utleiere i Lofoten og Nord-Norge.

---

## 1. Hva er Tuno?

**Tuno er Airbnb for parkering og bobil-/campingplasser i Norge.**

- Privatpersoner og profesjonelle utleiere leier ut plasser direkte til reisende
- Web: [tuno.no](https://tuno.no)
- iOS-app: "Tuno: Bobil og parkering" — live på App Store siden 21. mai 2026
- Android: ikke ennå (kommer senere)
- Språk: norsk, engelsk, tysk (DeepL-oversatt + manuell kvalitetssikring)

### To bruksområder
1. **Pendlerparkering** — særlig Oslo, hvor garasjeplasser/oppkjørsler leies ut til daglig parkering
2. **Bobil/camping-turisme** — særlig Nord-Norge, hvor private tomter og småbruk tilbyr overnatting til bobiler og campingvogner

### Kjøretøytyper vi støtter
- Bobil (default)
- Campingvogn / campervan
- Personbil

Plasser kan være "alt-i-ett" (godt egnet for bobil) eller mer spesifikke (kun bil).

---

## 2. Hvorfor er dette interessant for en utleier i Lofoten/Nord-Norge?

### Markedet
- **Bobilturismen i Nord-Norge eksploderer.** Lofoten alene tar imot enorme mengder utenlandske besøkende hver sommer. Mange leter etter overnattingsplasser utenom de tradisjonelle campingplassene.
- **Bobil-eierne vil ha autentiske opplevelser** — utsikt mot havet, ro, nær lokale severdigheter — ikke nødvendigvis stor camping med basseng.
- **Tilbudet er fragmentert.** I dag må reisende søke i Facebook-grupper, sende DM-er, eller bare prøve seg fram. Tuno samler tilbudet.

### Verdi for utleier
- **Tjen penger på plass du allerede har** — tomten, tunet, jordet, parkeringsplassen
- **Du bestemmer selv** — pris, regler, tilgjengelighet, hvilke kjøretøy du tar imot
- **Daglig utbetaling** via Stripe (rett til din konto, ikke noe venting)
- **Vi tar oss av kortbetaling, kontrakt, kommunikasjon** — utleier slipper å håndtere Vipps-MobilePay-rot
- **Gratis å opprette annonse** — vi tjener kun når du tjener (provisjon på toppen av din pris)

### Hvem passer det for?
- Småbrukseiere med plass på tunet
- Hytteeiere med stor parkering / oppstillingsplass
- Profesjonelle (campingplasser som vil ha ekstra distribusjonskanal)
- Folk med plass langs vei med utsikt
- Bensinstasjon-/butikkeiere med ledig plass

---

## 3. Tuno-flyten for en utleier

1. **Last ned appen** (iOS) eller gå til tuno.no
2. **Lag konto** (Apple, Google eller e-post)
3. **Trykk "Bli utleier"** — wizard på 8 steg:
   1. Kategori (parkering / camping) + kjøretøytype
   2. Detaljer (tittel, beskrivelse)
   3. Lokasjon (adresse + markere plasser på satellittkart, valgfritt "skjul eksakt adresse")
   4. Bilder (drag & drop)
   5. Fasiliteter (strøm, vann, toalett, dusj, wifi, etc.)
   6. Pris (per døgn for camping, per dag for parkering)
   7. Tilgjengelighetskalender
   8. Gjennomgang
4. **Stripe Connect-onboarding** — krever fødselsnummer + bankkonto (kjøres når første booking er på vei)
5. **Gjør seg klar** — annonsen går live, plasseres i søk og kart

### Når en gjest booker
- Push og e-post til utleier
- Utleier kan bekrefte (eller "Instant booking" om de har slått det på)
- Penger reserveres på gjestens kort
- Etter check-out: penger overføres til utleiers konto neste virkedag
- Tuno tar provisjon (legges på toppen av utleiers pris — gjesten betaler den, ikke utleier)

---

## 4. Pris-modellen (viktig å forklare riktig)

**Tunos provisjon legges PÅ TOPPEN av utleiers pris** — utleier får alltid 100 % av sin oppgitte pris.

Eksempel:
- Utleier setter prisen til 300 kr/døgn
- Gjest betaler ca. 330 kr (300 + Tunos service-fee)
- Utleier får 300 kr utbetalt
- Tuno får 30 kr

Dette gjør det enkelt å selge inn: "Du får det du oppgir. Vi tjener på dem som booker, ikke på deg."

---

## 5. Kontaktargumenter for ringerunden

### Åpning
"Hei, dette er [Harald/Kim] fra Tuno. Vi har laget en plattform for å leie ut parkering og bobilplasser — som Airbnb, men for plasser. Vi lanserte appen forrige uke, og vi har sett at Nord-Norge / Lofoten er et område hvor det er stor etterspørsel etter denne typen overnatting. Har du noen minutter?"

### Trigger-spørsmål
- Har du opplevd at bobil-folk har spurt deg om å parkere over natten?
- Har du tomt eller plass som ikke brukes i sommerhalvåret?
- Har du tenkt på å leie ut, men ikke ville rote med Facebook-DM-er, kontant, eller papirer?

### Vanlige innvendinger
- **"Hva med ansvar/forsikring?"** → Tuno krever at gjesten oppgir kortdetaljer og gjennomgår booking-betingelser. Du som utleier setter selv reglene. Vi jobber med å integrere en frivillig forsikringsmodul, men i utgangspunktet er det det samme som om noen booker en hytte/campingplass.
- **"Hva med skatt?"** → Vi rapporterer ikke automatisk, men du får full oversikt over utbetalinger i appen som du kan bruke i selvangivelsen. For mer enn ca. 10.000 kr/år i utleieinntekt anbefaler vi å snakke med regnskapsfører.
- **"Hva hvis ingen booker?"** → Det koster ingenting å ha annonsen liggende. Du har ikke noe å tape.
- **"Er det vanskelig å bli registrert?"** → 10 minutter i appen. Vi har norsk kundestøtte (Harald + Kim).
- **"Hva med konkurranse fra campingplasser?"** → Vi er ikke en konkurrent til campingplasser — vi er et alternativ for de som ønsker en mer rustikk/autentisk plass. Mange bobilister booker begge deler på samme ferie.

### Lukk
"Jeg kan hjelpe deg å sette opp annonsen nå over telefon hvis du har 15 minutter. Eller jeg kan sende deg en lenke + en kort video, så kan du gjøre det selv senere."

---

## 6. Tekniske/operasjonelle fakta

- **Stiftet:** Tuno er foreløpig drevet privat av Harald. AS-stiftelse er planlagt (gir EU-distribusjon via App Store DSA Trader-status).
- **Live-land:** Norge, Sverige, Danmark, Finland, Island, Storbritannia, Sveits (per 21. mai 2026). 8 EU-land aktiveres så snart AS er stiftet.
- **Betaling:** Stripe + Vipps (Vipps i private preview-fase, ikke fullt live ennå).
- **Verifikasjon:** Vi krever Stripe Identity-verifisering for utleiere (legitimasjon) før utbetaling.
- **Brand:** Mint-grønn `#46C185`, navn "Tuno" (tidligere "Free Space", "SpotShare").
- **Domene:** [tuno.no](https://tuno.no)

---

## 7. Kontakt / ressurser

- **Tuno.no** — webversjonen
- **App Store:** "Tuno: Bobil og parkering"
- **E-post:** harald@tuno.no (admin)
- **Eier:** Harald Ulvestad Salvesen
- **Co-tester:** Kim Cederstrøm

---

## 8. Status (per 22. mai 2026)

- ✅ iOS-app live på App Store i 7 land, 8 EU-land klar for aktivering
- ✅ Webversjon live på tuno.no
- ✅ Stripe Connect Custom — kortbetaling fungerer, daglige utbetalinger
- ✅ i18n: norsk, engelsk, tysk
- ⏳ Vipps (private preview, venter Stripe Support)
- ⏳ Trader-status (venter AS-stiftelse)
- ⏳ Ringerunde Lofoten/Nord-Norge — **starter nå**
- ⏳ Annonsering / launch-PR
- ⏳ Reviews/ratings-system
- ⏳ Sign-in with Apple-fix + UGC moderation (post-launch oppfølging)

---

## 9. Hvordan oppdatere denne filen

Begge har redigeringsrettigheter på Google Drive-mappen "tuno". Når noe endrer seg vesentlig:
1. Last ned dokumentet
2. Be Claude (din lokale instans) oppdatere relevante seksjoner
3. Last opp på nytt — overskriv eksisterende versjon
4. Si fra til den andre i Slack/Messenger så vi vet å hente ny versjon
