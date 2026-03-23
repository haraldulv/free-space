import type { Listing, Amenity, Host, ListingTag } from "@/types";

// --- Seed-based pseudo-random number generator (deterministic output) ---
function mulberry32(seed: number) {
  let s = seed;
  return () => {
    s |= 0;
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function generateListings(): Listing[] {
  const rand = mulberry32(42);

  // Helpers
  const pick = <T>(arr: T[]): T => arr[Math.floor(rand() * arr.length)];
  const randInt = (min: number, max: number) =>
    Math.floor(rand() * (max - min + 1)) + min;
  const randFloat = (min: number, max: number, decimals = 4) =>
    parseFloat((rand() * (max - min) + min).toFixed(decimals));
  const pickN = <T>(arr: T[], min: number, max: number): T[] => {
    const n = randInt(min, max);
    const shuffled = [...arr].sort(() => rand() - 0.5);
    return shuffled.slice(0, Math.min(n, arr.length));
  };

  // --- Image pools ---
  const parkingImages = [
    "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1486006920555-c77dcf18193c?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800&h=600&fit=crop",
  ];

  const campingImages = [
    "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1478827536114-da961b7f86d2?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&h=600&fit=crop",
    "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=800&h=600&fit=crop",
  ];

  // --- Hosts ---
  const hosts: Host[] = [
    { id: "gh1", name: "Erik Hansen", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&facepad=2", responseRate: 98, responseTime: "innen 1 time", joinedYear: 2022, listingsCount: 3 },
    { id: "gh2", name: "Ingrid Larsen", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&facepad=2", responseRate: 95, responseTime: "innen 2 timer", joinedYear: 2023, listingsCount: 1 },
    { id: "gh3", name: "Olav Moen", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&facepad=2", responseRate: 100, responseTime: "innen 30 min", joinedYear: 2021, listingsCount: 5 },
    { id: "gh4", name: "Kari Nilsen", avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop&facepad=2", responseRate: 92, responseTime: "innen 3 timer", joinedYear: 2023, listingsCount: 2 },
    { id: "gh5", name: "Anders Berg", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&facepad=2", responseRate: 88, responseTime: "innen 4 timer", joinedYear: 2024, listingsCount: 1 },
    { id: "gh6", name: "Siri Fjordheim", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&facepad=2", responseRate: 99, responseTime: "innen 1 time", joinedYear: 2021, listingsCount: 2 },
    { id: "gh7", name: "Magnus Nordland", avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&facepad=2", responseRate: 94, responseTime: "innen 2 timer", joinedYear: 2022, listingsCount: 3 },
    { id: "gh8", name: "Liv Hamar", avatar: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&h=100&fit=crop&facepad=2", responseRate: 97, responseTime: "innen 1 time", joinedYear: 2022, listingsCount: 1 },
    { id: "gh9", name: "Tor Johansen", avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&facepad=2", responseRate: 91, responseTime: "innen 2 timer", joinedYear: 2023, listingsCount: 4 },
    { id: "gh10", name: "Astrid Solberg", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&facepad=2", responseRate: 96, responseTime: "innen 1 time", joinedYear: 2021, listingsCount: 6 },
    { id: "gh11", name: "Per Lund", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&facepad=2", responseRate: 89, responseTime: "innen 3 timer", joinedYear: 2024, listingsCount: 2 },
    { id: "gh12", name: "Marte Vik", avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&facepad=2", responseRate: 93, responseTime: "innen 2 timer", joinedYear: 2022, listingsCount: 3 },
  ];

  // --- Norwegian street components ---
  const osloStreets = [
    "Kirkeveien", "Bogstadveien", "Thereses gate", "Ullevålsveien",
    "Grenseveien", "Trondheimsveien", "Sørkedalsveien", "Hoffsveien",
    "Drammensveien", "Bygdøy allé", "Frognerveien", "Pilestredet",
    "Josefines gate", "Industrigata", "Vibes gate", "Oscars gate",
    "Hegdehaugsveien", "Bislettgata", "Vogts gate", "Sandakerveien",
    "Maridalsveien", "Storgata", "Grünerløkka gate", "Torshov gate",
    "Sinsenveien", "Hasleveien", "Ensjøveien", "Gladengveien",
    "Alnabru terrasse", "Grorud gate", "Stovnerveien", "Furuset allé",
    "Lambertseter allé", "Nordstrandveien", "Ekebergveien", "Kongsveien",
  ];

  const tromsoStreets = [
    "Storgata", "Sjøgata", "Grønnegata", "Vestregata",
    "Bankgata", "Skippergata", "Havnegata", "Skolegata",
    "Kirkegata", "Fjordgata", "Kongsbakken", "Dramsvegen",
    "Tromsøysundvegen", "Kvaløyvegen", "Mellomveien", "Strandveien",
    "Skansen", "Gimlevegen", "Hansine Hansens veg", "Fløyvegen",
    "Bjerkaker gate", "Breiviklia", "Tomasjordvegen", "Reinen",
  ];

  const lofotenStreets = [
    "Fiskergata", "Havneveien", "Sjøveien", "Rorbuveien",
    "Strandveien", "Fjellveien", "Nordveien", "Sørveien",
    "Bryggeveien", "Torget", "Torgveien", "Vikveien",
    "Rambergveien", "Leknesveien", "Svolværveien", "Kabelvågveien",
    "Henningsvær gate", "Nusfjordveien", "Balstadveien", "Fredvangveien",
  ];

  // --- Title/description templates ---
  const parkingTitlePrefixes = [
    "Sentral Parkering", "Trygg Garasje", "Privat Oppkjørsel", "Innendørs Parkering",
    "Pendlerparkering", "Langtidsparkering", "Parkering Sentrum", "EV-parkering",
    "Gateparkering", "Parkeringshus", "Sikker Parkering", "Rolig Parkering",
    "Overbygget Parkering", "Døgnparkering", "Helgeparkering", "Parkering ved sentrum",
  ];

  const campingTitlePrefixes = [
    "Fjordcamp", "Naturplass", "Bobilparkering", "Villmarkcamp",
    "Utsiktsplass", "Strandcamp", "Skogcamp", "Fjellcamp",
    "Nordlyscamp", "Arktisk Camp", "Kystcamp", "Midnattsolcamp",
    "Havncamp", "Idyllisk Bobilplass", "Rolig Campingplass", "Eventyrcamp",
  ];

  const osloAreaNames = [
    "Majorstuen", "Grünerløkka", "Frogner", "Sagene", "St. Hanshaugen",
    "Torshov", "Bislett", "Løren", "Sinsen", "Hasle", "Ensjø", "Tøyen",
    "Grønland", "Kampen", "Vålerenga", "Lambertseter", "Nordstrand",
    "Ekeberg", "Grorud", "Stovner", "Furuset", "Alna", "Bøler",
    "Manglerud", "Helsfyr", "Bryn", "Skullerud", "Holmlia",
  ];

  const tromsoAreaNames = [
    "Sentrum", "Stakkevollan", "Kvaløya", "Tromsdalen", "Kroken",
    "Hamna", "Bjerkaker", "Breivika", "Tomasjord", "Langnes",
    "Giæver", "Skansen", "Reinen", "Gimle", "Dramsvegen",
  ];

  const lofotenAreaNames = [
    "Reine", "Svolvær", "Henningsvær", "Kabelvåg", "Leknes",
    "Nusfjord", "Ramberg", "Å", "Ballstad", "Stamsund",
    "Fredvang", "Hamnøy", "Moskenes", "Flakstad", "Bøstad",
  ];

  const parkingDescriptions = [
    "Trygg og beleilig parkeringsplass i rolig nabolag. Kort vei til sentrum og kollektivtransport. Godt opplyst og lett tilgjengelig.",
    "Privat garasjeplass med god plass. Beskyttet mot vær og vind. Praktisk beliggenhet nær butikker og restauranter.",
    "Sentral parkeringsplass perfekt for pendlere. Døgnåpen tilgang med enkel inn- og utkjøring. Overvåket område.",
    "Romslig parkeringsplass i attraktivt boligområde. Trygt og stille med god belysning. Ideell for dagparkering.",
    "Moderne parkeringsanlegg med alle fasiliteter. Ladestasjoner for elbil tilgjengelig. Kort gangavstand til sentrum.",
    "Praktisk parkering rett ved hovedveien. Enkel tilgang og god skilting. Passer for alle biltyper.",
    "Overbygget parkering med 24/7 tilgang. Kameraovervåkning og sikker inngang. Perfekt for de som trenger fast plass.",
    "Rimelig parkering i populært område. Kort vei til offentlig transport. Fleksible tider og enkel bestilling.",
  ];

  const campingDescriptions = [
    "Vakker bobilplass med fantastisk utsikt over naturen. Moderne fasiliteter inkludert dusj og toalett. Perfekt for naturelskere.",
    "Rolig og fredelig campingplass omgitt av natur. Grunnleggende fasiliteter med strøm og vann. Flott utgangspunkt for turer.",
    "Spektakulær beliggenhet med panoramautsikt. Ideell for bobiler og campingbiler. Vennlige verter og rene fasiliteter.",
    "Sjarmerende bobilplass ved kysten. Fiskemuligheter og turløyper i nærheten. Strøm, vann og tømmestasjon tilgjengelig.",
    "Naturskjønn campingplass med midnattssol om sommeren og nordlys om vinteren. En uforglemmelig opplevelse.",
    "Familievennlig campingplass med god plass. Lekeplass og bålplass. Moderne sanitæranlegg og gratis WiFi.",
    "Idyllisk plass mellom fjell og fjord. Stille og rolig med fantastisk natur. Perfekt for de som søker fred og ro.",
    "Koselig campingplass med arktisk natur rett utenfor døren. Godt egnet for bobiler opptil angitt lengde.",
  ];

  // --- Amenity pools ---
  const parkingAmenities: Amenity[] = [
    "ev_charging", "covered", "security_camera", "gated", "lighting",
  ];

  const campingAmenities: Amenity[] = [
    "electricity", "water", "toilets", "showers", "wifi",
    "campfire", "lake_access", "mountain_view", "pets_allowed", "waste_disposal",
  ];

  const allTags: ListingTag[] = ["popular", "featured", "available_today"];

  // --- Region configs ---
  interface RegionConfig {
    city: string;
    region: string;
    latMin: number;
    latMax: number;
    lngMin: number;
    lngMax: number;
    streets: string[];
    areaNames: string[];
    count: number;
  }

  const regions: RegionConfig[] = [
    {
      city: "Oslo", region: "Oslo",
      latMin: 59.85, latMax: 59.97, lngMin: 10.65, lngMax: 10.85,
      streets: osloStreets, areaNames: osloAreaNames, count: 150,
    },
    {
      city: "Tromsø", region: "Troms",
      latMin: 69.60, latMax: 69.72, lngMin: 18.85, lngMax: 19.15,
      streets: tromsoStreets, areaNames: tromsoAreaNames, count: 165,
    },
    {
      city: "Lofoten", region: "Nordland",
      latMin: 68.05, latMax: 68.45, lngMin: 13.40, lngMax: 14.80,
      streets: lofotenStreets, areaNames: lofotenAreaNames, count: 160,
    },
  ];

  const listings: Listing[] = [];
  let globalIdx = 1;

  for (const reg of regions) {
    for (let i = 0; i < reg.count; i++) {
      const isParking = rand() < 0.6;
      const id = `g${globalIdx}`;
      globalIdx++;

      const areaName = pick(reg.areaNames);
      const street = pick(reg.streets);
      const streetNum = randInt(1, 150);

      const titlePrefix = isParking
        ? pick(parkingTitlePrefixes)
        : pick(campingTitlePrefixes);
      const title = `${titlePrefix} ${areaName}`;
      const description = isParking
        ? pick(parkingDescriptions)
        : pick(campingDescriptions);

      const imagePool = isParking ? parkingImages : campingImages;
      const numImages = randInt(2, 3);
      const images: string[] = [];
      const shuffledImages = [...imagePool].sort(() => rand() - 0.5);
      for (let j = 0; j < numImages; j++) {
        images.push(shuffledImages[j % shuffledImages.length]);
      }

      const amenityPool = isParking ? parkingAmenities : campingAmenities;
      const amenities = pickN(amenityPool, 2, isParking ? 4 : 6);

      const price = isParking
        ? randInt(6, 25) * 10
        : randInt(20, 50) * 10;

      const rating = parseFloat((rand() * 1.0 + 4.0).toFixed(1));
      const reviewCount = randInt(5, 300);
      const spots = randInt(2, 50);

      // Tags: ~40% chance of having tags
      let tags: ListingTag[] | undefined;
      if (rand() < 0.4) {
        tags = pickN(allTags, 1, 2);
      }

      const listing: Listing = {
        id,
        title,
        description,
        category: isParking ? "parking" : "camping",
        images,
        location: {
          city: reg.city === "Lofoten" ? areaName : reg.city,
          region: reg.region,
          address: `${street} ${streetNum}`,
          lat: randFloat(reg.latMin, reg.latMax),
          lng: randFloat(reg.lngMin, reg.lngMax),
        },
        price,
        priceUnit: isParking ? "time" : "natt",
        rating,
        reviewCount,
        amenities,
        host: pick(hosts),
        spots,
        ...(tags && tags.length > 0 ? { tags } : {}),
        ...(!isParking ? { maxVehicleLength: randInt(6, 15) } : {}),
      };

      listings.push(listing);
    }
  }

  return listings;
}

export const generatedListings: Listing[] = generateListings();
