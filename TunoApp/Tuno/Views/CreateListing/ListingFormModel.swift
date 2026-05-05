import SwiftUI
import PhotosUI
import UIKit

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

@MainActor
final class ListingFormModel: ObservableObject {
    // MARK: - Step tracking
    @Published var currentStep = 0
    @Published var isSubmitting = false
    @Published var error: String?

    /// 18-stegs fullscreen-flow (0 Velkomst → 17 Klar).
    /// Mini-wizard 5-9 (5 steg per plass): Kjøretøy → Tilgjengelighet → Pris
    /// → Pris-variasjon → Tillegg. Etter mini-wizard kommer Rabatter (10) for
    /// parkering, deretter Booking (11) → Klar (17).
    let totalSteps = 18

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

    // MARK: - Steps 4–8: Plasser (mini-wizard)
    @Published var spotMarkers: [SpotMarker] = []
    /// Hvilken plass som vises i mini-wizarden (én plass per slide).
    @Published var currentSpotIndex: Int = 0
    /// Per-plass tilgjengelighet og pris-variasjon (form-state). Nøkkel = SpotMarker.id.
    /// Lagres ikke i SpotMarker — settes om til listing_pricing_rules + overrides ved publisering.
    @Published var availabilityBySpotId: [String: WizardSpotAvailability] = [:]
    /// Felles pris-bånd på tvers av plasser. Når true: bånd som settes på spot 0
    /// kopieres til alle andre spots ved goNext. Default på.
    @Published var pricingBandsSharedAcrossSpots: Bool = true

    /// Kopier spot 0's availability til alle andre spots. Brukes når
    /// pricingBandsSharedAcrossSpots er på, etter brukeren har redigert bånd.
    func syncFirstSpotAvailabilityToAll() {
        guard let firstId = spotMarkers.first?.id else { return }
        let template = availability(for: firstId)
        for spot in spotMarkers.dropFirst() {
            if let id = spot.id {
                availabilityBySpotId[id] = template
            }
        }
    }

    // MARK: - Step 11: Bilder
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var imageURLs: [String] = []
    @Published var uploadingPhotos: [UploadingPhoto] = []

    // MARK: - Step 12: Fasiliteter (felles for adressen)
    @Published var selectedAmenities: Set<String> = []

    // MARK: - Step 13: Velkomst-/utsjekkmelding (frivillig)
    @Published var checkInTime = "15:00"
    @Published var checkOutTime = "11:00"
    @Published var checkinMessage = ""
    @Published var checkoutMessage = ""
    @Published var checkoutMessageSendHoursBefore: Int = 2
    @Published var skippedMessages = false

    // MARK: - Step 15: Kalender (blocked_dates) — kun camping
    @Published var blockedDates: Set<String> = []

    // MARK: - Visningsmodus (full-skjerm, satt fra mini-wizard)
    /// True når et steg ønsker å skjule progress-bar / wizard-chrome (eks.
    /// SpotPriceVariation editing-fasen som vil dekke hele skjermen).
    @Published var fullscreenStep: Bool = false

    // MARK: - Listing-level (settes ved review)
    @Published var instantBooking = true
    /// Listing-nivå priceUnit — derives fra kategori (camping=natt, parkering=time).
    @Published var priceUnit: PriceUnit = .time
    /// Listing-nivå åpningstid (parkering). nil = døgnåpent.
    @Published var openingHours: OpeningHours? = nil
    /// Minimum antall dager bruker kan booke. nil = ingen minimum.
    @Published var minStayDays: Int? = nil
    /// Maksimum antall dager bruker kan booke. nil = ingen maksimum.
    @Published var maxStayDays: Int? = nil

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

    /// Hjelper: hent (eller initier) availability-state for en plass.
    func availability(for spotId: String) -> WizardSpotAvailability {
        availabilityBySpotId[spotId] ?? WizardSpotAvailability()
    }

    // MARK: - Draft persistence

    /// Snapshot av nåværende wizard-state for utkast-lagring.
    func toDraft() -> DraftListing {
        DraftListing(
            category: category,
            address: address,
            city: city,
            region: region,
            lat: lat,
            lng: lng,
            hideExactLocation: hideExactLocation,
            spots: spots,
            defaultVehicleTypes: defaultVehicleTypes,
            title: title,
            internalName: internalName,
            description: description,
            spotMarkers: spotMarkers,
            currentSpotIndex: currentSpotIndex,
            pricingBandsSharedAcrossSpots: pricingBandsSharedAcrossSpots,
            imageURLs: imageURLs,
            selectedAmenities: Array(selectedAmenities),
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            checkinMessage: checkinMessage,
            checkoutMessage: checkoutMessage,
            checkoutMessageSendHoursBefore: checkoutMessageSendHoursBefore,
            skippedMessages: skippedMessages,
            blockedDates: Array(blockedDates),
            instantBooking: instantBooking,
            priceUnit: priceUnit,
            openingHours: openingHours,
            minStayDays: minStayDays,
            maxStayDays: maxStayDays,
            currentStep: currentStep,
            savedAt: Date()
        )
    }

    /// Restore wizard-state fra et lagret utkast.
    func loadFromDraft(_ draft: DraftListing) {
        category = draft.category
        address = draft.address
        city = draft.city
        region = draft.region
        lat = draft.lat
        lng = draft.lng
        hideExactLocation = draft.hideExactLocation
        spots = draft.spots
        defaultVehicleTypes = draft.defaultVehicleTypes
        title = draft.title
        internalName = draft.internalName
        description = draft.description
        spotMarkers = draft.spotMarkers
        currentSpotIndex = draft.currentSpotIndex
        pricingBandsSharedAcrossSpots = draft.pricingBandsSharedAcrossSpots
        imageURLs = draft.imageURLs
        selectedAmenities = Set(draft.selectedAmenities)
        checkInTime = draft.checkInTime
        checkOutTime = draft.checkOutTime
        checkinMessage = draft.checkinMessage
        checkoutMessage = draft.checkoutMessage
        checkoutMessageSendHoursBefore = draft.checkoutMessageSendHoursBefore
        skippedMessages = draft.skippedMessages
        blockedDates = Set(draft.blockedDates)
        instantBooking = draft.instantBooking
        priceUnit = draft.priceUnit
        openingHours = draft.openingHours
        minStayDays = draft.minStayDays
        maxStayDays = draft.maxStayDays
        currentStep = draft.currentStep
    }

    /// Lagre utkast for denne brukeren. Kalles auto fra goNext/goBack
    /// + ved bruker-eksplisitt close.
    func saveDraft(userId: String) {
        // Sparer ikke utkast hvis bruker er på Velkomst-steget (0) — ingen
        // meningsfulle data ennå, og det forhindrer at en tom "Fortsett"-
        // banner dukker opp etter at de bare titta på første skjerm.
        guard currentStep > 0 else { return }
        DraftStorage.save(toDraft(), userId: userId)
    }

    /// Slett utkast (kalles etter publisering).
    func clearDraft(userId: String) {
        DraftStorage.clear(userId: userId)
    }

    /// Hjelper: oppdater availability-state for en plass.
    func setAvailability(_ avail: WizardSpotAvailability, for spotId: String) {
        availabilityBySpotId[spotId] = avail
    }

    /// Sant hvis ANY plass har bånd. Brukes til å sette listings.availability_mode.
    var hasAnyAvailabilityBands: Bool {
        availabilityBySpotId.values.contains { !$0.bands.isEmpty }
    }

    /// Generisk safe-subscript for arrays.
    func spotMarker(at index: Int) -> SpotMarker? {
        spotMarkers.indices.contains(index) ? spotMarkers[index] : nil
    }

    // MARK: - Step labels (for progress) — 18 steg
    // Booking-steget er flyttet rett etter Marker-plasser (steg 5) slik at
    // verten setter booking-modus + min/maks-dager før de går inn i mini-
    // wizarden per plass. Mini-wizarden er nå steg 6–10.
    var stepLabels: [String] {
        ["Velkommen", "Kategori", "Adresse", "Plasser", "Marker", "Booking", "Kjøretøy", "Tilgjengelighet", "Pris", "Prisvariasjon", "Tillegg", "Rabatter", "Beskrivelse", "Bilder", "Fasiliteter", "Meldinger", "Kalender", "Klar"]
    }

    /// Åpningstid-steget (7) er listing-nivå og kun for parkering. Default
    /// døgnåpent (form.openingHours = nil). Vises på første plass-iterasjon i
    /// mini-wizarden — etterfølgende plasser hopper steget.
    var skipsAvailabilityStep: Bool {
        category != .parking
    }

    /// Pris-variasjon-steget (9) er per plass.
    /// - Parkering: hopper alltid over (ingen hourly-bånd lenger etter
    ///   parkering-per-dag-refaktoren).
    /// - Camping: aktivert — viser sesong-bånd-kalender (WizardSeasonalCalendarView).
    func skipsPriceVariationStep(forSpotIndex idx: Int) -> Bool {
        if category == .camping {
            return false  // camping bruker sesong-bånd
        }
        return true  // parkering: ingen pris-variasjon i wizard for nå
    }

    /// Rabatter-steget (11) gir kr-priser for uke/måned/3mnd/6mnd/år-bookinger.
    /// Kun relevant for parkering — camping bruker en flat per-døgn-pris.
    var skipsRabatterStep: Bool {
        category != .parking
    }

    /// Kalender-steget (16) blokkerer datoer. For parkering er tilgjengelighet
    /// allerede definert via åpningstid, så vi hopper over.
    /// Camping bruker fortsatt CalendarStep til å blokkere spesifikke datoer.
    var skipsCalendarStep: Bool {
        category == .parking
    }

    // MARK: - Validation per step

    /// Brukes av WizardNavBar til å disable Neste-knappen når påkrevde felter mangler.
    /// Speiler `validateCurrentStep()` men returnerer bool i stedet for streng.
    var canAdvance: Bool {
        validateCurrentStep() == nil
    }

    func validateCurrentStep() -> String? {
        switch currentStep {
        case 0: return nil
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
            // Booking — instant/request + min/maks. Min ≤ maks.
            if let minD = minStayDays, let maxD = maxStayDays, minD > maxD {
                return "Minimum kan ikke være større enn maksimum"
            }
            return nil
        case 6:
            // Mini-wizard Kjøretøy
            guard spotMarkers.indices.contains(currentSpotIndex) else { return "Ingen plass valgt" }
            let spot = spotMarkers[currentSpotIndex]
            if spot.effectiveVehicleTypes.isEmpty { return "Velg minst én biltype" }
            let needsLength = spot.effectiveVehicleTypes.contains(where: { !$0.isCompact })
            if needsLength, (spot.vehicleMaxLength ?? 0) < 1 { return "Sett maks lengde i meter" }
        case 7:
            // Mini-wizard Tilgjengelighet — alltid gyldig
            return nil
        case 8:
            // Mini-wizard Pris: minst én pris satt
            guard spotMarkers.indices.contains(currentSpotIndex) else { return "Ingen plass valgt" }
            let s = spotMarkers[currentSpotIndex]
            let hasHour = (s.pricePerHour ?? 0) > 0
            let hasNight = (s.pricePerNight ?? 0) > 0
            let hasLegacy = (s.price ?? 0) > 0
            if !hasHour && !hasNight && !hasLegacy { return "Sett pris" }
        case 9:
            // Mini-wizard Pris-variasjon — alltid gyldig
            return nil
        case 10:
            // Mini-wizard Tillegg — alltid gyldig
            return nil
        case 11:
            // Rabatter — alltid valid (alle tier-priser er frivillige)
            return nil
        case 12:
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "Skriv en tittel" }
            if trimmed.count > 80 { return "Tittel kan være maks 80 tegn" }
        case 13:
            if imageURLs.isEmpty { return "Legg til minst 1 bilde" }
        default: return nil
        }
        return nil
    }

    /// Sant hvis nåværende hovedsteg har mini-wizard (én plass per slide).
    /// Mini-wizard er nå 5 steg: Kjøretøy (6), Tilgjengelighet (7), Pris (8),
    /// Pris-variasjon (9), Tillegg (10).
    var currentStepHasMiniWizard: Bool {
        currentStep >= 6 && currentStep <= 10
    }

    /// Visuell fremdrift 0..1. Mini-wizard utgjør 5 steg per plass.
    var displayProgress: Double {
        let spotCount = max(1, spotMarkers.count)
        // 6 pre-mini (0–5: Velkommen → Booking) + 5*N mini + 7 post-mini (11 Rabatter → 17 Klar)
        let totalVirtual = 13 + 5 * spotCount
        let pos: Int
        if currentStep < 6 {
            pos = currentStep
        } else if currentStep <= 10 {
            pos = 6 + currentSpotIndex * 5 + (currentStep - 6)
        } else {
            pos = 6 + 5 * spotCount + (currentStep - 11)
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

        // Mini-wizard 6-10: Kjøretøy → Tilgjengelighet → Pris → Pris-variasjon → Tillegg
        if currentStepHasMiniWizard {
            if currentStep < 10 {
                var next = currentStep + 1
                // Åpningstid (7) er listing-nivå — vis kun for parkering, og
                // kun på første plass-iterasjon (currentSpotIndex == 0).
                if next == 7 && (skipsAvailabilityStep || currentSpotIndex > 0) { next = 8 }
                // Hopp over Pris-variasjon (9) hvis plassen ikke har bånd
                if next == 9 && skipsPriceVariationStep(forSpotIndex: currentSpotIndex) { next = 10 }
                withAnimation(.easeInOut(duration: 0.32)) { currentStep = next }
                return
            }
            // Steg 10 (Tillegg): plassen er ferdig
            if currentSpotIndex < spotMarkers.count - 1 {
                withAnimation(.easeInOut(duration: 0.32)) {
                    currentSpotIndex += 1
                    currentStep = 6
                }
                return
            }
            // Siste plass ferdig — gå til Rabatter (11), eller hopp til Beskrivelse (12) for camping.
            let nextAfterMini = skipsRabatterStep ? 12 : 11
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = nextAfterMini }
            return
        }

        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep += 1
                if currentStepHasMiniWizard {
                    currentSpotIndex = 0
                }
                // Hopp over Rabatter (11) for camping
                if currentStep == 11 && skipsRabatterStep {
                    currentStep = 12
                }
                // Hopp over Kalender (16) for parkering
                if currentStep == 16 && skipsCalendarStep {
                    currentStep = 17
                }
            }
        }
    }

    func goBack() {
        error = nil

        if currentStepHasMiniWizard {
            if currentStep > 6 {
                var prev = currentStep - 1
                if prev == 7 && (skipsAvailabilityStep || currentSpotIndex > 0) { prev = 6 }
                if prev == 9 && skipsPriceVariationStep(forSpotIndex: currentSpotIndex) { prev = 8 }
                withAnimation(.easeInOut(duration: 0.32)) { currentStep = prev }
                return
            }
            // Steg 6 (Kjøretøy): gå til Tillegg (10) av forrige plass
            if currentSpotIndex > 0 {
                withAnimation(.easeInOut(duration: 0.32)) {
                    currentSpotIndex -= 1
                    currentStep = 10
                }
                return
            }
            // Første plass på steg 6 — tilbake til Booking (5)
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 5 }
            return
        }

        // Hopp over Kalender (16) bakover for parkering
        if currentStep == 17 && skipsCalendarStep {
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 15 }
            return
        }

        if currentStep > 0 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep -= 1
                // Hopp over Rabatter (11) bakover for camping
                if currentStep == 11 && skipsRabatterStep {
                    currentStep = 10
                }
                // Bakover INN i mini-wizard fra Rabatter/Beskrivelse → siste plass, Tillegg (10)
                if currentStepHasMiniWizard && !spotMarkers.isEmpty {
                    currentSpotIndex = spotMarkers.count - 1
                    currentStep = 10
                }
            }
        }
    }

    /// Hopp direkte til et bestemt steg. Brukes fra PublishStep for hurtignav.
    /// `spotIndex` settes når mål-steget er en mini-wizard-step (6-10).
    func goTo(step: Int, spotIndex: Int? = nil) {
        guard step >= 0, step < totalSteps else { return }
        error = nil
        withAnimation(.easeInOut(duration: 0.32)) {
            if let spotIndex, spotMarkers.indices.contains(spotIndex) {
                currentSpotIndex = spotIndex
            }
            currentStep = step
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
                pricePerHour: nil,
                pricePerNight: nil,
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
        let hasPrice = (s.price ?? 0) > 0 || (s.pricePerHour ?? 0) > 0 || (s.pricePerNight ?? 0) > 0
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
        // Parkering bruker price (kr/dag), camping bruker pricePerNight.
        let primaryPrices = spotMarkers.compactMap { spot -> Int? in
            if let n = spot.pricePerNight, n > 0 { return n }
            return spot.price
        }.filter { $0 > 0 }
        let derivedListingPrice = primaryPrices.min() ?? 0

        let nightPrices = spotMarkers.compactMap { $0.pricePerNight }.filter { $0 > 0 }
        let derivedPricePerNight: Int? = category == .parking ? nil : nightPrices.min()

        let lengths = spotMarkers.compactMap { $0.vehicleMaxLength }.filter { $0 > 0 }
        let derivedMaxLength = lengths.max()
        let derivedVehicleType: VehicleType = spotMarkers.first?.effectiveVehicleTypes.first
            ?? defaultVehicleTypes.first
            ?? .motorhome

        // Parkering = .time (kr/dag), camping = .natt. .hour er fjernet fra DB.
        let derivedPriceUnit: PriceUnit = category == .parking ? .time : .natt

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
            priceUnit: derivedPriceUnit.rawValue,
            pricePerNight: derivedPricePerNight,
            openingHours: openingHours,
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
            isActive: true,
            minStayDays: minStayDays,
            maxStayDays: maxStayDays
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
    let pricePerNight: Int?
    let openingHours: OpeningHours?
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
    let minStayDays: Int?
    let maxStayDays: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, region, address, lat, lng, price, spots, images, amenities, extras
        case hostId = "host_id"
        case internalName = "internal_name"
        case vehicleType = "vehicle_type"
        case priceUnit = "price_unit"
        case pricePerNight = "price_per_night"
        case openingHours = "opening_hours"
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
        case minStayDays = "min_stay_days"
        case maxStayDays = "max_stay_days"
    }
}
