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
    /// True når brukeren har nådd oppsummeringen (PublishStep, currentStep ==
    /// totalSteps - 1) minst én gang i denne sesjonen. Brukes til å la
    /// Neste-knappen hoppe rett tilbake til oppsummeringen i stedet for å
    /// walke gjennom alle steg etter en liten edit.
    @Published var hasReachedSummary: Bool = false

    /// 19-stegs fullscreen-flow (0 Velkomst → 18 Klar).
    /// Booking-modus (5) og Lengde på opphold (6) er på hver sin slide.
    /// Mini-wizard 7-11 (5 steg per plass): Kjøretøy → Tilgjengelighet → Pris
    /// → Pris-variasjon → Tillegg. Etter mini-wizard kommer Rabatter (12) for
    /// parkering, deretter Beskrivelse (13) → Klar (18).
    let totalSteps = 17

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
    @Published var instantBooking = false
    /// Listing-nivå priceUnit — derives fra kategori (camping=natt, parkering=time).
    @Published var priceUnit: PriceUnit = .time
    /// Listing-nivå åpningstid (parkering). nil = døgnåpent.
    @Published var openingHours: OpeningHours? = nil
    /// Minimum antall dager bruker kan booke. Default 1 (nedre grense).
    @Published var minStayDays: Int? = 1
    /// Maksimum antall dager bruker kan booke. nil = ingen maksimum.
    @Published var maxStayDays: Int? = nil
    /// Type parkering. nil = ikke oppgitt. Kun relevant for parkering-kategori.
    @Published var parkingType: ParkingType? = nil

    // MARK: - Edit mode (TU-61)
    /// True når formen brukes til å redigere en eksisterende annonse.
    /// EditListingHub setter denne ved opprettelse, så CategoryStep skjules.
    @Published var editingMode: Bool = false
    /// listing.id når editingMode = true. Brukes som målsetting for UPDATE-query.
    @Published var existingListingId: String? = nil
    /// Snapshot-hash tatt etter loadFromListing(). Brukes av computed `isDirty`
    /// for å sjekke om brukeren har gjort endringer siden load.
    @Published var initialEditHash: Int = 0

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
        minStayDays = draft.minStayDays ?? 1
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
    // Booking-modus (5) og Lengde på opphold (6) er separate slides slik at
    // verten setter en og en innstilling. Mini-wizarden er steg 7-11.
    var stepLabels: [String] {
        ["Velkommen", "Kategori", "Adresse", "Plasser", "Marker", "Booking", "Lengde", "Kjøretøy", "Tilgjengelighet", "Pris", "Tillegg", "Kalender", "Rabatter", "Beskrivelse", "Bilder", "Fasiliteter", "Meldinger", "Klar"]
    }

    /// Åpningstid-steget (8) er listing-nivå og kun for parkering. Default
    /// døgnåpent (form.openingHours = nil). Vises på første plass-iterasjon i
    /// mini-wizarden — etterfølgende plasser hopper steget.
    var skipsAvailabilityStep: Bool {
        category != .parking
    }

    /// Rabatter-steget (12) er nå flettet inn under Pris-steget som en
    /// collapsible seksjon, så denne hopper alltid. Beholdt som flagg slik at
    /// existing step-routing-kode fortsetter å peke forbi step-en.
    var skipsRabatterStep: Bool {
        true
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
            // Booking-modus (instant/request) — alltid gyldig
            return nil
        case 6:
            // Mini-wizard Kjøretøy + ParkingType
            guard spotMarkers.indices.contains(currentSpotIndex) else { return "Ingen plass valgt" }
            let spot = spotMarkers[currentSpotIndex]
            if spot.effectiveVehicleTypes.isEmpty { return "Velg minst én biltype" }
            let needsLength = spot.effectiveVehicleTypes.contains(where: { !$0.isCompact })
            if needsLength, (spot.vehicleMaxLength ?? 0) < 1 { return "Sett maks lengde i meter" }
        case 7:
            // Mini-wizard Tilgjengelighet (åpningstid, listing-level) — alltid gyldig
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
            // Mini-wizard Tillegg — alltid gyldig
            return nil
        case 10:
            // Mini-wizard Kalender (per spot, valgfritt) — alltid gyldig
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
    /// Mini-wizard er 5 steg: Kjøretøy (6), Tilgjengelighet (7 — listing-level),
    /// Pris (8), Tillegg (9), Kalender (10 — per spot, valgfritt).
    var currentStepHasMiniWizard: Bool {
        currentStep >= 6 && currentStep <= 10
    }

    /// Visuell fremdrift 0..1. Mini-wizard utgjør 5 steg per plass.
    var displayProgress: Double {
        let spotCount = max(1, spotMarkers.count)
        // 6 pre-mini (0–5: Velkommen → Booking) + 5*N mini + 6 post-mini (11 Rabatter → 16 Klar)
        let totalVirtual = 12 + 5 * spotCount
        let pos: Int
        if currentStep < 7 {
            pos = currentStep
        } else if currentStep <= 11 {
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

        // Hvis brukeren har vært på oppsummeringen før og er nå på et tidligere
        // steg (etter å ha tappet en rad i oppsummeringen), short-circuit Neste
        // direkte tilbake til oppsummeringen i stedet for å walke gjennom alt.
        if hasReachedSummary && currentStep != totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep = totalSteps - 1
            }
            return
        }

        // Mini-wizard 6-10: Kjøretøy → Tilgjengelighet → Pris → Tillegg → Kalender
        if currentStepHasMiniWizard {
            if currentStep < 10 {
                var next = currentStep + 1
                // Åpningstid (7) er listing-nivå — vis kun for parkering, og
                // kun på første plass-iterasjon (currentSpotIndex == 0).
                if next == 7 && (skipsAvailabilityStep || currentSpotIndex > 0) { next = 8 }
                withAnimation(.easeInOut(duration: 0.32)) { currentStep = next }
                return
            }
            // Steg 10 (Kalender): plassen er ferdig
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
            }
            if currentStep == totalSteps - 1 {
                hasReachedSummary = true
            }
        }
    }

    func goBack() {
        error = nil

        if currentStepHasMiniWizard {
            if currentStep > 6 {
                var prev = currentStep - 1
                if prev == 7 && (skipsAvailabilityStep || currentSpotIndex > 0) { prev = 6 }
                withAnimation(.easeInOut(duration: 0.32)) { currentStep = prev }
                return
            }
            // Steg 6 (Kjøretøy): gå til Kalender (10) av forrige plass
            if currentSpotIndex > 0 {
                withAnimation(.easeInOut(duration: 0.32)) {
                    currentSpotIndex -= 1
                    currentStep = 10
                }
                return
            }
            // Første plass på steg 6 — tilbake til InstantBooking (5)
            withAnimation(.easeInOut(duration: 0.32)) { currentStep = 5 }
            return
        }

        if currentStep > 0 {
            withAnimation(.easeInOut(duration: 0.32)) {
                currentStep -= 1
                // Hopp over Rabatter (11) bakover for camping
                if currentStep == 11 && skipsRabatterStep {
                    currentStep = 10
                }
                // Bakover INN i mini-wizard fra Rabatter/Beskrivelse → siste plass, Kalender (10)
                if currentStepHasMiniWizard && !spotMarkers.isEmpty {
                    currentSpotIndex = spotMarkers.count - 1
                    currentStep = 10
                }
            }
        }
    }

    /// Hopp direkte til et bestemt steg. Brukes fra PublishStep for hurtignav.
    /// `spotIndex` settes når mål-steget er en mini-wizard-step (7-11).
    func goTo(step: Int, spotIndex: Int? = nil) {
        guard step >= 0, step < totalSteps else { return }
        error = nil
        withAnimation(.easeInOut(duration: 0.32)) {
            if let spotIndex, spotMarkers.indices.contains(spotIndex) {
                currentSpotIndex = spotIndex
            }
            currentStep = step
        }
        if step == totalSteps - 1 {
            hasReachedSummary = true
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
            // Elbil-lading og Under tak er overflødige: under tak er dekket
            // av Type plass (Garasje/P-hus), elbil-lading hører hjemme som
            // egen tjeneste senere.
            return [.securityCamera, .gated, .lighting, .handicapAccessible]
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

        // Når annonsen har kun én plass, speiles plassens beskrivelse opp til
        // listing-nivå. Vert skriver beskrivelsen ett sted (på plassen) og det
        // blir også annonse-beskrivelsen. Brukers eksplisitte annonse-beskrivelse
        // vinner om begge finnes.
        let resolvedDescription: String = {
            let trimmed = description.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
            if spots == 1, let spotDesc = spotMarkers.first?.description?.trimmingCharacters(in: .whitespaces), !spotDesc.isEmpty {
                return spotDesc
            }
            return trimmed
        }()

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

        // Avled rentalPeriodTypes + display_price fra spotMarkers' pricePackages.
        var seenPeriods: Set<PricePackagePeriodType> = []
        var minDay: Int?
        var minWeek: Int?
        var minMonth: Int?
        var minYear: Int?
        for s in spotMarkers {
            for p in s.pricePackages ?? [] {
                seenPeriods.insert(p.periodType)
                switch p.periodType {
                case .day: minDay = min(minDay ?? Int.max, p.priceNok)
                case .week: minWeek = min(minWeek ?? Int.max, p.priceNok)
                case .month: minMonth = min(minMonth ?? Int.max, p.priceNok)
                case .year: minYear = min(minYear ?? Int.max, p.priceNok)
                }
            }
            if let p = s.weeklyPrice, p > 0 {
                seenPeriods.insert(.week)
                minWeek = min(minWeek ?? Int.max, p)
            }
            if let p = s.monthlyPrice, p > 0 {
                seenPeriods.insert(.month)
                minMonth = min(minMonth ?? Int.max, p)
            }
            if let p = s.yearPrice, p > 0 {
                seenPeriods.insert(.year)
                minYear = min(minYear ?? Int.max, p)
            }
            let basePrice = category == .parking
                ? (s.price ?? 0)
                : (s.pricePerNight ?? s.price ?? 0)
            if basePrice > 0 {
                seenPeriods.insert(.day)
                minDay = min(minDay ?? Int.max, basePrice)
            }
        }
        let derivedPeriodTypes: [String] = seenPeriods.map { $0.rawValue }.sorted()
        let (displayPrice, displayPriceSuffix): (Int?, String) = {
            if let d = minDay { return (d, "") }
            if let w = minWeek { return (w, "/uke") }
            if let m = minMonth { return (m, "/mnd") }
            if let y = minYear { return (y, "/år") }
            return (derivedListingPrice > 0 ? derivedListingPrice : nil, "")
        }()
        // Avled minimum opphold fra korteste tilbudte pakke. Bruker satte
        // minStayDays går foran. Filter i søk: hvis brukers valgte periode
        // (i dager) < min_stay_days, ekskluderes annonsen.
        let derivedMinStayDays: Int? = {
            if let m = minStayDays { return m }
            if seenPeriods.contains(.day) { return 1 }
            if seenPeriods.contains(.week) { return 7 }
            if seenPeriods.contains(.month) { return 30 }
            if seenPeriods.contains(.year) { return 365 }
            return nil
        }()

        return CreateListingInput(
            id: UUID().uuidString.lowercased(),
            hostId: hostId,
            title: resolvedTitle,
            internalName: internalName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : internalName.trimmingCharacters(in: .whitespaces),
            description: resolvedDescription,
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
            minStayDays: derivedMinStayDays,
            maxStayDays: maxStayDays,
            parkingType: category == .parking ? parkingType?.rawValue : nil,
            rentalPeriodTypes: derivedPeriodTypes,
            displayPrice: displayPrice,
            displayPriceSuffix: displayPriceSuffix
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

// MARK: - Edit mode helpers (TU-61)

extension ListingFormModel {
    /// Mapper en eksisterende Listing tilbake til form-state. Speiler den
    /// gamle `EditListingView.populateFields()` slik at edit-flyten kan dele
    /// nøyaktig samme step-views som wizard-flyten.
    func loadFromListing(_ listing: Listing) {
        category = listing.category ?? .camping
        title = listing.title
        internalName = listing.internalName ?? ""
        description = listing.description ?? ""
        address = listing.address ?? ""
        city = listing.city ?? ""
        region = listing.region ?? ""
        lat = listing.lat ?? 0
        lng = listing.lng ?? 0
        hideExactLocation = listing.hideExactLocation ?? false
        spots = listing.spots ?? 1
        spotMarkers = listing.spotMarkers ?? []
        imageURLs = listing.images ?? []
        selectedAmenities = Set(listing.amenities ?? [])
        checkInTime = listing.checkInTime ?? "15:00"
        checkOutTime = listing.checkOutTime ?? "11:00"
        checkinMessage = listing.checkinMessage ?? ""
        checkoutMessage = listing.checkoutMessage ?? ""
        checkoutMessageSendHoursBefore = listing.checkoutMessageSendHoursBefore ?? 2
        skippedMessages = false
        blockedDates = Set(listing.blockedDates ?? [])
        instantBooking = listing.instantBooking ?? false
        priceUnit = listing.priceUnit ?? PriceUnit.defaultUnit(for: listing.category ?? .camping)
        openingHours = listing.openingHours
        minStayDays = listing.minStayDays
        maxStayDays = listing.maxStayDays
        parkingType = listing.parkingType
        defaultVehicleTypes = listing.spotMarkers?.first?.effectiveVehicleTypes ?? [listing.category == .parking ? .car : .motorhome]

        // Backfill legacy pris-felt til pricePackages slik at rabatter-UI
        // viser tidligere innstillinger. Speiler logikken i den gamle
        // populateFields().
        for i in spotMarkers.indices {
            var pkgs = spotMarkers[i].pricePackages ?? []
            func upsert(_ pt: PricePackagePeriodType, _ pv: Int, _ price: Int?) {
                guard let p = price, p > 0 else { return }
                if pkgs.contains(where: { $0.periodType == pt && $0.periodValue == pv }) { return }
                pkgs.append(PricePackage(periodType: pt, periodValue: pv, priceNok: p))
            }
            upsert(.week, 1, spotMarkers[i].weeklyPrice)
            upsert(.month, 1, spotMarkers[i].monthlyPrice)
            upsert(.month, 3, spotMarkers[i].threeMonthPrice)
            upsert(.month, 6, spotMarkers[i].sixMonthPrice)
            upsert(.year, 1, spotMarkers[i].yearPrice)
            spotMarkers[i].pricePackages = pkgs.isEmpty ? nil : pkgs.sortedForDisplay
        }

        currentStep = 0
        currentSpotIndex = 0
        error = nil
        initialEditHash = currentEditHash()
    }

    /// Sjekker om brukeren har endret noe siden `loadFromListing(_:)`.
    /// Computed slik at SwiftUI re-evaluerer automatisk når @Published-felter
    /// publiserer endringer.
    var isDirty: Bool {
        guard editingMode else { return false }
        return currentEditHash() != initialEditHash
    }

    /// Hash av alle bruker-redigerbare felt. Brukes for å sammenligne med
    /// `initialEditHash` for å vite om "Lagre"-knappen skal være aktiv.
    func currentEditHash() -> Int {
        var h = Hasher()
        h.combine(title)
        h.combine(internalName)
        h.combine(description)
        h.combine(address)
        h.combine(city)
        h.combine(region)
        h.combine(lat)
        h.combine(lng)
        h.combine(hideExactLocation)
        h.combine(spots)
        h.combine(checkInTime)
        h.combine(checkOutTime)
        h.combine(checkinMessage)
        h.combine(checkoutMessage)
        h.combine(checkoutMessageSendHoursBefore)
        h.combine(skippedMessages)
        h.combine(instantBooking)
        h.combine(priceUnit.rawValue)
        h.combine(minStayDays ?? -1)
        h.combine(maxStayDays ?? -1)
        h.combine(parkingType?.rawValue ?? "")
        h.combine(Array(selectedAmenities).sorted())
        h.combine(imageURLs)
        h.combine(Array(blockedDates).sorted())
        // Kompleks-felter: hash via JSON for å unngå Hashable-conformance-krav.
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(spotMarkers) { h.combine(data) }
        if let oh = openingHours, let data = try? encoder.encode(oh) {
            h.combine(data)
        } else {
            h.combine(0) // nil-sentinel
        }
        return h.finalize()
    }

    /// Bygger UPDATE-payload for å oppdatere en eksisterende listing.
    /// Speiler `saveChanges()` fra den gamle EditListingView.
    func buildUpdateInput() -> UpdateListingInput {
        let isParking = category == .parking
        // Avled cached-felter på listing-nivå fra spotMarkers — samme logikk
        // som CreateListingView's `buildInput`. Søk og kart-bobler leser disse,
        // så de må holdes konsistent med spot-data.
        let derivedListingPrice = spotMarkers.compactMap { spot -> Int? in
            if let n = spot.pricePerNight, n > 0 { return n }
            return spot.price
        }.filter { $0 > 0 }.min() ?? 0

        let derivedMaxLength = spotMarkers.compactMap { $0.vehicleMaxLength }.filter { $0 > 0 }.max()

        var seenPeriods: Set<PricePackagePeriodType> = []
        var minDay: Int?
        var minWeek: Int?
        var minMonth: Int?
        var minYear: Int?
        for s in spotMarkers {
            for p in s.pricePackages ?? [] {
                seenPeriods.insert(p.periodType)
                switch p.periodType {
                case .day: minDay = min(minDay ?? Int.max, p.priceNok)
                case .week: minWeek = min(minWeek ?? Int.max, p.priceNok)
                case .month: minMonth = min(minMonth ?? Int.max, p.priceNok)
                case .year: minYear = min(minYear ?? Int.max, p.priceNok)
                }
            }
            if let p = s.weeklyPrice, p > 0 { seenPeriods.insert(.week); minWeek = min(minWeek ?? Int.max, p) }
            if let p = s.monthlyPrice, p > 0 { seenPeriods.insert(.month); minMonth = min(minMonth ?? Int.max, p) }
            if let p = s.yearPrice, p > 0 { seenPeriods.insert(.year); minYear = min(minYear ?? Int.max, p) }
            let basePrice = isParking ? (s.price ?? 0) : (s.pricePerNight ?? s.price ?? 0)
            if basePrice > 0 { seenPeriods.insert(.day); minDay = min(minDay ?? Int.max, basePrice) }
        }
        let (displayPrice, displaySuffix): (Int?, String) = {
            if let d = minDay { return (d, "") }
            if let w = minWeek { return (w, "/uke") }
            if let m = minMonth { return (m, "/mnd") }
            if let y = minYear { return (y, "/år") }
            return (derivedListingPrice > 0 ? derivedListingPrice : nil, "")
        }()
        let derivedPeriodTypes = seenPeriods.map { $0.rawValue }.sorted()
        let derivedMinStay: Int? = {
            if let m = minStayDays { return m }
            if seenPeriods.contains(.day) { return 1 }
            if seenPeriods.contains(.week) { return 7 }
            if seenPeriods.contains(.month) { return 30 }
            if seenPeriods.contains(.year) { return 365 }
            return nil
        }()

        // Listing-nivå pris bør falle tilbake til displayPrice for filtre som
        // leser kun `price`-kolonnen.
        let resolvedPrice = derivedListingPrice > 0 ? derivedListingPrice : (displayPrice ?? 0)

        // priceUnit i DB: parkering = .time (kr/dag), camping = .natt. Hour er fjernet.
        let resolvedPriceUnit: PriceUnit = isParking ? .time : .natt

        // Tittel og beskrivelse — speiler `buildInput`-fallback-logikken.
        let resolvedTitle: String = {
            let t = title.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
            let cat = category?.displayName ?? "Plass"
            let loc = !address.isEmpty ? address
                : !city.isEmpty ? city
                : !region.isEmpty ? region
                : "Norge"
            return "\(cat) i \(loc)"
        }()
        let resolvedDescription: String = {
            let d = description.trimmingCharacters(in: .whitespaces)
            if !d.isEmpty { return d }
            if spots == 1, let sd = spotMarkers.first?.description?.trimmingCharacters(in: .whitespaces), !sd.isEmpty {
                return sd
            }
            return d
        }()

        return UpdateListingInput(
            title: resolvedTitle,
            internalName: internalName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : internalName.trimmingCharacters(in: .whitespaces),
            description: resolvedDescription,
            checkoutMessage: skippedMessages || checkoutMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : checkoutMessage,
            checkoutMessageSendHoursBefore: checkoutMessageSendHoursBefore,
            spots: spots,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            checkinMessage: skippedMessages || checkinMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : checkinMessage,
            address: address,
            city: city,
            region: region,
            lat: lat,
            lng: lng,
            price: resolvedPrice,
            priceUnit: resolvedPriceUnit.rawValue,
            instantBooking: instantBooking,
            amenities: Array(selectedAmenities),
            images: imageURLs,
            blockedDates: Array(blockedDates).sorted(),
            hideExactLocation: hideExactLocation,
            spotMarkers: spotMarkers,
            extras: [],
            maxVehicleLength: derivedMaxLength,
            isActive: true,
            openingHours: isParking ? openingHours : nil,
            minStayDays: derivedMinStay,
            maxStayDays: maxStayDays,
            parkingType: isParking ? parkingType?.rawValue : nil,
            rentalPeriodTypes: derivedPeriodTypes,
            displayPrice: displayPrice,
            displayPriceSuffix: displaySuffix
        )
    }
}

// MARK: - UPDATE payload (delt mellom EditListingHub og legacy edit-flyt)

struct UpdateListingInput: Encodable {
    let title: String
    let internalName: String?
    let description: String
    let checkoutMessage: String?
    let checkoutMessageSendHoursBefore: Int
    let spots: Int
    let checkInTime: String
    let checkOutTime: String
    let checkinMessage: String?
    let address: String
    let city: String
    let region: String
    let lat: Double
    let lng: Double
    let price: Int
    let priceUnit: String
    let instantBooking: Bool
    let amenities: [String]
    let images: [String]
    let blockedDates: [String]
    let hideExactLocation: Bool
    let spotMarkers: [SpotMarker]
    let extras: [ListingExtra]
    let maxVehicleLength: Int?
    let isActive: Bool
    let openingHours: OpeningHours?
    let minStayDays: Int?
    let maxStayDays: Int?
    let parkingType: String?
    let rentalPeriodTypes: [String]
    let displayPrice: Int?
    let displayPriceSuffix: String

    enum CodingKeys: String, CodingKey {
        case title, description, spots, address, city, region, lat, lng, price, amenities, images, extras
        case internalName = "internal_name"
        case checkoutMessage = "checkout_message"
        case checkoutMessageSendHoursBefore = "checkout_message_send_hours_before"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case checkinMessage = "checkin_message"
        case priceUnit = "price_unit"
        case instantBooking = "instant_booking"
        case blockedDates = "blocked_dates"
        case hideExactLocation = "hide_exact_location"
        case spotMarkers = "spot_markers"
        case maxVehicleLength = "max_vehicle_length"
        case isActive = "is_active"
        case openingHours = "opening_hours"
        case minStayDays = "min_stay_days"
        case maxStayDays = "max_stay_days"
        case parkingType = "parking_type"
        case rentalPeriodTypes = "rental_period_types"
        case displayPrice = "display_price"
        case displayPriceSuffix = "display_price_suffix"
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
    let parkingType: String?
    let rentalPeriodTypes: [String]
    let displayPrice: Int?
    let displayPriceSuffix: String

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
        case parkingType = "parking_type"
        case rentalPeriodTypes = "rental_period_types"
        case displayPrice = "display_price"
        case displayPriceSuffix = "display_price_suffix"
    }
}
