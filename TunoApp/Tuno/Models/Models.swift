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
    /// Legacy per-time-pris (parkering). Kun til stede på gamle annonser før modellen
    /// ble forenklet til per-dag. nil for nye annonser.
    let pricePerHour: Int?
    /// Per-natt-pris for camping. NULL for parkering.
    let pricePerNight: Int?
    /// @deprecated availability_mode er fjernet fra DB — felt beholdes kun for å
    /// hindre Codable-feil på eldre app-builds. Alltid nil.
    let availabilityMode: String?
    /// Åpningstid på listing-nivå (parkering). NULL = døgnåpent.
    let openingHours: OpeningHours?
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
    let checkoutMessage: String?
    let checkoutMessageSendHoursBefore: Int?
    let isActive: Bool?
    /// Minste antall dager en bruker kan booke. nil = ingen minimum.
    let minStayDays: Int?
    /// Største antall dager en bruker kan booke. nil = ingen maksimum.
    let maxStayDays: Int?
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
        case pricePerHour = "price_per_hour"
        case pricePerNight = "price_per_night"
        case availabilityMode = "availability_mode"
        case openingHours = "opening_hours"
        case maxVehicleLength = "max_vehicle_length"
        case instantBooking = "instant_booking"
        case spotMarkers = "spot_markers"
        case hideExactLocation = "hide_exact_location"
        case blockedDates = "blocked_dates"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case checkinMessage = "checkin_message"
        case checkoutMessage = "checkout_message"
        case checkoutMessageSendHoursBefore = "checkout_message_send_hours_before"
        case isActive = "is_active"
        case minStayDays = "min_stay_days"
        case maxStayDays = "max_stay_days"
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
    var lat: Double
    var lng: Double
    var label: String?
    var description: String?
    var price: Int?
    /// @deprecated Legacy per-time-pris. Kun nil på nye annonser.
    var pricePerHour: Int?
    /// Per-natt-pris for camping (overstyrer listing-nivå). nil for parkering.
    var pricePerNight: Int?
    var vehicleMaxLength: Int?
    /// Multi-select biltyper plassen passer for.
    var vehicleTypes: [VehicleType]?
    /// Eldre singel-felt — beholdes kun for backward-compat ved decode av seedede listings.
    var vehicleType: VehicleType?
    /// @deprecated Per-plass priceUnit. Nye annonser arver kategorinivå.
    var priceUnit: PriceUnit?
    var extras: [ListingExtra]?
    var blockedDates: [String]?
    var checkinMessage: String?
    /// Bilder tagget til denne spesifikke plassen. URL-ene er delmengde av
    /// listing.images — ingen separat opplasting. Utleier tagger i wizard/edit.
    var images: [String]?
    /// "Lengre opphold"-pris (kr) for ett fullt døgn. @deprecated — fjernet fra
    /// UI fordi det er identisk med standard-dagspris. Beholdt felt for
    /// bakoverkompat ved decode av eldre annonser. Sett alltid nil for nye.
    var dailyPrice: Int? = nil
    /// "Lengre opphold"-pris (kr) for 7 påfølgende fulle døgn.
    var weeklyPrice: Int? = nil
    /// "Lengre opphold"-pris (kr) for 30 påfølgende fulle døgn.
    var monthlyPrice: Int? = nil
    /// "Lengre opphold"-pris (kr) for 90 påfølgende fulle døgn (3 måneder).
    var threeMonthPrice: Int? = nil
    /// "Lengre opphold"-pris (kr) for 180 påfølgende fulle døgn (6 måneder).
    var sixMonthPrice: Int? = nil
    /// "Lengre opphold"-pris (kr) for 365 påfølgende fulle døgn (1 år).
    var yearPrice: Int? = nil
    /// @deprecated %-rabatt. Beholdes kun for å hindre Codable-feil på eldre annonser. Alltid nil.
    var discountDayPct: Int? = nil
    /// @deprecated bruk weeklyPrice.
    var discountWeekPct: Int? = nil
    /// @deprecated bruk monthlyPrice.
    var discountMonthPct: Int? = nil
    /// Per-plass åpningstid (parkering). Overstyrer listing.openingHours hvis satt.
    /// nil = arve listing-nivå.
    var openingHours: OpeningHours?

    enum CodingKeys: String, CodingKey {
        case id, lat, lng, label, description, price, extras, images
        case pricePerHour = "pricePerHour"
        case pricePerNight = "pricePerNight"
        case vehicleMaxLength = "vehicleMaxLength"
        case vehicleType = "vehicleType"
        case vehicleTypes = "vehicleTypes"
        case priceUnit = "priceUnit"
        case blockedDates = "blockedDates"
        case checkinMessage = "checkinMessage"
        case dailyPrice = "dailyPrice"
        case weeklyPrice = "weeklyPrice"
        case monthlyPrice = "monthlyPrice"
        case threeMonthPrice = "threeMonthPrice"
        case sixMonthPrice = "sixMonthPrice"
        case yearPrice = "yearPrice"
        case discountDayPct = "discountDayPct"
        case discountWeekPct = "discountWeekPct"
        case discountMonthPct = "discountMonthPct"
        case openingHours = "openingHours"
    }

    /// Returner effektive kr-priser for "lengre opphold".
    func effectiveLongerStayPrices(baseHourly: Int) -> (daily: Int, weekly: Int, monthly: Int) {
        return (daily: dailyPrice ?? 0, weekly: weeklyPrice ?? 0, monthly: monthlyPrice ?? 0)
    }

    /// Backward-compat: returner vehicleTypes hvis satt, ellers wrap singel vehicleType.
    var effectiveVehicleTypes: [VehicleType] {
        if let arr = vehicleTypes, !arr.isEmpty { return arr }
        if let v = vehicleType { return [v] }
        return []
    }
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

/// Per-time pris-entry for hourly bookings (parkering per time).
struct HourlyPriceEntry: Codable, Hashable {
    /// ISO 8601 timestamp for time-blokken (Europe/Oslo).
    let hourAt: String
    let price: Int
    let source: String  // "base" | "hourly" | "override"
}

/// ISO-ukes-nøkkel (year + ukenummer). Brukes til å scope prisbånd til
/// spesifikke uker i wizardens pris-steg.
struct WeekKey: Hashable, Identifiable {
    let year: Int
    let weekNum: Int
    var id: String { String(format: "%04d-%02d", year, weekNum) }
}

/// Når et prisbånd skal være aktivt. Default = alle uker; brukeren kan
/// også velge en eller flere bestemte uker via multi-select sheet.
enum WeekScope: Hashable {
    case allWeeks
    case specificWeeks(Set<WeekKey>)
}

/// Time-bånd-regel som settes opp i wizard og inserts som listing_pricing_rules
/// etter publisering. Holdes lokalt i form-state.
struct WizardPricingBand: Identifiable, Hashable {
    let id: UUID
    var dayMask: Int
    var startHour: Int
    /// Minutt 0 eller 30. Default 0.
    var startMinute: Int
    var endHour: Int
    /// Minutt 0 eller 30. Default 0.
    var endMinute: Int
    var price: Int
    var weekScope: WeekScope
    /// Utleier-valgt farge-indeks (0-4 i palett). nil = derives fra id-hash.
    var colorIndex: Int? = nil
    /// Sesongbånd (camping): startdato i ISO-format "yyyy-MM-dd". Null for
    /// hourly/parking-bånd. Når satt sammen med endDate definerer båndet en
    /// dato-range i stedet for en time-range.
    var startDate: String? = nil
    /// Sesongbånd (camping): sluttdato (inklusiv) i ISO-format. Se startDate.
    var endDate: String? = nil

    init(
        id: UUID = UUID(),
        dayMask: Int,
        startHour: Int = 0,
        startMinute: Int = 0,
        endHour: Int = 24,
        endMinute: Int = 0,
        price: Int,
        weekScope: WeekScope = .allWeeks,
        colorIndex: Int? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) {
        self.id = id
        self.dayMask = dayMask
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.price = price
        self.weekScope = weekScope
        self.colorIndex = colorIndex
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Total minutter siden midnatt for start.
    var startMinutes: Int { startHour * 60 + startMinute }
    /// Total minutter siden midnatt for slutt.
    var endMinutes: Int { endHour * 60 + endMinute }

    /// True hvis båndet er et sesongbånd (camping). Bestemmes av om startDate
    /// er satt — sesongbånd har dato-range, ikke time-range.
    var isSeasonal: Bool { startDate != nil }

    /// "09:30 – 17:00" (hourly) eller "1. juni – 31. aug" (seasonal).
    var timeDisplayLabel: String {
        if isSeasonal, let start = startDate, let end = endDate {
            return "\(formatSeasonal(start)) – \(formatSeasonal(end))"
        }
        let s = String(format: "%02d:%02d", startHour, startMinute)
        let e = String(format: "%02d:%02d", endHour, endMinute)
        return "\(s) – \(e)"
    }

    private func formatSeasonal(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d. MMM"
        out.locale = Locale(identifier: "nb_NO")
        return out.string(from: date)
    }
}

/// Pris-overstyring for et tilgjengelighets-bånd. Brukeren setter en annen
/// pris for båndet i en spesifikk uke / sett av uker / hele perioden.
/// Persisteres som ekstra `listing_pricing_rules`-rader (kind='hourly') ved
/// publisering, med start_date/end_date avledet fra weekScope.
struct WizardBandPriceOverride: Identifiable, Hashable {
    let id: UUID
    /// Refererer til WizardPricingBand.id som denne overstyringen gjelder for.
    var bandId: UUID
    var weekScope: WeekScope
    var price: Int

    init(id: UUID = UUID(), bandId: UUID, weekScope: WeekScope, price: Int) {
        self.id = id
        self.bandId = bandId
        self.weekScope = weekScope
        self.price = price
    }
}

/// Pris-overstyring for en spesifikk dato. Persisteres som rad i
/// `listing_pricing_overrides`-tabellen ved publisering.
struct WizardDateOverride: Identifiable, Hashable {
    let id: UUID
    var date: String   // "yyyy-MM-dd"
    var price: Int

    init(id: UUID = UUID(), date: String, price: Int) {
        self.id = id
        self.date = date
        self.price = price
    }
}

/// Per-plass-tilgjengelighet og pris-variasjon i wizard-state. Kilde til
/// sannhet for SpotAvailabilityStep + PriceRulesStep editing-fase. Lagres
/// IKKE i SpotMarker (som er jsonb) — settes i ListingFormModel og brukes
/// kun ved publisering for å lage listing_pricing_rules + overrides.
struct WizardSpotAvailability: Hashable {
    var alwaysAvailable: Bool = true
    var bands: [WizardPricingBand] = []
    var bandPriceOverrides: [WizardBandPriceOverride] = []
    var dateOverrides: [WizardDateOverride] = []
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

    /// Kortere label brukt i tabs/cards (forsidens picker, "Hvor"-modal).
    var tabLabel: String {
        switch self {
        case .parking: return "Parkering"
        case .camping: return "Camping"
        }
    }

    /// Asset-navn for Lucide-ikoner. Camping = telt, Parkering = bil.
    var lucideIcon: String {
        switch self {
        case .camping: return "lucide-tent"
        case .parking: return "lucide-car"
        }
    }

    /// Branded 3D-PNG-ikoner brukt i kategori-velgere (forsiden, WhereSheet,
    /// wizard-CategoryStep). Original-rendret (ikke template) så fargene
    /// beholdes uavhengig av foregroundStyle.
    var categoryIcon: String {
        switch self {
        case .camping: return "category-camping"
        case .parking: return "category-parking"
        }
    }
}

enum VehicleType: String, Codable, CaseIterable {
    case motorhome
    case campervan
    case car
    case van
    case motorcycle

    var displayName: String {
        switch self {
        case .car: return "Personbil"
        case .campervan: return "Campingbil"
        case .motorhome: return "Bobil"
        case .van: return "Varebil"
        case .motorcycle: return "Motorsykkel"
        }
    }

    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .campervan: return "box.truck.fill"
        case .motorhome: return "box.truck.fill"
        case .van: return "shippingbox.fill"
        case .motorcycle: return "bicycle"
        }
    }

    /// Asset-navn for Lucide-ikoner (samme som web-appen). Bruk `Image(lucideIcon)`
    /// i SwiftUI — Xcode-assets er satt opp som template-rendering SVG-er.
    /// Bobil og campingbil må ha forskjellige ikoner: bobil = bus (større, integrert),
    /// campingbil = caravan (mindre, mer kompakt form).
    var lucideIcon: String {
        switch self {
        case .car: return "lucide-car"
        case .campervan: return "lucide-caravan"
        case .motorhome: return "lucide-bus"
        case .van: return "lucide-truck"
        case .motorcycle: return "lucide-bike"
        }
    }

    /// Hvilke biltyper som er relevante per kategori.
    /// Camping: kun campingkjøretøy (bobil, campingbil, personbil med telt).
    /// Parkering: alle 5 — pendlere har vanligvis personbil/varebil/MC, men store kjøretøy også.
    static func available(for category: ListingCategory) -> [VehicleType] {
        switch category {
        case .camping: return [.motorhome, .campervan, .car]
        case .parking: return [.car, .van, .motorcycle, .campervan, .motorhome]
        }
    }

    /// Disse trenger ikke maks-lengde-info — er små/standard.
    var isCompact: Bool {
        switch self {
        case .car, .motorcycle, .van: return true
        case .campervan, .motorhome: return false
        }
    }

    /// Hvilke listing-vehicle_types som kan ta imot dette kjøretøyet.
    /// Et bobil-listing tar imot alle (men ikke automatisk omvendt).
    /// Brukes av søkefilter mot listing-nivå `vehicle_type`-kolonnen.
    var acceptingListingTypes: [VehicleType] {
        switch self {
        case .motorcycle: return [.motorcycle, .car, .van, .campervan, .motorhome]
        case .car:        return [.car, .van, .campervan, .motorhome]
        case .van:        return [.van, .campervan, .motorhome]
        case .campervan:  return [.campervan, .motorhome]
        case .motorhome:  return [.motorhome]
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
        case .wasteDisposal: return "Avfall"
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
    case time   // Parkering per dag (24 timer) — historisk key "time".
    case natt   // Camping per natt
    /// @deprecated per-time-prising er fjernet. Beholdes som case kun for å
    /// hindre Codable-feil hvis en gammel app-build sender 'hour'.
    case hour

    var displayName: String {
        switch self {
        case .time: return "dag"
        case .natt: return "døgn"
        case .hour: return "time"
        }
    }

    /// Pluralisert label for telleordet — "1 dag" / "2 dager", "1 døgn" / "2 døgn".
    func pluralized(count: Int) -> String {
        switch self {
        case .time: return count == 1 ? "dag" : "dager"
        case .natt: return "døgn"
        case .hour: return count == 1 ? "time" : "timer"
        }
    }

    static func defaultUnit(for category: ListingCategory) -> PriceUnit {
        switch category {
        case .camping: return .natt
        case .parking: return .time
        }
    }
}

// MARK: - OpeningHours
//
// Åpningstid per ukedag (parkering). nil/manglende felt = stengt.
// Verdier på formatet "HH:MM-HH:MM" (lokal tid, Europe/Oslo).
// Hele struct nil på listing = døgnåpent.

struct OpeningHours: Codable, Hashable {
    var mon: String?
    var tue: String?
    var wed: String?
    var thu: String?
    var fri: String?
    var sat: String?
    var sun: String?

    func value(for day: Weekday) -> String? {
        switch day {
        case .mon: return mon
        case .tue: return tue
        case .wed: return wed
        case .thu: return thu
        case .fri: return fri
        case .sat: return sat
        case .sun: return sun
        }
    }

    mutating func set(_ value: String?, for day: Weekday) {
        switch day {
        case .mon: mon = value
        case .tue: tue = value
        case .wed: wed = value
        case .thu: thu = value
        case .fri: fri = value
        case .sat: sat = value
        case .sun: sun = value
        }
    }

    /// Default for "Med åpningstid"-toggle: man-fre 09-17, helg stengt.
    static let defaultLimited = OpeningHours(
        mon: "09:00-17:00",
        tue: "09:00-17:00",
        wed: "09:00-17:00",
        thu: "09:00-17:00",
        fri: "09:00-17:00",
        sat: nil,
        sun: nil
    )
}

enum Weekday: String, CaseIterable, Codable {
    case mon, tue, wed, thu, fri, sat, sun

    /// Fra Calendar.component(.weekday, from:) (1=Sun..7=Sat) til Weekday.
    static func from(weekdayComponent w: Int) -> Weekday {
        switch w {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        case 7: return .sat
        default: return .mon
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
    let location: String?
    let stripeAccountId: String?
    let stripeOnboardingComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case responseRate = "response_rate"
        case responseTime = "response_time"
        case joinedYear = "joined_year"
        case location
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
    /// ISO 8601 timestamp for hourly bookings (parkering per time). nil for daglige bookinger.
    let checkInAt: String?
    let checkOutAt: String?
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
        case checkInAt = "check_in_at"
        case checkOutAt = "check_out_at"
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
    let address: String?
    let lat: Double?
    let lng: Double?
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
    let archivedByGuest: Bool?
    let archivedByHost: Bool?
    let starredByGuest: Bool?
    let starredByHost: Bool?
    let mutedByGuest: Bool?
    let mutedByHost: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case guestId = "guest_id"
        case hostId = "host_id"
        case bookingId = "booking_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case archivedByGuest = "archived_by_guest"
        case archivedByHost = "archived_by_host"
        case starredByGuest = "starred_by_guest"
        case starredByHost = "starred_by_host"
        case mutedByGuest = "muted_by_guest"
        case mutedByHost = "muted_by_host"
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
