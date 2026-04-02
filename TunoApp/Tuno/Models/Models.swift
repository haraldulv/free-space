import Foundation

// MARK: - Listing

struct Listing: Codable, Identifiable, Hashable {
    let id: String
    let hostId: String?
    let title: String
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
    let isActive: Bool?
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
        case vehicleType = "vehicle_type"
        case priceUnit = "price_unit"
        case maxVehicleLength = "max_vehicle_length"
        case instantBooking = "instant_booking"
        case spotMarkers = "spot_markers"
        case hideExactLocation = "hide_exact_location"
        case blockedDates = "blocked_dates"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case isActive = "is_active"
        case reviewCount = "review_count"
        case hostName = "host_name"
        case hostAvatar = "host_avatar"
        case hostResponseRate = "host_response_rate"
        case hostResponseTime = "host_response_time"
        case hostJoinedYear = "host_joined_year"
        case hostListingsCount = "host_listings_count"
        case createdAt = "created_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Listing, rhs: Listing) -> Bool {
        lhs.id == rhs.id
    }
}

struct SpotMarker: Codable, Hashable {
    let lat: Double
    let lng: Double
    let label: String?
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
    case car
    case campervan
    case motorhome

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
        case .motorhome: return "truck.box.fill"
        }
    }
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
    let status: BookingStatus
    let paymentStatus: PaymentStatus
    let transferStatus: TransferStatus?
    let paymentIntentId: String?
    let stripeTransferId: String?
    let licensePlate: String?
    let isRentalCar: Bool?
    let createdAt: String?

    // Joined data
    let listing: BookingListing?

    enum CodingKeys: String, CodingKey {
        case id, status, listing
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
    let rating: Int
    let comment: String
    let createdAt: String?
    let profile: ReviewProfile?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment, profile
        case bookingId = "booking_id"
        case listingId = "listing_id"
        case userId = "user_id"
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
