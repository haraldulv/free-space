import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class ListingFormModel: ObservableObject {
    // MARK: - Step tracking
    @Published var currentStep = 0
    @Published var isSubmitting = false
    @Published var error: String?

    /// 15-stegs fullscreen-flow (0 Velkomst → 14 Klar).
    /// Steg 5 = Plass-kjøretøy, steg 6 = Plass-pris, steg 7 = Plass-tillegg
    /// (alle tre er mini-wizards med én plass per slide).
    /// Steg 8 = Booking (direktebooking vs godkjenn først).
    /// Steg 9 = Beskrivelse (tittel + valgfri beskrivelse av annonsen).
    let totalSteps = 16

    // MARK: - Step 1: Category
    @Published var category: ListingCategory? = .camping

    // MARK: - Step 2: Address (m/ skjul-toggle)
    @Published var address = ""
    @Published var city = ""
    @Published var region = ""
    @Published var lat: Double = 0
    @Published var lng: Double = 0
    @Published var hideExactLocation = false

    // MARK: - Step 3: Spot count + listing-level info
    @Published var spots = 1
    /// Default-biltyper som settes på nye plasser. Multi-select fra build 61+.
    /// Per-plass vehicleTypes overstyrer dette.
    @Published var defaultVehicleTypes: [VehicleType] = [.motorhome]
    /// Listing-nivå tittel — autogenereres fra by hvis tom ved publisering.
    @Published var title = ""
    @Published var internalName = ""
    @Published var description = ""

    // MARK: - Steps 4–5: Plasser
    @Published var spotMarkers: [SpotMarker] = []
    /// Hvilken plass som vises i SpotDetailsStep mini-wizarden (én plass per slide).
    /// Hovedstegtelleren forblir på steg 5 mens brukeren går gjennom plassene én etter én.
    @Published var currentSpotIndex: Int = 0

    // MARK: - Step 6: Bilder
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var imageURLs: [String] = []
    @Published var uploadingPhotos: [UploadingPhoto] = []

    // MARK: - Step 7: Fasiliteter (felles for adressen)
    @Published var selectedAmenities: Set<String> = []

    // MARK: - Step 8: Velkomst-/utsjekkmelding (frivillig)
    @Published var checkInTime = "15:00"
    @Published var checkOutTime = "11:00"
    @Published var checkinMessage = ""
    @Published var checkoutMessage = ""
    @Published var checkoutMessageSendHoursBefore: Int = 2
    @Published var skippedMessages = false

    // MARK: - Step 9: Kalender
    @Published var blockedDates: Set<String> = []
    /// Time-bånd for parkering per time. Lagres som listing_pricing_rules
    /// (kind='hourly') etter at annonsen er publisert.
    @Published var pricingBands: [WizardPricingBand] = []

    // MARK: - Listing-level (settes ved review)
    @Published var instantBooking = true
    /// Listing-nivå priceUnit — derives fra kategori (camping=natt, parkering=time/døgn).
    /// Per-plass priceUnit i SpotMarker overstyrer denne for visning av plass-pris.
    @Published var priceUnit: PriceUnit = .natt

    /// Settes når kategori velges — bytter også defaultPriceUnit og defaultVehicleTypes.
    func setCategory(_ newCategory: ListingCategory) {
        category = newCategory
        priceUnit = PriceUnit.defaultUnit(for: newCategory)
        // Reset default biltyper til kategori-relevante valg
        let available = VehicleType.available(for: newCategory)
        defaultVehicleTypes = available.isEmpty ? [] : [available.first!]
    }

    /// Effektiv priceUnit for en gitt plass — spot.priceUnit eller fallback til listing-nivå.
    func effectivePriceUnit(for spot: SpotMarker) -> PriceUnit {
        spot.priceUnit ?? priceUnit
    }

    // MARK: - Step labels (for progress) — 16 steg
    var stepLabels: [String] {
        ["Velkommen", "Kategori", "Adresse", "Plasser", "Marker", "Kjøretøy", "Pris", "Tillegg", "Booking", "Beskrivelse", "Bilder", "Fasiliteter", "Meldinger", "Prisbånd", "Kalender", "Klar"]
    }

    /// Pris-bånd-steget (13) er kun relevant for parkering per time.
    /// Andre kategorier hopper over det automatisk i goNext/goBack.
    var skipsPricingRulesStep: Bool {
        if category != .parking { return true }
        if priceUnit == .hour { return false }
        if spotMarkers.contains(where: { $0.priceUnit == .hour }) { return false }
        return true
    }

    // MARK: - Validation per step

    /// Brukes av WizardNavBar til å disable Neste-knappen når påkrevde felter mangler.
    /// Speiler `validateCurrentStep()` men returnerer bool i stedet for streng.
    var canAdvance: Bool {
        validateCurrentStep() == nil
    }

    func validateCurrentStep() -> String? {
        switch currentStep {
        case 0: return nil  // Velkomst — alltid gyldig
        case 1: if category == nil { return "Velg en kategori" }
        case 2:
            if address.trimmingCharacters(in: .whitespaces).isEmpty { return "Adresse er påkrevd" }
            if city.trimmingCharacters(in: .whitespaces).isEmpty { return "By er påkrevd" }
            if lat == 0 && lng == 0 { return "Velg en lokasjon fra forslagene" }
        case 3:
            if spots < 1 { return "Du må ha minst én plass" }
        case 4:
            if spotMarkers.count < spots { return "Marker alle \(spots) plassene på kartet" }
        case 5:
            // Mini-wizard Kjøretøy: valider biltype-valg + maks-lengde for store kjøretøy.
            guard spotMarkers.indices.contains(currentSpotIndex) else { return "Ingen plass valgt" }
            let spot = spotMarkers[currentSpotIndex]
            if spot.effectiveVehicleTypes.isEmpty {
                return "Velg minst én biltype"
            }
            // Bobil/campingbil/van krever maks-lengde — gjest må vite om sitt
            // kjøretøy passer. Hvis utleier ikke har tallet, må biltypen tas vekk.
            let needsLength = spot.effectiveVehicleTypes.contains(where: { !$0.isCompact })
            if needsLength, (spot.vehicleMaxLength ?? 0) < 1 {
                return "Sett maks lengde i meter"
            }
        case 6:
            // Mini-wizard Pris: valider pris på gjeldende plass.
            guard spotMarkers.indices.contains(currentSpotIndex) else { return "Ingen plass valgt" }
            let p = spotMarkers[currentSpotIndex].price ?? 0
            if p < 1 { return "Sett pris" }
        case 7:
            // Mini-wizard Tillegg — alltid gyldig (alt valgfritt)
            return nil
        case 8:
            // Booking-modus: bool kan ikke være ugyldig. Default = direktebooking.
            return nil
        case 9:
            // Beskrivelse: tittel er påkrevd så annonsen får et meningsfylt
            // navn. Beskrivelse forblir valgfri.
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "Skriv en tittel" }
            if trimmed.count > 80 { return "Tittel kan være maks 80 tegn" }
        case 10:
            if imageURLs.isEmpty { return "Legg til minst 1 bilde" }
        default: return nil
        }
        return nil
    }

    /// Sant hvis nåværende hovedsteg har mini-wizard (én plass per slide).
    /// Brukes til å rute goNext/goBack riktig + til å vise plass-indikator
    /// over progress-baren i CreateListingView.
    var currentStepHasMiniWizard: Bool {
        currentStep == 5 || currentStep == 6 || currentStep == 7
    }

    /// Visuell fremdrift 0..1 — tar hensyn til at mini-wizard-stegene
    /// (Kjøretøy/Pris/Tillegg) gjentas per plass slik at progress-baren
    /// fyller seg jevnt gjennom hele opprettelsen, ikke "spoler tilbake"
    /// når vi starter på neste plass.
    var displayProgress: Double {
        let spotCount = max(1, spotMarkers.count)
        // 5 pre-mini (0–4) + 3*N mini + 8 post-mini (8 Booking → 15 Klar)
        let totalVirtual = 13 + 3 * spotCount
        let pos: Int
        if currentStep < 5 {
            pos = currentStep
        } else if currentStep <= 7 {
            pos = 5 + currentSpotIndex * 3 + (currentStep - 5)
        } else {
            pos = 5 + 3 * spotCount + (currentStep - 8)
        }
        guard totalVirtual > 1 else { return 1 }
        return Double(pos) / Double(totalVirtual - 1)
    }

    func goNext() {
        if let err = validateCurrentStep() {
            error = err
            return
        }
        error = nil

        // Mini-wizard: kjør hele plassen (Kjøretøy → Pris → Tillegg) før neste plass.
        if currentStepHasMiniWizard {
            if currentStep < 7 {
                // Steg 5 eller 6 → neste mini-wizard-steg på SAMME plass.
                withAnimation(.easeInOut(duration: 0.32)) { currentStep += 1 }
                return
            }
            // Steg 7 (Tillegg): plassen er ferdig.
            if currentSpotIndex < spotMarkers.count - 1 {
                // Hopp til neste plass — start på Kjøretøy igjen.
                withAnimation(.easeInOut(duration: 0.32)) {
                    currentSpotIndex += 1
                    currentStep = 5
                }
                return
            }
            // Siste plass ferdig — gå videre til Booking (steg 8).
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 8 }
            return
        }

        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep += 1
                // Inn i mini-wizard fra steg 4 → start på første plass.
                if currentStepHasMiniWizard {
                    currentSpotIndex = 0
                }
                // Hopp over Prisbånd-steget for ikke-parkering-per-time.
                if currentStep == 13 && skipsPricingRulesStep {
                    currentStep = 14
                }
            }
        }
    }

    func goBack() {
        error = nil

        if currentStepHasMiniWizard {
            // Innenfor mini-wizard: gå tilbake innenfor SAMME plass først.
            if currentStep > 5 {
                withAnimation(.easeInOut(duration: 0.32)) { currentStep -= 1 }
                return
            }
            // Steg 5 (Kjøretøy): gå til Tillegg (7) av forrige plass.
            if currentSpotIndex > 0 {
                withAnimation(.easeInOut(duration: 0.32)) {
                    currentSpotIndex -= 1
                    currentStep = 7
                }
                return
            }
            // Første plass på steg 5 — tilbake til MarkSpots (4).
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 4 }
            return
        }

        // Hopp over Prisbånd-steget når brukeren går bakover for ikke-parkering-per-time
        if currentStep == 14 && skipsPricingRulesStep {
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 12 }
            return
        }

        if currentStep > 0 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep -= 1
                // Bakover INN i mini-wizard fra Booking (steg 8) → siste plass, Tillegg.
                if currentStepHasMiniWizard && !spotMarkers.isEmpty {
                    currentSpotIndex = spotMarkers.count - 1
                    currentStep = 7
                }
            }
        }
    }

    func skip() {
        // Brukes på MessagesStep ("Jeg tar det senere")
        skippedMessages = true
        error = nil
        goNext()
    }

    // MARK: - Spot helpers

    /// Brukes ved overgang fra MarkSpotsStep til SpotDetailsStep:
    /// Sørger for at vi har riktig antall SpotMarker (matcher `spots`-tellaren).
    /// Mini-wizarden tillater ikke å legge til/fjerne plasser underveis.
    func ensureSpotCountMatchesSpots() {
        while spotMarkers.count < spots {
            let centerLat = lat != 0 ? lat : 59.9139
            let centerLng = lng != 0 ? lng : 10.7522
            let offset = 0.0001 * Double(spotMarkers.count + 1)
            let new = SpotMarker(
                id: UUID().uuidString.lowercased(),
                lat: centerLat + offset,
                lng: centerLng + offset,
                label: "Plass \(spotMarkers.count + 1)",
                description: nil,
                price: nil,
                vehicleMaxLength: nil,
                vehicleTypes: defaultVehicleTypes,
                vehicleType: nil,
                priceUnit: category == .parking ? priceUnit : nil,
                extras: nil,
                blockedDates: nil,
                checkinMessage: nil,
                images: nil
            )
            spotMarkers.append(new)
        }
        // Hvis brukeren reduserer antall plasser, kutt fra slutten.
        if spotMarkers.count > spots {
            spotMarkers = Array(spotMarkers.prefix(spots))
        }
        if currentSpotIndex >= spotMarkers.count {
            currentSpotIndex = max(0, spotMarkers.count - 1)
        }
    }

    func isSpotComplete(_ index: Int) -> Bool {
        guard spotMarkers.indices.contains(index) else { return false }
        let s = spotMarkers[index]
        // Navn settes automatisk ved opprettelse — sjekkes ikke.
        let hasPrice = (s.price ?? 0) > 0
        let hasVehicleTypes = !s.effectiveVehicleTypes.isEmpty
        return hasPrice && hasVehicleTypes
    }

    // MARK: - Amenities for current category

    var availableAmenities: [AmenityType] {
        switch category {
        case .parking:
            return [.evCharging, .covered, .securityCamera, .gated, .lighting, .handicapAccessible]
        case .camping:
            return [.water, .wasteDisposal, .toilets, .showers, .wifi, .campfire, .lakeAccess, .mountainView, .petsAllowed, .handicapAccessible]
        case nil:
            return AmenityType.allCases
        }
    }

    // MARK: - Build listing input for Supabase

    func buildInput(hostId: String, profile: Profile?) -> CreateListingInput {
        // Auto-derive listing-nivå pris og maxVehicleLength fra plasser så
        // søkefilter på web (som leser listing-nivå) fortsatt fungerer.
        let prices = spotMarkers.compactMap { $0.price }.filter { $0 > 0 }
        let derivedListingPrice = prices.min() ?? 0
        let lengths = spotMarkers.compactMap { $0.vehicleMaxLength }.filter { $0 > 0 }
        let derivedMaxLength = lengths.max()
        // Listing-nivå vehicleType: bruk første biltype fra første plass (backward-compat for web-søkefilter)
        let derivedVehicleType: VehicleType = spotMarkers.first?.effectiveVehicleTypes.first
            ?? defaultVehicleTypes.first
            ?? .motorhome
        // Fallback-tittel hvis utleier ikke har skrevet noe — foretrekk
        // konkret stedsnavn (address) før city/region/Norge.
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let resolvedTitle: String = {
            if !trimmedTitle.isEmpty { return trimmedTitle }
            let categoryName = category?.displayName ?? "Plass"
            let location = !address.isEmpty ? address
                : !city.isEmpty ? city
                : !region.isEmpty ? region
                : "Norge"
            return "\(categoryName) i \(location)"
        }()

        return CreateListingInput(
            id: UUID().uuidString.lowercased(),
            hostId: hostId,
            title: resolvedTitle,
            internalName: internalName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : internalName.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: category?.rawValue ?? "camping",
            vehicleType: derivedVehicleType.rawValue,
            city: city,
            region: region,
            address: address,
            lat: lat,
            lng: lng,
            price: derivedListingPrice,
            priceUnit: priceUnit.rawValue,
            spots: spotMarkers.count,
            images: imageURLs,
            amenities: Array(selectedAmenities),
            instantBooking: instantBooking,
            hideExactLocation: hideExactLocation,
            spotMarkers: spotMarkers,
            blockedDates: Array(blockedDates).sorted(),
            maxVehicleLength: derivedMaxLength,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            checkinMessage: skippedMessages || checkinMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : checkinMessage,
            checkoutMessage: skippedMessages || checkoutMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : checkoutMessage,
            checkoutMessageSendHoursBefore: checkoutMessageSendHoursBefore,
            extras: [],
            hostName: profile?.fullName ?? "",
            hostAvatar: profile?.avatarUrl ?? "",
            isActive: true
        )
    }
}

// MARK: - Uploading photo (local preview + in-flight upload)

struct UploadingPhoto: Identifiable, Equatable {
    let id = UUID()
    let data: Data
}

// MARK: - Image compression helper

enum ImageCompression {
    /// Resize to max 2048px longest side (ved scale=1 så det er faktisk 2048px),
    /// re-enkod som JPEG og komprimér aggressivt hvis resultatet fortsatt
    /// overskrider Supabase sitt 5 MB-tak.
    static func compressForUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 2048
        let largestSide = max(image.size.width, image.size.height)
        let scale = largestSide > maxDimension ? maxDimension / largestSide : 1.0
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        let maxBytes = 4 * 1024 * 1024
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let jpeg = resized.jpegData(compressionQuality: CGFloat(quality)),
               jpeg.count <= maxBytes {
                return jpeg
            }
        }
        return resized.jpegData(compressionQuality: 0.3)
    }
}

// MARK: - Codable input for Supabase insert

struct CreateListingInput: Encodable {
    let id: String
    let hostId: String
    let title: String
    let internalName: String?
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
    let checkinMessage: String?
    let checkoutMessage: String?
    let checkoutMessageSendHoursBefore: Int
    let extras: [ListingExtra]
    let hostName: String
    let hostAvatar: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, region, address, lat, lng, price, spots, images, amenities, extras
        case hostId = "host_id"
        case internalName = "internal_name"
        case vehicleType = "vehicle_type"
        case priceUnit = "price_unit"
        case instantBooking = "instant_booking"
        case hideExactLocation = "hide_exact_location"
        case spotMarkers = "spot_markers"
        case blockedDates = "blocked_dates"
        case maxVehicleLength = "max_vehicle_length"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case checkinMessage = "checkin_message"
        case checkoutMessage = "checkout_message"
        case checkoutMessageSendHoursBefore = "checkout_message_send_hours_before"
        case hostName = "host_name"
        case hostAvatar = "host_avatar"
        case isActive = "is_active"
    }
}
