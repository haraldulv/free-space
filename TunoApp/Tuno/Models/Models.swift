import Foundation

// MARK: - Listing

struct Listing: Codable, Identifiable, Hashable {
    let id: String
    let hostId: String?
    let title: String
    let internalName: String?
    let description: String?
    let category: ListingCategory?
    let vehicleType: VehicleType?
    let city: String?
    let region: String?
    let address: String?
    let lat: Double?
    let lng: Double?
    let price: Int?
    let priceUnit: PriceUnit?
    let amenities: [String]?
    let maxVehicleLength: Double?
    let spots: Int?
    let images: [String]?
    let instantBooking: Bool?
    let spotMarkers: [SpotMarker]?
    let hideExactLocation: Bool?
    let blockedDates: [String]?
    let checkInTime: String?
    let checkOutTime: String?
    let checkinMessage: String?
    let isActive: Bool?
    let extras: [ListingExtra]?
    let rating: Double?
    let reviewCount: Int?
    let hostName: String?
    let hostAvatar: String?
    let hostResponseRate: Double?
    let hostResponseTime: String?
    let hostJoinedYear: Int?
    let hostListingsCount: Int?
    let tags: [String]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, region, address, lat, lng, price, amenities, spots, images, rating, tags
        case hostId = "host_id"
        case internalName = "internal_name"
        case vehicleType = "vehicle_type"
        case priceUnit = "price_unit"
        case maxVehicleLength = "max_vehicle_length"
        case instantBooking = "instant_booking"
        case spotMarkers = "spot_markers"
        case hideExactLocation = "hide_exact_location"
        case blockedDates = "blocked_dates"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case checkinMessage = "checkin_message"
        case isActive = "is_active"
        case extras
        case reviewCount = "review_count"
        case hostName = "host_name"
        case hostAvatar = "host_avatar"
        case hostResponseRate = "host_response_rate"
        case hostResponseTime = "host_response_time"
        case hostJoinedYear = "host_joined_year"
        case hostListingsCount = "host_listings_count"
        case createdAt = "created_at"
    }
}

extension Listing {
    /// Pris som skal vises i kort / detalj / booking-summary.
    /// Returnerer (min, max) basert på individuelle spot-priser hvis satt,
    /// ellers fall tilbake til listing.price.
    var displayPriceRange: (min: Int, max: Int) {
        let spotPrices = (spotMarkers ?? []).compactMap { $0.price }.filter { $0 > 0 }
        if !spotPrices.isEmpty {
            return (spotPrices.min()!, spotPrices.max()!)
        }
        let fallback = price ?? 0
        return (fallback, fallback)
    }

    /// Formatert pris-streng: "150" for uniform, "150–300" for individuell med spread.
    var displayPriceText: String {
        let range = displayPriceRange
        if range.min == range.max { return "\(range.min)" }
        return "\(range.min)–\(range.max)"
    }
}

struct SpotMarker: Codable, Hashable {
    var id: String?
    let lat: Double
    let lng: Double
    var label: String?
    var price: Int?
    var extras: [ListingExtra]?
    var blockedDates: [String]?
    var checkinMessage: String?
}

struct SelectedExtraEntry: Codable, Hashable {
    let id: String
    let name: String
    let price: Int
    let perNight: Bool
    let quantity: Int
    var message: String? = nil
}

struct SelectedExtras: Codable, Hashable {
    var listing: [SelectedExtraEntry]?
    var spots: [String: [SelectedExtraEntry]]?
}

/// Per-natt pris-entry på en booking — snapshot tas ved booking-insert.
struct NightlyPriceEntry: Codable, Hashable {
    let date: String
    let price: Int
    let source: String  // "base" | "weekend" | "season" | "override"
}

enum ListingCategory: String, Codable, CaseIterable {
    case parking
    case camping

    var displayName: String {
        switch self {
        case .parking: return "Parkering"
        case .camping: return "Campingplass"
        }
    }
}

enum VehicleType: String, Codable, CaseIterable {
    case motorhome
    case campervan
    case car

    var displayName: String {
        switch self {
        case .car: return "Personbil"
        case .campervan: return "Campingbil"
        case .motorhome: return "Bobil"
        }
    }

    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .campervan: return "bus.fill"
        case .motorhome: return "bus.fill"
        }
    }
}

// MARK: - Listing Extra

struct ListingExtra: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var price: Int
    var perNight: Bool
    /// Valgfri melding som sendes til gjest ved innsjekk hvis dette ekstrautstyret ble booket.
    var message: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, price, message
        case perNight = "perNight"
    }
}

enum ExtraScope: String, Codable, Hashable {
    case siteSpecific  // hører til én spesifikk plass (strøm, EV, septik)
    case areaWide      // felles for hele anlegget (sauna, ved, kajakk...)
}

enum ExtraType: String, CaseIterable {
    case evCharging = "ev_charging"
    case powerHookup = "power_hookup"
    case septicDisposal = "septic_disposal"
    case sauna
    case firewood
    case kayak
    case bikeRental = "bike_rental"
    case fishingGear = "fishing_gear"
    case bedding
    case grill

    var name: String {
        switch self {
        case .evCharging: return "Elbil-lading"
        case .powerHookup: return "Strømtilkobling"
        case .septicDisposal: return "Septiktømming"
        case .sauna: return "Badstue"
        case .firewood: return "Ved"
        case .kayak: return "Kajakk"
        case .bikeRental: return "Sykkelutleie"
        case .fishingGear: return "Fiskeutstyr"
        case .bedding: return "Sengetøy"
        case .grill: return "Grillpakke"
        }
    }

    var icon: String {
        switch self {
        case .evCharging: return "bolt.fill"
        case .powerHookup: return "powerplug.fill"
        case .septicDisposal: return "drop.fill"
        case .sauna: return "flame.fill"
        case .firewood: return "leaf.fill"
        case .kayak: return "sailboat.fill"
        case .bikeRental: return "bicycle"
        case .fishingGear: return "fish.fill"
        case .bedding: return "bed.double.fill"
        case .grill: return "frying.pan.fill"
        }
    }

    var defaultPrice: Int {
        switch self {
        case .evCharging: return 50
        case .powerHookup: return 75
        case .septicDisposal: return 150
        case .sauna: return 200
        case .firewood: return 100
        case .kayak: return 150
        case .bikeRental: return 100
        case .fishingGear: return 75
        case .bedding: return 100
        case .grill: return 50
        }
    }

    var perNight: Bool {
        switch self {
        case .evCharging, .powerHookup, .kayak, .bikeRental, .fishingGear: return true
        case .septicDisposal, .sauna, .firewood, .bedding, .grill: return false
        }
    }

    var categories: [ListingCategory] {
        switch self {
        case .evCharging: return [.parking, .camping]
        default: return [.camping]
        }
    }

    var scope: ExtraScope {
        switch self {
        case .evCharging, .powerHookup, .septicDisposal: return .siteSpecific
        case .sauna, .firewood, .kayak, .bikeRental, .fishingGear, .bedding, .grill: return .areaWide
        }
    }

    static func available(for category: ListingCategory) -> [ExtraType] {
        allCases.filter { $0.categories.contains(category) }
    }

    static func available(for category: ListingCategory, scope: ExtraScope) -> [ExtraType] {
        available(for: category).filter { $0.scope == scope }
    }
}

// MARK: - Amenity

enum AmenityType: String, CaseIterable {
    case evCharging = "ev_charging"
    case covered
    case securityCamera = "security_camera"
    case gated
    case lighting
    case toilets
    case showers
    case electricity
    case water
    case wifi
    case campfire
    case lakeAccess = "lake_access"
    case mountainView = "mountain_view"
    case petsAllowed = "pets_allowed"
    case wasteDisposal = "waste_disposal"
    case handicapAccessible = "handicap_accessible"

    var label: String {
        switch self {
        case .evCharging: return "Elbil-lading"
        case .covered: return "Under tak"
        case .securityCamera: return "Overvåkingskamera"
        case .gated: return "Portadgang"
        case .lighting: return "Belysning"
        case .toilets: return "Toalett"
        case .showers: return "Dusj"
        case .electricity: return "Strøm (tilkobling)"
        case .water: return "Vanntilkobling"
        case .wifi: return "WiFi"
        case .campfire: return "Bålplass"
        case .lakeAccess: return "Sjø-/innsjøtilgang"
        case .mountainView: return "Fjellpanorama"
        case .petsAllowed: return "Dyrevennlig"
        case .wasteDisposal: return "Septiktømming"
        case .handicapAccessible: return "Rullestoltilgjengelig"
        }
    }

    var icon: String {
        switch self {
        case .evCharging: return "bolt.fill"
        case .covered: return "umbrella.fill"
        case .securityCamera: return "video.fill"
        case .gated: return "lock.fill"
        case .lighting: return "lightbulb.fill"
        case .toilets: return "toilet.fill"
        case .showers: return "shower.fill"
        case .electricity: return "bolt.fill"
        case .water: return "drop.fill"
        case .wifi: return "wifi"
        case .campfire: return "flame.fill"
        case .lakeAccess: return "water.waves"
        case .mountainView: return "mountain.2.fill"
        case .petsAllowed: return "pawprint.fill"
        case .wasteDisposal: return "trash.fill"
        case .handicapAccessible: return "figure.roll"
        }
    }

    /// Amenities useful as search filters
    static let filterableAmenities: [AmenityType] = [
        .electricity, .wifi, .water, .toilets, .showers, .evCharging, .wasteDisposal
    ]
}

enum PriceUnit: String, Codable {
    case time
    case natt

    var displayName: String {
        switch self {
        case .time: return "dag"
        case .natt: return "natt"
        }
    }
}

// MARK: - Profile

struct Profile: Codable, Identifiable {
    let id: String
    let fullName: String?
    let avatarUrl: String?
    let responseRate: Double?
    let responseTime: String?
    let joinedYear: Int?
    let stripeAccountId: String?
    let stripeOnboardingComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case responseRate = "response_rate"
        case responseTime = "response_time"
        case joinedYear = "joined_year"
        case stripeAccountId = "stripe_account_id"
        case stripeOnboardingComplete = "stripe_onboarding_complete"
    }
}

// MARK: - Booking

struct Booking: Codable, Identifiable {
    let id: String
    let userId: String
    let listingId: String
    let hostId: String
    let checkIn: String
    let checkOut: String
    let totalPrice: Int
    var status: BookingStatus
    let paymentStatus: PaymentStatus
    let transferStatus: TransferStatus?
    let paymentIntentId: String?
    let stripeTransferId: String?
    let licensePlate: String?
    let isRentalCar: Bool?
    let createdAt: String?
    let cancelledAt: String?
    let cancelledBy: String?
    let cancellationReason: String?
    var refundAmount: Int?
    let selectedSpotIds: [String]?
    let selectedExtras: SelectedExtras?
    let approvalDeadline: String?
    let hostRespondedAt: String?
    /// Snapshot av listing.check_in_time ved booking-tidspunkt — beholder opprinnelig
    /// avtale selv om host endrer listingen senere. NULL for gamle bookinger.
    let checkInTimeSnapshot: String?
    let checkOutTimeSnapshot: String?
    /// Per-natt pris-breakdown. Lagres ved booking-insert når regler er aktive.
    let priceBreakdown: [NightlyPriceEntry]?

    // Joined data
    let listing: BookingListing?
    let guest: BookingGuest?

    enum CodingKeys: String, CodingKey {
        case id, status, listing, guest
        case userId = "user_id"
        case listingId = "listing_id"
        case hostId = "host_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
        case totalPrice = "total_price"
        case paymentStatus = "payment_status"
        case transferStatus = "transfer_status"
        case paymentIntentId = "payment_intent_id"
        case stripeTransferId = "stripe_transfer_id"
        case licensePlate = "license_plate"
        case isRentalCar = "is_rental_car"
        case createdAt = "created_at"
        case cancelledAt = "cancelled_at"
        case cancelledBy = "cancelled_by"
        case cancellationReason = "cancellation_reason"
        case refundAmount = "refund_amount"
        case selectedSpotIds = "selected_spot_ids"
        case selectedExtras = "selected_extras"
        case approvalDeadline = "approval_deadline"
        case hostRespondedAt = "host_responded_at"
        case checkInTimeSnapshot = "check_in_time"
        case checkOutTimeSnapshot = "check_out_time"
        case priceBreakdown = "price_breakdown"
    }
}

struct BookingGuest: Codable {
    let fullName: String?
    let avatarUrl: String?
    let rating: Double?
    let reviewCount: Int?
    let joinedYear: Int?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case rating
        case reviewCount = "review_count"
        case joinedYear = "joined_year"
    }
}

struct BookingListing: Codable {
    let id: String
    let title: String
    let city: String
    let images: [String]
}

enum BookingStatus: String, Codable {
    case pending
    case requested
    case confirmed
    case cancelled
}

enum PaymentStatus: String, Codable {
    case pending
    case paid
    case failed
    case refunded
}

enum TransferStatus: String, Codable {
    case pending
    case transferred
    case reversed
    case not_applicable
}

// MARK: - Review

struct Review: Codable, Identifiable {
    let id: String
    let bookingId: String
    let listingId: String
    let userId: String
    let reviewerRole: String?
    let revieweeId: String?
    let rating: Int
    let comment: String
    let createdAt: String?
    let profile: ReviewProfile?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment, profile
        case bookingId = "booking_id"
        case listingId = "listing_id"
        case userId = "user_id"
        case reviewerRole = "reviewer_role"
        case revieweeId = "reviewee_id"
        case createdAt = "created_at"
    }
}

struct ReviewProfile: Codable {
    let fullName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Conversation & Message

struct Conversation: Codable, Identifiable {
    let id: String
    let listingId: String
    let guestId: String
    let hostId: String
    let bookingId: String?
    let lastMessageAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case guestId = "guest_id"
        case hostId = "host_id"
        case bookingId = "booking_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
    }
}

struct Message: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let read: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content, read
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}

// MARK: - Favorite

struct Favorite: Codable, Identifiable {
    let id: String
    let userId: String
    let listingId: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case listingId = "listing_id"
    }
}
