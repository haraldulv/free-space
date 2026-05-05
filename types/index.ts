export type ListingCategory = "parking" | "camping";

export type ListingTag = "popular" | "featured" | "available_today";

export type VehicleType = "car" | "campervan" | "motorhome" | "van" | "motorcycle";

export const vehicleLabels: Record<VehicleType, string> = {
  motorhome: "Bobil",
  campervan: "Campingbil",
  car: "Personbil",
  van: "Varebil",
  motorcycle: "Motorsykkel",
};

export const vehicleLengths: Record<VehicleType, number> = {
  motorcycle: 2,
  car: 5,
  van: 6,
  campervan: 7,
  motorhome: 10,
};

/**
 * Vehicle size hierarchy — hvilke biltyper kan en plass for X ta imot.
 * En plass merket "motorhome" kan også ta mindre kjøretøy. MC/varebil er kompakte.
 */
export const vehicleFitsIn: Record<VehicleType, VehicleType[]> = {
  motorcycle: ["motorcycle", "car", "van", "campervan", "motorhome"],
  car: ["car", "van", "campervan", "motorhome"],
  van: ["van", "campervan", "motorhome"],
  campervan: ["campervan", "motorhome"],
  motorhome: ["motorhome"],
};

/** Hvilke biltyper er relevante per kategori. Camping = campingkjøretøy; parkering = alle. */
export const VEHICLE_TYPES_BY_CATEGORY: Record<ListingCategory, VehicleType[]> = {
  camping: ["motorhome", "campervan", "car"],
  parking: ["car", "van", "motorcycle", "campervan", "motorhome"],
};

export interface SearchFilters {
  query?: string;
  category?: ListingCategory;
  vehicleType?: VehicleType;
  checkIn?: string;
  checkOut?: string;
  lat?: number;
  lng?: number;
  radiusKm?: number;
  /** Filter på åpningstid. `any` = alle (default), `always` = kun døgnåpne, `limited` = kun med begrenset åpningstid. */
  openingHours?: "any" | "always" | "limited";
}

export type Amenity =
  | "ev_charging"
  | "covered"
  | "security_camera"
  | "gated"
  | "lighting"
  | "toilets"
  | "showers"
  | "electricity"
  | "water"
  | "wifi"
  | "campfire"
  | "lake_access"
  | "mountain_view"
  | "pets_allowed"
  | "waste_disposal"
  | "handicap_accessible";

export type ListingExtra = {
  id: string;
  name: string;
  price: number;
  perNight: boolean;
  /** Valgfri melding som sendes til gjest ved innsjekk hvis dette tillegget ble booket. */
  message?: string;
};

export type ExtraId =
  | "ev_charging"
  | "power_hookup"
  | "septic_disposal"
  | "sauna"
  | "firewood"
  | "kayak"
  | "bike_rental"
  | "fishing_gear"
  | "bedding"
  | "grill";

export type ExtraScope = "site" | "area";

export const AVAILABLE_EXTRAS: { id: ExtraId; name: string; defaultPrice: number; perNight: boolean; category: ListingCategory[]; scope: ExtraScope }[] = [
  { id: "ev_charging", name: "Elbil-lading", defaultPrice: 50, perNight: true, category: ["parking", "camping"], scope: "site" },
  { id: "power_hookup", name: "Strømtilkobling", defaultPrice: 75, perNight: true, category: ["camping"], scope: "site" },
  { id: "septic_disposal", name: "Septiktømming", defaultPrice: 150, perNight: false, category: ["camping"], scope: "site" },
  { id: "sauna", name: "Badstue", defaultPrice: 200, perNight: false, category: ["camping"], scope: "area" },
  { id: "firewood", name: "Ved", defaultPrice: 100, perNight: false, category: ["camping"], scope: "area" },
  { id: "kayak", name: "Kajakk", defaultPrice: 150, perNight: true, category: ["camping"], scope: "area" },
  { id: "bike_rental", name: "Sykkelutleie", defaultPrice: 100, perNight: true, category: ["camping"], scope: "area" },
  { id: "fishing_gear", name: "Fiskeutstyr", defaultPrice: 75, perNight: true, category: ["camping"], scope: "area" },
  { id: "bedding", name: "Sengetøy", defaultPrice: 100, perNight: false, category: ["camping"], scope: "area" },
  { id: "grill", name: "Grillpakke", defaultPrice: 50, perNight: false, category: ["camping"], scope: "area" },
];

export const AMENITIES_BY_CATEGORY: Record<ListingCategory, Amenity[]> = {
  parking: ["ev_charging", "covered", "security_camera", "gated", "lighting", "handicap_accessible"],
  camping: ["electricity", "water", "waste_disposal", "toilets", "showers", "wifi", "campfire", "lake_access", "mountain_view", "pets_allowed", "handicap_accessible"],
};

export interface Host {
  id: string;
  name: string;
  avatar: string;
  responseRate: number;
  responseTime: string;
  joinedYear: number;
  listingsCount: number;
  /** Aggregert rating fra profiles-tabellen (alle vertens annonser kombinert). */
  rating?: number;
  /** Antall reviews vert har totalt. */
  reviewCount?: number;
  /** Bio fra profiles. */
  bio?: string;
}

export type PriceUnit = "time" | "natt";

export const priceUnitLabels: Record<PriceUnit, string> = {
  time: "dag",
  natt: "natt",
};

export type Weekday = "mon" | "tue" | "wed" | "thu" | "fri" | "sat" | "sun";

export const WEEKDAYS: Weekday[] = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

/**
 * Åpningstid per ukedag for parkering. `"HH:MM-HH:MM"` (lokal tid, Europe/Oslo).
 * `null` på en ukedag = stengt. Felt fraværende = stengt.
 * Hele objektet `null`/`undefined` på listing = døgnåpent.
 */
export type OpeningHours = Partial<Record<Weekday, string | null>>;

export interface SpotMarker {
  id?: string;
  lat: number;
  lng: number;
  label?: string;
  description?: string;
  price?: number;
  /** Camping per natt-pris per plass. */
  pricePerNight?: number;
  vehicleMaxLength?: number;
  /** Multi-select biltyper — bruk denne fra build 61+. Singel `vehicleType` er backward-compat. */
  vehicleTypes?: VehicleType[];
  /** @deprecated bruk `vehicleTypes`. Beholdes for decode av seedede listings. */
  vehicleType?: VehicleType;
  extras?: ListingExtra[];
  blockedDates?: string[];
  checkinMessage?: string;
  images?: string[];
  /** @deprecated 1-dags-tier eksponeres ikke i UI lenger — standard-dagsprisen dekker. */
  dailyPrice?: number;
  /** Pris (kr) for 7 påfølgende fulle døgn. */
  weeklyPrice?: number;
  /** Pris (kr) for 30 påfølgende fulle døgn. */
  monthlyPrice?: number;
  /** Pris (kr) for 90 påfølgende fulle døgn (3 måneder). */
  threeMonthPrice?: number;
  /** Pris (kr) for 180 påfølgende fulle døgn (6 måneder). */
  sixMonthPrice?: number;
  /** Pris (kr) for 365 påfølgende fulle døgn (1 år). */
  yearPrice?: number;
  /**
   * Per-plass åpningstid. Hvis satt overstyrer den listing-nivå.
   * `null` (eller fraværende) = arve listing.openingHours.
   */
  openingHours?: OpeningHours | null;
}

/** Returner effective vehicleTypes på en SpotMarker — håndterer backward-compat. */
export function getEffectiveVehicleTypes(spot: Pick<SpotMarker, "vehicleTypes" | "vehicleType">): VehicleType[] {
  if (spot.vehicleTypes && spot.vehicleTypes.length > 0) return spot.vehicleTypes;
  if (spot.vehicleType) return [spot.vehicleType];
  return [];
}

/**
 * Returns display price range for a listing — (min, max) basert på individuelle
 * spot-priser hvis satt, ellers fall tilbake til listing.price.
 */
export function getDisplayPriceRange(listing: Pick<Listing, "price" | "spotMarkers">): { min: number; max: number } {
  const spotPrices = (listing.spotMarkers || [])
    .map((s) => s.price)
    .filter((p): p is number => p != null && p > 0);
  if (spotPrices.length > 0) {
    return { min: Math.min(...spotPrices), max: Math.max(...spotPrices) };
  }
  return { min: listing.price, max: listing.price };
}

/** "150" for uniform, "150–300" for individuell med spread. */
export function getDisplayPriceText(listing: Pick<Listing, "price" | "spotMarkers">): string {
  const { min, max } = getDisplayPriceRange(listing);
  return min === max ? `${min}` : `${min}–${max}`;
}

export type SelectedExtraEntry = {
  id: string;
  name: string;
  price: number;
  perNight: boolean;
  quantity: number;
  /** Kopiert fra ListingExtra.message ved booking så den overlever hvis host endrer senere. */
  message?: string;
};

export type SelectedExtras = {
  listing?: SelectedExtraEntry[];
  spots?: Record<string, SelectedExtraEntry[]>;
};

export type NightlyPriceSource = "base" | "weekend" | "season" | "override";

export interface NightlyPriceEntry {
  date: string;
  price: number;
  source: NightlyPriceSource;
}

export interface Listing {
  id: string;
  title: string;
  internalName?: string;
  description: string;
  category: ListingCategory;
  images: string[];
  location: {
    city: string;
    region: string;
    address: string;
    lat: number;
    lng: number;
  };
  spotMarkers?: SpotMarker[];
  hideExactLocation?: boolean;
  price: number;
  priceUnit: PriceUnit;
  rating: number;
  reviewCount: number;
  amenities: Amenity[];
  host: Host;
  maxVehicleLength?: number;
  spots: number;
  tags?: ListingTag[];
  vehicleType?: VehicleType;
  instantBooking?: boolean;
  isActive?: boolean;
  blockedDates?: string[];
  availableSpots?: number;
  checkInTime?: string;
  checkOutTime?: string;
  extras?: ListingExtra[];
  checkinMessage?: string;
  checkoutMessage?: string;
  checkoutMessageSendHoursBefore?: number;
  /** Åpningstid på listing-nivå. NULL = døgnåpent. Kun relevant for parkering. */
  openingHours?: OpeningHours | null;
  /** Minimum antall dager bruker kan booke. NULL = ingen minimum. */
  minStayDays?: number | null;
  /** Maksimum antall dager bruker kan booke. NULL = ingen maksimum. */
  maxStayDays?: number | null;
}

export interface Booking {
  id: string;
  listingId: string;
  listingTitle: string;
  listingImage: string;
  listingCategory: ListingCategory;
  location: string;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  status: "pending" | "requested" | "confirmed" | "cancelled";
  createdAt: string;
  userId?: string;
  hostId?: string;
  paymentIntentId?: string;
  paymentStatus?: "pending" | "paid" | "failed" | "refunded";
  approvalDeadline?: string;
  hostRespondedAt?: string;
  guestRating?: number;
  guestReviewCount?: number;
  guestName?: string;
  guestAvatar?: string;
  guestEmail?: string;
  licensePlate?: string;
  isRentalCar?: boolean;
  checkInTime?: string;
  checkOutTime?: string;
  listingLat?: number;
  listingLng?: number;
  listingAddress?: string;
  cancelledAt?: string;
  cancelledBy?: "guest" | "host";
  cancellationReason?: string;
  refundAmount?: number;
  hostName?: string;
  hostPhone?: string;
  conversationId?: string;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtras;
  priceBreakdown?: NightlyPriceEntry[];
}

export interface Review {
  id: string;
  bookingId: string;
  listingId: string;
  userId: string;
  rating: number;
  comment: string;
  createdAt: string;
  userName?: string;
  userAvatar?: string;
}

export interface Conversation {
  id: string;
  listingId: string;
  guestId: string;
  hostId: string;
  bookingId?: string;
  lastMessageAt: string;
  createdAt: string;
  otherUserName?: string;
  otherUserAvatar?: string;
  listingTitle?: string;
  listingImage?: string;
  lastMessageText?: string;
  unreadCount?: number;
}

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  content: string;
  read: boolean;
  createdAt: string;
  senderName?: string;
  senderAvatar?: string;
}

export interface AppNotification {
  id: string;
  userId: string;
  type: "booking_received" | "booking_confirmed" | "booking_cancelled" | "new_message" | "new_review" | "payout_sent";
  title: string;
  body?: string;
  metadata?: Record<string, unknown>;
  read: boolean;
  createdAt: string;
}

export interface UserProfile {
  id: string;
  email: string;
  fullName: string;
  avatar?: string;
  responseRate?: number;
  responseTime?: string;
  joinedYear?: number;
  createdAt?: string;
}
