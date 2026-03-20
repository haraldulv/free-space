import { Listing, SearchFilters, vehicleLengths } from "@/types";

export const mockListings: Listing[] = [
  {
    id: "p1",
    title: "Sentrum Pendlerparkering",
    description:
      "Trygg og beleilig parkeringsplass rett ved Oslo S. Perfekt for pendlere som trenger daglig parkering i sentrum. Døgnåpen tilgang med elektrisk port og overvåkningskameraer. Kort gangavstand til kollektivtransport.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Oslo",
      region: "Oslo",
      address: "Schweigaards gate 14",
      lat: 59.9107,
      lng: 10.7592,
    },
    price: 150,
    priceUnit: "time",
    rating: 4.8,
    reviewCount: 124,
    amenities: ["covered", "security_camera", "gated", "ev_charging", "lighting"],
    host: {
      id: "h1",
      name: "Erik Hansen",
      avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&facepad=2",
      responseRate: 98,
      responseTime: "innen 1 time",
      joinedYear: 2022,
      listingsCount: 3,
    },
    spots: 12,
    tags: ["popular", "featured"],
  },
  {
    id: "p2",
    title: "Garasje ved Bryggen",
    description:
      "Privat garasjeplass i hjertet av Bergen, kun minutter fra Bryggen og Fisketorget. Overbygget og beskyttet mot regn. Ideell for turister og forretningsreisende.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Bergen",
      region: "Vestland",
      address: "Strandgaten 22",
      lat: 60.3943,
      lng: 5.3259,
    },
    price: 120,
    priceUnit: "time",
    rating: 4.6,
    reviewCount: 87,
    amenities: ["covered", "security_camera", "lighting"],
    host: {
      id: "h2",
      name: "Ingrid Larsen",
      avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&facepad=2",
      responseRate: 95,
      responseTime: "innen 2 timer",
      joinedYear: 2023,
      listingsCount: 1,
    },
    spots: 4,
    tags: ["available_today"],
  },
  {
    id: "p3",
    title: "EV-parkering Solsiden",
    description:
      "Moderne parkeringsanlegg med hurtiglading for elbiler. Sentralt plassert i Trondheims mest populære bydel. Tilgang via app eller kort.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Trondheim",
      region: "Trøndelag",
      address: "Beddingen 10",
      lat: 63.4337,
      lng: 10.4108,
    },
    price: 180,
    priceUnit: "time",
    rating: 4.9,
    reviewCount: 56,
    amenities: ["ev_charging", "covered", "gated", "security_camera", "lighting"],
    host: {
      id: "h3",
      name: "Olav Moen",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&facepad=2",
      responseRate: 100,
      responseTime: "innen 30 min",
      joinedYear: 2021,
      listingsCount: 5,
    },
    spots: 8,
    tags: ["featured", "available_today"],
  },
  {
    id: "p4",
    title: "Flyplass Langtidsparkering",
    description:
      "Rimelig langtidsparkering nær Stavanger lufthavn Sola. Gratis shuttle til terminalen hver 15. minutt. Trygt område med gjerde og kameraovervåkning.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Stavanger",
      region: "Rogaland",
      address: "Flyplassveien 230",
      lat: 58.882,
      lng: 5.638,
    },
    price: 89,
    priceUnit: "time",
    rating: 4.4,
    reviewCount: 203,
    amenities: ["gated", "security_camera", "lighting"],
    host: {
      id: "h4",
      name: "Kari Nilsen",
      avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop&facepad=2",
      responseRate: 92,
      responseTime: "innen 3 timer",
      joinedYear: 2023,
      listingsCount: 2,
    },
    spots: 30,
    tags: ["popular"],
  },
  {
    id: "p5",
    title: "Privat Oppkjørsel Majorstuen",
    description:
      "Rolig og trygg parkeringsplass på privat oppkjørsel i attraktivt boligområde. Kort vei til T-bane og butikker. Perfekt for de som jobber i Oslo vest.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1486006920555-c77dcf18193c?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Oslo",
      region: "Oslo",
      address: "Sorgenfrigata 8",
      lat: 59.9296,
      lng: 10.7136,
    },
    price: 100,
    priceUnit: "time",
    rating: 4.7,
    reviewCount: 42,
    amenities: ["lighting"],
    host: {
      id: "h5",
      name: "Anders Berg",
      avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&facepad=2",
      responseRate: 88,
      responseTime: "innen 4 timer",
      joinedYear: 2024,
      listingsCount: 1,
    },
    spots: 2,
    tags: ["available_today"],
  },
  {
    id: "c1",
    title: "Fjordcamp Hardanger",
    description:
      "Vakker bobilplass rett ved Hardangerfjorden med fantastisk utsikt. Moderne fasiliteter inkludert dusj, toalett og strømtilkobling. Perfekt utgangspunkt for fjordcruise og fruktgårder.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1478827536114-da961b7f86d2?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Ulvik",
      region: "Vestland",
      address: "Fjordveien 45",
      lat: 60.5682,
      lng: 6.9103,
    },
    price: 350,
    priceUnit: "natt",
    rating: 4.9,
    reviewCount: 178,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "showers",
      "wifi",
      "waste_disposal",
      "lake_access",
      "pets_allowed",
    ],
    host: {
      id: "h6",
      name: "Siri Fjordheim",
      avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&facepad=2",
      responseRate: 99,
      responseTime: "innen 1 time",
      joinedYear: 2021,
      listingsCount: 2,
    },
    maxVehicleLength: 10,
    spots: 15,
    tags: ["popular", "available_today"],
  },
  {
    id: "c2",
    title: "Lofoten Utsiktsplass",
    description:
      "Spektakulær bobilparkering med panoramautsikt over Lofotens ikoniske fjelltopper og fiskevær. Enkel men sjarmerende plass med grunnleggende fasiliteter. Midnattssol om sommeren!",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Reine",
      region: "Nordland",
      address: "Reinebringen 2",
      lat: 67.9324,
      lng: 13.0884,
    },
    price: 420,
    priceUnit: "natt",
    rating: 4.8,
    reviewCount: 93,
    amenities: [
      "toilets",
      "water",
      "waste_disposal",
      "mountain_view",
      "pets_allowed",
    ],
    host: {
      id: "h7",
      name: "Magnus Nordland",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&facepad=2",
      responseRate: 94,
      responseTime: "innen 2 timer",
      joinedYear: 2022,
      listingsCount: 3,
    },
    maxVehicleLength: 8,
    spots: 6,
    tags: ["featured"],
  },
  {
    id: "c3",
    title: "Skogsplass ved Mjøsa",
    description:
      "Fredelig skogsplass ved Norges største innsjø. Bålplass, fiskemuligheter og turløyper rett utenfor døren. Familievennlig med lekeplass. Strøm og vann tilgjengelig.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1478827536114-da961b7f86d2?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Hamar",
      region: "Innlandet",
      address: "Strandvegen 100",
      lat: 60.7945,
      lng: 11.068,
    },
    price: 280,
    priceUnit: "natt",
    rating: 4.7,
    reviewCount: 65,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "campfire",
      "lake_access",
      "pets_allowed",
      "waste_disposal",
    ],
    host: {
      id: "h8",
      name: "Liv Hamar",
      avatar: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&h=100&fit=crop&facepad=2",
      responseRate: 97,
      responseTime: "innen 1 time",
      joinedYear: 2022,
      listingsCount: 1,
    },
    maxVehicleLength: 12,
    spots: 20,
    tags: ["available_today"],
  },
  {
    id: "c4",
    title: "Geiranger Fjordcamping",
    description:
      "UNESCO-verdensarvsted! Bobilplass med direkte utsikt til Geirangerfjorden og De syv søstre. Full service camping med butikk, restaurant og utleie av kajakk.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Geiranger",
      region: "Møre og Romsdal",
      address: "Fjordvegen 1",
      lat: 62.1008,
      lng: 7.2059,
    },
    price: 450,
    priceUnit: "natt",
    rating: 4.9,
    reviewCount: 312,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "showers",
      "wifi",
      "waste_disposal",
      "mountain_view",
      "lake_access",
    ],
    host: {
      id: "h9",
      name: "Bjørn Geiranger",
      avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&facepad=2",
      responseRate: 100,
      responseTime: "innen 30 min",
      joinedYear: 2020,
      listingsCount: 4,
    },
    maxVehicleLength: 15,
    spots: 40,
    tags: ["popular", "featured"],
  },
  {
    id: "c5",
    title: "Nordkapp Villmarksplass",
    description:
      "Nordligste bobilparkering i Europa! Opplev midnattssol og nordlys fra denne unike plassen nær Nordkapp. Enkel standard, men en uforglemmelig opplevelse.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Honningsvåg",
      region: "Troms og Finnmark",
      address: "Nordkapveien 1",
      lat: 71.1685,
      lng: 25.7838,
    },
    price: 380,
    priceUnit: "natt",
    rating: 4.6,
    reviewCount: 147,
    amenities: [
      "toilets",
      "water",
      "electricity",
      "waste_disposal",
      "mountain_view",
    ],
    host: {
      id: "h10",
      name: "Tone Nordkapp",
      avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&facepad=2",
      responseRate: 90,
      responseTime: "innen 3 timer",
      joinedYear: 2023,
      listingsCount: 1,
    },
    maxVehicleLength: 10,
    spots: 10,
    tags: ["featured"],
  },
  {
    id: "p6",
    title: "Aker Brygge Parkeringshus",
    description:
      "Moderne parkeringshus ved Oslos mest populære havnepromenade. Perfekt for shopping, restaurantbesøk eller kontorarbeid i området. Godt opplyst og trygt.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Oslo",
      region: "Oslo",
      address: "Brynjulf Bulls plass 2",
      lat: 59.9087,
      lng: 10.7267,
    },
    price: 200,
    priceUnit: "time",
    rating: 4.7,
    reviewCount: 189,
    amenities: ["covered", "security_camera", "gated", "ev_charging", "lighting"],
    host: {
      id: "h11",
      name: "Henrik Strand",
      avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&facepad=2",
      responseRate: 96,
      responseTime: "innen 1 time",
      joinedYear: 2021,
      listingsCount: 4,
    },
    spots: 50,
    tags: ["popular", "available_today"],
  },
  {
    id: "p7",
    title: "Bodø Sentrum Parkering",
    description:
      "Sentral parkeringsplass i Bodø, ideell for reisende som tar Hurtigruten eller utforsker Saltstraumen. Kort vei til butikker og restauranter.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1486006920555-c77dcf18193c?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Bodø",
      region: "Nordland",
      address: "Sjøgata 3",
      lat: 67.2804,
      lng: 14.4049,
    },
    price: 95,
    priceUnit: "time",
    rating: 4.5,
    reviewCount: 34,
    amenities: ["lighting", "security_camera"],
    host: {
      id: "h12",
      name: "Marte Nordvik",
      avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&facepad=2",
      responseRate: 91,
      responseTime: "innen 2 timer",
      joinedYear: 2024,
      listingsCount: 1,
    },
    spots: 8,
    tags: ["featured"],
  },
  {
    id: "p8",
    title: "Fredrikstad Gamlebyen P-plass",
    description:
      "Parkering ved vakre Gamlebyen i Fredrikstad. Utforsk Norges best bevarte festningsby til fots. Rolig og trygt område.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Fredrikstad",
      region: "Østfold",
      address: "Gamlebyveien 1",
      lat: 59.2181,
      lng: 10.9298,
    },
    price: 75,
    priceUnit: "time",
    rating: 4.3,
    reviewCount: 28,
    amenities: ["lighting"],
    host: {
      id: "h13",
      name: "Thomas Enger",
      avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&facepad=2",
      responseRate: 85,
      responseTime: "innen 4 timer",
      joinedYear: 2024,
      listingsCount: 1,
    },
    spots: 6,
    tags: ["available_today"],
  },
  {
    id: "c6",
    title: "Trolltunga Basecamp",
    description:
      "Bobilparkering ved foten av den berømte Trolltunga-turen. Våkn opp til fjellutsikt og start turen rett fra plassen. Grunnleggende fasiliteter med fokus på naturnærhet.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Odda",
      region: "Vestland",
      address: "Trolltungavegen 89",
      lat: 60.1241,
      lng: 6.5449,
    },
    price: 320,
    priceUnit: "natt",
    rating: 4.8,
    reviewCount: 256,
    amenities: ["toilets", "water", "waste_disposal", "mountain_view", "campfire"],
    host: {
      id: "h14",
      name: "Eirik Fjellstad",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&facepad=2",
      responseRate: 97,
      responseTime: "innen 1 time",
      joinedYear: 2021,
      listingsCount: 2,
    },
    maxVehicleLength: 9,
    spots: 12,
    tags: ["popular", "featured"],
  },
  {
    id: "c7",
    title: "Preikestolen Camping",
    description:
      "Campingplass med utsikt over Lysefjorden, kun kort kjøretur fra Preikestolen. Moderne fasiliteter og familievennlig atmosfære. Kajakk- og fiskeutleie tilgjengelig.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1478827536114-da961b7f86d2?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Jørpeland",
      region: "Rogaland",
      address: "Preikestolvegen 40",
      lat: 58.9865,
      lng: 6.1867,
    },
    price: 390,
    priceUnit: "natt",
    rating: 4.7,
    reviewCount: 142,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "showers",
      "wifi",
      "lake_access",
      "mountain_view",
      "pets_allowed",
    ],
    host: {
      id: "h15",
      name: "Silje Lyse",
      avatar: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&h=100&fit=crop&facepad=2",
      responseRate: 98,
      responseTime: "innen 30 min",
      joinedYear: 2022,
      listingsCount: 1,
    },
    maxVehicleLength: 12,
    spots: 25,
    tags: ["popular", "available_today"],
  },
  {
    id: "c8",
    title: "Lyngør Skjærgårdscamping",
    description:
      "Idyllisk camping ved Sørlandets fineste skjærgård. Bobilplass med sjøutsikt, bademuligheter og kort vei til Lyngør — kåret til Europas best bevarte tettsted.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Tvedestrand",
      region: "Agder",
      address: "Lyngørveien 15",
      lat: 58.6339,
      lng: 9.1429,
    },
    price: 310,
    priceUnit: "natt",
    rating: 4.9,
    reviewCount: 87,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "showers",
      "lake_access",
      "pets_allowed",
      "waste_disposal",
    ],
    host: {
      id: "h16",
      name: "Anne Skjærgård",
      avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&facepad=2",
      responseRate: 100,
      responseTime: "innen 1 time",
      joinedYear: 2023,
      listingsCount: 1,
    },
    maxVehicleLength: 8,
    spots: 10,
    tags: ["featured", "available_today"],
  },
  {
    id: "p9",
    title: "Tromsø Havn Parkering",
    description:
      "Parkeringsplass ved Tromsø havn med utsikt over Ishavskatedralen. Sentralt for nordlyssafari, Polaria og bysentrum. Godt vedlikeholdt helårsanlegg.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1593941707882-a5bba14938c7?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Tromsø",
      region: "Troms og Finnmark",
      address: "Havnegata 5",
      lat: 69.6496,
      lng: 18.9553,
    },
    price: 130,
    priceUnit: "time",
    rating: 4.6,
    reviewCount: 76,
    amenities: ["lighting", "security_camera", "gated"],
    host: {
      id: "h17",
      name: "Lars Nordlys",
      avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&facepad=2",
      responseRate: 93,
      responseTime: "innen 2 timer",
      joinedYear: 2022,
      listingsCount: 2,
    },
    spots: 15,
    tags: ["popular", "featured"],
  },
  {
    id: "c9",
    title: "Sognefjorden Panorama",
    description:
      "Campingplass ved verdens lengste fjord. Spektakulær utsikt over Sognefjorden fra terrasserte plasser. Nærhet til Flåmsbana og Nærøyfjorden.",
    category: "camping",
    images: [
      "https://images.unsplash.com/photo-1478827536114-da961b7f86d2?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Balestrand",
      region: "Vestland",
      address: "Fjordvegen 22",
      lat: 61.2094,
      lng: 6.5314,
    },
    price: 370,
    priceUnit: "natt",
    rating: 4.8,
    reviewCount: 198,
    amenities: [
      "electricity",
      "water",
      "toilets",
      "showers",
      "wifi",
      "lake_access",
      "mountain_view",
      "waste_disposal",
    ],
    host: {
      id: "h18",
      name: "Kristin Sogndal",
      avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&facepad=2",
      responseRate: 99,
      responseTime: "innen 30 min",
      joinedYear: 2020,
      listingsCount: 3,
    },
    maxVehicleLength: 14,
    spots: 30,
    tags: ["popular", "featured", "available_today"],
  },
  {
    id: "p10",
    title: "Kristiansand Kvadraturen",
    description:
      "Trygg parkering i hjertet av Kristiansand sentrum. Gåavstand til Dyreparken, Fiskebrygga og Markens gate. Perfekt for dagsturer til Sørlandet.",
    category: "parking",
    images: [
      "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=800&h=600&fit=crop",
      "https://images.unsplash.com/photo-1486006920555-c77dcf18193c?w=800&h=600&fit=crop",
    ],
    location: {
      city: "Kristiansand",
      region: "Agder",
      address: "Markens gate 15",
      lat: 58.1462,
      lng: 7.9956,
    },
    price: 110,
    priceUnit: "time",
    rating: 4.4,
    reviewCount: 63,
    amenities: ["lighting", "covered", "security_camera"],
    host: {
      id: "h19",
      name: "Julie Sørland",
      avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop&facepad=2",
      responseRate: 89,
      responseTime: "innen 3 timer",
      joinedYear: 2023,
      listingsCount: 2,
    },
    spots: 10,
    tags: ["available_today", "featured"],
  },
];

export function getListingById(id: string): Listing | undefined {
  return mockListings.find((l) => l.id === id);
}

export function getListingsByCategory(
  category?: "parking" | "camping"
): Listing[] {
  if (!category) return mockListings;
  return mockListings.filter((l) => l.category === category);
}

export function searchListings(filters: SearchFilters): Listing[] {
  let results = [...mockListings];

  if (filters.category) {
    results = results.filter((l) => l.category === filters.category);
  }

  if (filters.query) {
    const q = filters.query.toLowerCase();
    results = results.filter(
      (l) =>
        l.title.toLowerCase().includes(q) ||
        l.location.city.toLowerCase().includes(q) ||
        l.location.region.toLowerCase().includes(q)
    );
  }

  if (filters.vehicleType) {
    const length = vehicleLengths[filters.vehicleType];
    results = results.filter(
      (l) => !l.maxVehicleLength || l.maxVehicleLength >= length
    );
  }

  return results;
}

function filterByTag(listings: Listing[], tag: string): Listing[] {
  return listings.filter((l) => l.tags?.includes(tag as never));
}

export function getPopularListings(filters: SearchFilters = {}): Listing[] {
  return filterByTag(searchListings(filters), "popular");
}

export function getFeaturedListings(filters: SearchFilters = {}): Listing[] {
  return filterByTag(searchListings(filters), "featured");
}

export function getAvailableTodayListings(filters: SearchFilters = {}): Listing[] {
  return filterByTag(searchListings(filters), "available_today");
}
