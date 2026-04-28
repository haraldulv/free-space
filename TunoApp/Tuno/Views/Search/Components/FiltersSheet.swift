import SwiftUI

/// Hvilke booking-typer brukeren vil se. Tre-tilstand så bruker kan
/// eksplisitt velge "kun direkte", "kun forespørsel" eller begge deler.
enum BookingPreference: String, Equatable, CaseIterable {
    case all          // Alle annonser
    case directOnly   // Kun direktebooking
    case requestOnly  // Kun forespørsel
}

/// Modeltype for søk + filter-valg. Delt mellom WhereSheet (søkepille)
/// og FiltersSheet (filter-knapp). Begge oppdaterer samme state, så
/// endringer ett sted speiles automatisk det andre.
///
/// `priceMax = 0` er sentinel for "ingen øvre grense" — søk filtrerer
/// kun hvis verdien er strengt større enn 0.
struct SearchFilters: Equatable {
    var category: ListingCategory? = nil
    var vehicleTypes: Set<VehicleType> = []
    var priceMin: Int = 0
    var priceMax: Int = 0
    var bookingPreference: BookingPreference = .all
    var amenities: Set<AmenityType> = []

    /// Antall aktive filtre — driver badge på FilterCircleButton.
    /// `dynamicMaxPrice` er øvre grense fra current listings; den brukes
    /// til å sammenligne om priceMax representerer en faktisk begrensning.
    func activeCount(dynamicMaxPrice: Int) -> Int {
        var n = 0
        if category != nil { n += 1 }
        if !vehicleTypes.isEmpty { n += 1 }
        if priceMin > 0 || (priceMax > 0 && priceMax < dynamicMaxPrice) { n += 1 }
        if bookingPreference != .all { n += 1 }
        if !amenities.isEmpty { n += 1 }
        return n
    }
}

/// Filter-modal. 1:1 med WhereSheet — kategori, kjøretøy og bookingtype
/// vises også her så endringer kan gjøres begge steder. Pris og fasiliteter
/// er forfining som ikke er i søkepillen.
struct FiltersSheet: View {
    @Binding var isPresented: Bool
    @Binding var filters: SearchFilters
    let prices: [Int]   // priser fra current listings — for histogram
    let resultCount: Int
    let onApply: () -> Void

    @State private var draft = SearchFilters()

    /// Maks pris å bruke som histogram-bound. Tar høyeste pris fra current
    /// listings, eller 1000 som fallback hvis ingen listings.
    private var dynamicMaxPrice: Int {
        let valid = prices.filter { $0 > 0 }
        guard let m = valid.max() else { return 1000 }
        // Rund opp til nærmeste hundre for et fint slider-bound.
        return ((m + 99) / 100) * 100
    }

    /// Fasiliteter relevant for valgt kategori. Parkering: sikkerhet/komfort.
    /// Camping: tilkoblinger/natur/komfort. Begge: handicap, kjæledyr.
    private var relevantAmenities: [AmenityType] {
        switch draft.category {
        case .parking:
            return [.evCharging, .covered, .securityCamera, .gated, .lighting, .handicapAccessible]
        case .camping:
            return [.electricity, .water, .toilets, .showers, .wifi, .wasteDisposal,
                    .campfire, .lakeAccess, .mountainView, .petsAllowed, .handicapAccessible]
        case .none:
            return AmenityType.allCases
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    typeSection
                    vehicleSection
                    bookingPrefSection
                    priceSection
                    amenitiesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Color.white)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .accessibilityLabel("Lukk")
                }
                ToolbarItem(placement: .principal) {
                    Text("Filter")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            draft = filters
            // Sentinel 0 → vis hele rangen som default (slider på maks)
            if draft.priceMax == 0 { draft.priceMax = dynamicMaxPrice }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type plass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 8) {
                segmentButton(label: "Alle", isSelected: draft.category == nil) {
                    draft.category = nil
                }
                segmentButton(label: "Camping", isSelected: draft.category == .camping) {
                    draft.category = .camping
                    if draft.vehicleTypes.contains(where: { $0 == .car }) || draft.vehicleTypes.isEmpty {
                        draft.vehicleTypes = [.motorhome, .campervan]
                    }
                }
                segmentButton(label: "Parkering", isSelected: draft.category == .parking) {
                    draft.category = .parking
                    draft.vehicleTypes = [.car]
                }
            }
        }
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kjøretøytype")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            FlowLayout(spacing: 8) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    chip(
                        label: type.displayName,
                        icon: type.icon,
                        isSelected: draft.vehicleTypes.contains(type)
                    ) {
                        if draft.vehicleTypes.contains(type) {
                            draft.vehicleTypes.remove(type)
                        } else {
                            draft.vehicleTypes.insert(type)
                        }
                    }
                }
            }
        }
    }

    private var bookingPrefSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bestillingstype")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 8) {
                segmentButton(label: "Alle", isSelected: draft.bookingPreference == .all) {
                    draft.bookingPreference = .all
                }
                segmentButton(label: "Direkte", isSelected: draft.bookingPreference == .directOnly) {
                    draft.bookingPreference = .directOnly
                }
                segmentButton(label: "Forespørsel", isSelected: draft.bookingPreference == .requestOnly) {
                    draft.bookingPreference = .requestOnly
                }
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pris")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Total pris i NOK")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)

            PriceHistogram(
                prices: prices,
                bounds: 0...dynamicMaxPrice,
                lowerBound: $draft.priceMin,
                upperBound: $draft.priceMax
            )

            HStack(spacing: 12) {
                priceField(label: "Minst", value: draft.priceMin)
                priceField(
                    label: "Maksimalt",
                    value: draft.priceMax,
                    suffix: draft.priceMax >= dynamicMaxPrice ? "+" : ""
                )
            }
        }
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fasiliteter")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            if relevantAmenities.isEmpty {
                Text("Ingen relevante fasiliteter for valgt kategori")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(relevantAmenities, id: \.self) { amenity in
                        chip(
                            label: amenity.label,
                            icon: amenity.icon,
                            isSelected: draft.amenities.contains(amenity)
                        ) {
                            if draft.amenities.contains(amenity) {
                                draft.amenities.remove(amenity)
                            } else {
                                draft.amenities.insert(amenity)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - UI helpers

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .neutral900 : .neutral500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white : Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.neutral900 : Color.neutral200, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func chip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Color.neutral900 : Color.white)
            .foregroundStyle(isSelected ? .white : .neutral700)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func priceField(label: String, value: Int, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            Text("\(value) kr\(suffix)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Fjern alle") {
                    draft = SearchFilters()
                    draft.priceMax = dynamicMaxPrice
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .underline()

                Spacer()

                Button {
                    // Konverter "fullt utdratt slider" tilbake til sentinel 0
                    // så activeCount ikke teller pris som aktivt filter.
                    if draft.priceMax >= dynamicMaxPrice { draft.priceMax = 0 }
                    filters = draft
                    onApply()
                    isPresented = false
                } label: {
                    Text("Vis \(resultCount) annonser")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.neutral900)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color.white)
    }
}
