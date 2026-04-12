export type ListingCategory = "parking" | "camping";

export type ListingTag = "popular" | "featured" | "available_today";

export type VehicleType = "car" | "campervan" | "motorhome";

export const vehicleLabels: Record<VehicleType, string> = {
  motorhome: "Bobil",
  campervan: "Campingbil",
  car: "Personbil",
};

export const vehicleLengths: Record<VehicleType, number> = {
  car: 5,
  campervan: 7,
  motorhome: 10,
};

/** Vehicle size hierarchy — a listing for motorhome fits all, campervan fits campervan+car, etc. */
export const vehicleFitsIn: Record<VehicleType, VehicleType[]> = {
  car: ["car", "campervan", "motorhome"],
  campervan: ["campervan", "motorhome"],
  motorhome: ["motorhome"],
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

export const AVAILABLE_EXTRAS: { id: ExtraId; name: string; defaultPrice: number; perNight: boolean; category: ListingCategory[] }[] = [
  { id: "ev_charging", name: "Elbil-lading", defaultPrice: 50, perNight: true, category: ["parking", "camping"] },
  { id: "power_hookup", name: "Strømtilkobling", defaultPrice: 75, perNight: true, category: ["camping"] },
  { id: "septic_disposal", name: "Septiktømming", defaultPrice: 150, perNight: false, category: ["camping"] },
  { id: "sauna", name: "Badstue", defaultPrice: 200, perNight: false, category: ["camping"] },
  { id: "firewood", name: "Ved", defaultPrice: 100, perNight: false, category: ["camping"] },
  { id: "kayak", name: "Kajakk", defaultPrice: 150, perNight: true, category: ["camping"] },
  { id: "bike_rental", name: "Sykkelutleie", defaultPrice: 100, perNight: true, category: ["camping"] },
  { id: "fishing_gear", name: "Fiskeutstyr", defaultPrice: 75, perNight: true, category: ["camping"] },
  { id: "bedding", name: "Sengetøy", defaultPrice: 100, perNight: false, category: ["camping"] },
  { id: "grill", name: "Grillpakke", defaultPrice: 50, perNight: false, category: ["camping"] },
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
}

export interface SpotMarker {
  lat: number;
  lng: number;
  label?: string;
}

export interface Listing {
  id: string;
  title: string;
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
  priceUnit: "time" | "natt";
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
  status: "pending" | "confirmed" | "cancelled";
  createdAt: string;
  userId?: string;
  hostId?: string;
  paymentIntentId?: string;
  paymentStatus?: "pending" | "paid" | "failed" | "refunded";
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
  selectedExtras?: { id: string; name: string; price: number; quantity: number }[];
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
