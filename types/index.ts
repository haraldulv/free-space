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
  /** Multi-select: vis kun annonser som tilbyr minst én av disse pris-pakke-periodene. */
  rentalPeriodTypes?: PricePackagePeriodType[];
}

/** Type for pris-pakker (DAY/WEEK/MONTH/YEAR). Brukes både i annonse og søk. */
export type PricePackagePeriodType = "DAY" | "WEEK" | "MONTH" | "YEAR";

export const PRICE_PACKAGE_PERIOD_LABELS: Record<PricePackagePeriodType, string> = {
  DAY: "Dag",
  WEEK: "Uke",
  MONTH: "Måned",
  YEAR: "År",
};

/** Tillatt antall enheter per periode-type (DAY 1-6, WEEK 1-3, MONTH 1-11, YEAR 1-3). */
export const PRICE_PACKAGE_VALUE_RANGES: Record<PricePackagePeriodType, { min: number; max: number }> = {
  DAY: { min: 1, max: 6 },
  WEEK: { min: 1, max: 3 },
  MONTH: { min: 1, max: 11 },
  YEAR: { min: 1, max: 3 },
};

export interface PricePackage {
  periodType: PricePackagePeriodType;
  /** DAY 1-6, WEEK 1-3, MONTH 1-11, YEAR 1-3 (jf. PRICE_PACKAGE_VALUE_RANGES). */
  periodValue: number;
  /** Pris i kroner (heltall). */
  priceNok: number;
}

/** Type for parking_type på listings. NULL = ikke oppgitt. */
export type ParkingType = "GARAGE" | "OUTDOOR" | "PARKING_HOUSE";

export const PARKING_TYPE_LABELS: Record<ParkingType, string> = {
  GARAGE: "Garasje",
  OUTDOOR: "Utendørs",
  PARKING_HOUSE: "Parkeringshus",
};

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
  /**
   * Per-dato pris-overstyringer. Nøkkel = "yyyy-MM-dd", verdi = kr.
   * Hvis dato finnes her overstyrer den standard `price` for booking-pris.
   */
  datePriceOverrides?: Record<string, number>;
  /**
   * Pris-pakker som tilbys for denne plassen.
   * Standard-pakkene (1 dag / 1 uke / 1 måned) ligger her, og utleier kan legge
   * til custom-pakker (DAY 1-6, WEEK 1-3, MONTH 1-11, YEAR 1-3).
   * Duplikater (samme periodType+periodValue) er ikke tillatt.
   */
  pricePackages?: PricePackage[];
  /**
   * Per-dato overstyring av åpningstid. Trumfer ukedags-default fra openingHours.
   * Eks: `{ "2026-05-17": { closed: true }, "2026-07-01": { open: "12:00-22:00" } }`.
   */
  openingHoursOverrides?: Record<string, DayOpeningOverride>;
}

/** Per-dato åpningstid-overstyring. closed=true → stengt. open="HH:MM-HH:MM" → annen tid. */
export interface DayOpeningOverride {
  closed?: boolean;
  open?: string;
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
  /** Type parkering. NULL = ikke oppgitt. */
  parkingType?: ParkingType | null;
  /** Cached liste av periode-typer som annonsen tilbyr (avledet fra spotMarkers[].pricePackages). */
  rentalPeriodTypes?: PricePackagePeriodType[];
  /** Kilde for importerte annonser (f.eks. "hygglo", "finn"). */
  source?: string | null;
  /** Stabil unik id i kildens system. */
  sourceId?: string | null;
}

/** Returnér unik liste av PricePackage-perioder fra alle spots. */
export function derivePeriodTypesFromSpots(spots: SpotMarker[] | undefined | null): PricePackagePeriodType[] {
  if (!spots || spots.length === 0) return [];
  const seen = new Set<PricePackagePeriodType>();
  for (const s of spots) {
    if (s.pricePackages) {
      for (const pkg of s.pricePackages) seen.add(pkg.periodType);
    }
    // Fallback for legacy data: tier-pris-felter implisitt mapper til periode-type.
    if (s.weeklyPrice != null) seen.add("WEEK");
    if (s.monthlyPrice != null || s.threeMonthPrice != null || s.sixMonthPrice != null) seen.add("MONTH");
    if (s.yearPrice != null) seen.add("YEAR");
    if (s.price != null || s.pricePerNight != null || s.dailyPrice != null) seen.add("DAY");
  }
  return Array.from(seen);
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
  listingId: string | null;
  guestId: string;
  hostId: string | null;
  bookingId?: string;
  /** "booking" eller "support". Default "booking" for bakoverkompatibilitet. */
  type?: "booking" | "support";
  lastMessageAt: string;
  createdAt: string;
  otherUserName?: string;
  otherUserAvatar?: string;
  listingTitle?: string;
  listingImage?: string;
  lastMessageText?: string;
  unreadCount?: number;
}

export type MessageKind = "text" | "offer" | "offer_accepted" | "offer_declined" | "system";

export interface OfferMessageMetadata {
  offerId?: string;
  bookingId?: string;
  totalPrice?: number;
  checkIn?: string;
  checkOut?: string;
  proposedByRole?: "guest" | "host";
  round?: number;
  expiresAt?: string;
  paymentDeadline?: string;
  acceptorRole?: "guest" | "host";
  declinedBy?: "guest" | "host";
  reason?: string;
}

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  content: string;
  read: boolean;
  createdAt: string;
  /** "text" | "offer" | "offer_accepted" | "offer_declined" | "system". Default "text". */
  kind?: MessageKind;
  metadata?: OfferMessageMetadata;
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

// ─── Utleier-outreach (admin) ────────────────────────────────────────────────

export type OutreachCategory = "rorbu" | "hotell" | "restaurant" | "camping" | "overnatting" | "other";

export type OutreachStatus =
  | "not_contacted"
  | "queued"
  | "contacted"
  | "no_response"
  | "follow_up"
  | "responded"
  | "interested"
  | "declined"
  | "onboarded";

export type OutreachContactType = "email" | "phone" | "note";

export interface OutreachTarget {
  id: string;
  placeId: string;
  name: string;
  category: OutreachCategory;
  area: string;
  address?: string | null;
  phone?: string | null;
  website?: string | null;
  email?: string | null;
  contactPerson?: string | null;
  lat?: number | null;
  lng?: number | null;
  rating?: number | null;
  userRatingsTotal?: number | null;
  statuses: OutreachStatus[];
  notes?: string | null;
  lastContactedAt?: string | null;
  lastContactedBy?: string | null;
  followUpAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface OutreachContactLogEntry {
  id: string;
  targetId: string;
  contactedBy?: string | null;
  contactedByName?: string | null;
  contactType: OutreachContactType;
  recipient?: string | null;
  subject?: string | null;
  body?: string | null;
  statusAfter?: string | null;
  createdAt: string;
}

export interface OutreachEmailTemplate {
  id: string;
  name: string;
  subject: string;
  body: string;
  isDefault: boolean;
  createdBy?: string | null;
  createdAt: string;
  updatedAt: string;
}

export const OUTREACH_STATUS_LABELS: Record<OutreachStatus, string> = {
  not_contacted: "Ikke kontaktet",
  queued: "I kø",
  contacted: "Kontaktet",
  no_response: "Ingen svar",
  follow_up: "Følges opp",
  responded: "Svart",
  interested: "Interessert",
  declined: "Takket nei",
  onboarded: "Registrert som vert",
};

export const OUTREACH_CATEGORY_LABELS: Record<OutreachCategory, string> = {
  rorbu: "Rorbu",
  hotell: "Hotell",
  restaurant: "Restaurant",
  camping: "Camping",
  overnatting: "Overnatting",
  other: "Annet",
};

export const OUTREACH_STATUS_COLORS: Record<OutreachStatus, string> = {
  not_contacted: "#9CA3AF",
  queued: "#A78BFA",
  contacted: "#3B82F6",
  no_response: "#6B7280",
  follow_up: "#F59E0B",
  responded: "#F97316",
  interested: "#10B981",
  declined: "#EF4444",
  onboarded: "#46C185",
};
