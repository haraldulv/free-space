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
}

export interface AppNotification {
  id: string;
  userId: string;
  type: "booking_received" | "booking_confirmed" | "booking_cancelled";
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
