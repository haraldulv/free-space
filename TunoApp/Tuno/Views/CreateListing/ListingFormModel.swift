import SwiftUI
import PhotosUI

@MainActor
final class ListingFormModel: ObservableObject {
    // MARK: - Step tracking
    @Published var currentStep = 0
    @Published var isSubmitting = false
    @Published var error: String?

    let totalSteps = 9

    // MARK: - Step 0: Category & Vehicle Type
    @Published var category: ListingCategory?
    @Published var vehicleType: VehicleType = .motorhome

    // MARK: - Step 1: Basic Info
    @Published var title = ""
    @Published var description = ""
    @Published var spots = 1
    @Published var maxVehicleLength: Int?
    @Published var checkInTime = "15:00"
    @Published var checkOutTime = "11:00"

    // MARK: - Step 2: Location
    @Published var address = ""
    @Published var city = ""
    @Published var region = ""
    @Published var lat: Double = 0
    @Published var lng: Double = 0
    @Published var spotMarkers: [SpotMarker] = []
    @Published var hideExactLocation = false

    // MARK: - Step 3: Images
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var imageURLs: [String] = []
    @Published var isUploadingImages = false

    // MARK: - Step 4: Amenities
    @Published var selectedAmenities: Set<String> = []

    // MARK: - Step 5: Extras
    @Published var selectedExtras: [ListingExtra] = []

    // MARK: - Step 6: Pricing
    @Published var price = ""
    @Published var priceUnit: PriceUnit = .natt
    @Published var instantBooking = false

    // MARK: - Step 7: Availability
    @Published var blockedDates: Set<String> = []

    // MARK: - Validation

    var stepLabels: [String] {
        ["Kategori", "Detaljer", "Lokasjon", "Bilder", "Fasiliteter", "Tillegg", "Pris", "Kalender", "Publiser"]
    }

    func validateCurrentStep() -> String? {
        switch currentStep {
        case 0:
            if category == nil { return "Velg en kategori" }
        case 1:
            if title.trimmingCharacters(in: .whitespaces).count < 3 { return "Tittel må ha minst 3 tegn" }
            if description.trimmingCharacters(in: .whitespaces).count < 10 { return "Beskrivelse må ha minst 10 tegn" }
            if spots < 1 { return "Minst 1 plass" }
        case 2:
            if address.trimmingCharacters(in: .whitespaces).isEmpty { return "Adresse er påkrevd" }
            if city.trimmingCharacters(in: .whitespaces).isEmpty { return "By er påkrevd" }
            if lat == 0 && lng == 0 { return "Velg en lokasjon fra forslagene" }
        case 3:
            if imageURLs.isEmpty { return "Legg til minst 1 bilde" }
        case 6:
            if let p = Int(price), p < 1 { return "Pris må være minst 1 kr" }
            if Int(price) == nil { return "Skriv inn en gyldig pris" }
        default:
            break
        }
        return nil
    }

    func goNext() {
        if let err = validateCurrentStep() {
            error = err
            return
        }
        error = nil
        if currentStep < totalSteps - 1 {
            withAnimation { currentStep += 1 }
        }
    }

    func goBack() {
        error = nil
        if currentStep > 0 {
            withAnimation { currentStep -= 1 }
        }
    }

    // MARK: - Amenities for current category

    var availableAmenities: [AmenityType] {
        switch category {
        case .parking:
            return [.evCharging, .covered, .securityCamera, .gated, .lighting, .handicapAccessible]
        case .camping:
            return [.electricity, .water, .wasteDisposal, .toilets, .showers, .wifi, .campfire, .lakeAccess, .mountainView, .petsAllowed, .handicapAccessible]
        case nil:
            return AmenityType.allCases
        }
    }

    // MARK: - Build listing input for Supabase

    func buildInput(hostId: String, profile: Profile?) -> CreateListingInput {
        CreateListingInput(
            id: UUID().uuidString.lowercased(),
            hostId: hostId,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: category?.rawValue ?? "camping",
            vehicleType: vehicleType.rawValue,
            city: city,
            region: region,
            address: address,
            lat: lat,
            lng: lng,
            price: Int(price) ?? 0,
            priceUnit: priceUnit.rawValue,
            spots: spots,
            images: imageURLs,
            amenities: Array(selectedAmenities),
            instantBooking: instantBooking,
            hideExactLocation: hideExactLocation,
            spotMarkers: spotMarkers,
            blockedDates: Array(blockedDates).sorted(),
            maxVehicleLength: category == .camping ? maxVehicleLength : nil,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            extras: selectedExtras,
            hostName: profile?.fullName ?? "",
            hostAvatar: profile?.avatarUrl ?? "",
            isActive: true
        )
    }
}

// MARK: - Codable input for Supabase insert

struct CreateListingInput: Encodable {
    let id: String
    let hostId: String
    let title: String
    let description: String
    let category: String
    let vehicleType: String
    let city: String
    let region: String
    let address: String
    let lat: Double
    let lng: Double
    let price: Int
    let priceUnit: String
    let spots: Int
    let images: [String]
    let amenities: [String]
    let instantBooking: Bool
    let hideExactLocation: Bool
    let spotMarkers: [SpotMarker]
    let blockedDates: [String]
    let maxVehicleLength: Int?
    let checkInTime: String
    let checkOutTime: String
    let extras: [ListingExtra]
    let hostName: String
    let hostAvatar: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, region, address, lat, lng, price, spots, images, amenities, extras
        case hostId = "host_id"
        case vehicleType = "vehicle_type"
        case priceUnit = "price_unit"
        case instantBooking = "instant_booking"
        case hideExactLocation = "hide_exact_location"
        case spotMarkers = "spot_markers"
        case blockedDates = "blocked_dates"
        case maxVehicleLength = "max_vehicle_length"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case hostName = "host_name"
        case hostAvatar = "host_avatar"
        case isActive = "is_active"
    }
}
