import Foundation

/// Snapshot av wizardens state — lagres som JSON i UserDefaults så verten
/// kan stoppe midt i og fortsette senere fra "Mine annonser".
///
/// Inneholder kun Codable-felter; selectedPhotos (PhotosPickerItem) og
/// uploadingPhotos kan ikke lagres — kun de allerede opplastede imageURLs.
struct DraftListing: Codable {
    var category: ListingCategory?
    var address: String
    var city: String
    var region: String
    var lat: Double
    var lng: Double
    var hideExactLocation: Bool
    var spots: Int
    var defaultVehicleTypes: [VehicleType]
    var title: String
    var internalName: String
    var description: String
    var spotMarkers: [SpotMarker]
    var currentSpotIndex: Int
    var pricingBandsSharedAcrossSpots: Bool
    var imageURLs: [String]
    var selectedAmenities: [String]
    var checkInTime: String
    var checkOutTime: String
    var checkinMessage: String
    var checkoutMessage: String
    var checkoutMessageSendHoursBefore: Int
    var skippedMessages: Bool
    var blockedDates: [String]
    var instantBooking: Bool
    var priceUnit: PriceUnit
    var openingHours: OpeningHours?
    var currentStep: Int
    var savedAt: Date

    /// Tittel som vises på "Fortsett utkast"-kortet i Mine annonser.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        if !address.isEmpty { return address }
        if let category {
            return "Utkast: \(category.displayName)"
        }
        return "Utkast"
    }

    /// Beskrivende tekst — viser hvor langt verten har kommet og når sist lagret.
    var displaySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "nb_NO")
        return "Sist endret \(formatter.string(from: savedAt))"
    }
}

/// UserDefaults-bakket lagring av utkast. Per-user-scoped så ulike kontoer
/// på samme enhet ikke ser hverandres utkast.
enum DraftStorage {
    private static func key(for userId: String) -> String {
        "tuno.draftListing.\(userId.lowercased())"
    }

    /// Lagre eller overskriv eksisterende utkast for denne brukeren.
    static func save(_ draft: DraftListing, userId: String) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key(for: userId))
    }

    /// Returner lagret utkast, eller nil hvis ingen finnes / decode feiler.
    static func load(userId: String) -> DraftListing? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(DraftListing.self, from: data)
    }

    /// Slett utkastet (etter publisering eller eksplisitt forkast).
    static func clear(userId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userId))
    }

    /// Sjekk om det finnes et utkast for denne brukeren.
    static func exists(userId: String) -> Bool {
        UserDefaults.standard.data(forKey: key(for: userId)) != nil
    }
}
