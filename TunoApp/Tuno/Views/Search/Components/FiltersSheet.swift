import SwiftUI

/// Modeltype for alle filter-valg som brukes i FiltersSheet og av søk.
struct SearchFilters: Equatable {
    var category: ListingCategory? = nil  // nil = "Hvilken som helst"
    var vehicleTypes: Set<VehicleType> = []
    var priceMin: Int = 0
    var priceMax: Int = 5000
    var instantBookingOnly: Bool = false
    var noHostCheckIn: Bool = false
    var freeCancellation: Bool = false
    var petsAllowed: Bool = false
    var amenities: Set<AmenityType> = []

    /// Hvor mange filtre er aktive — vises som badge på FilterCircleButton.
    var activeCount: Int {
        var n = 0
        if category != nil { n += 1 }
        if !vehicleTypes.isEmpty { n += 1 }
        if priceMin > 0 || priceMax < 5000 { n += 1 }
        if instantBookingOnly { n += 1 }
        if noHostCheckIn { n += 1 }
        if freeCancellation { n += 1 }
        if petsAllowed { n += 1 }
        if !amenities.isEmpty { n += 1 }
        return n
    }
}

/// Full Airbnb-paritet filter-modal med alle seksjoner: anbefalt, type
/// sted, kjøretøy, pris-histogram, bestillingsalternativer, fasiliteter.
struct FiltersSheet: View {
    @Binding var isPresented: Bool
    @Binding var filters: SearchFilters
    let prices: [Int]   // priser fra current listings — for histogram
    let resultCount: Int
    let onApply: () -> Void

    @State private var draft = SearchFilters()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    recommendedSection
                    typeSection
                    vehicleSection
                    priceSection
                    bookingOptionsSection
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
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral700)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Filter")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear { draft = filters }
    }

    // MARK: - Sections

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anbefalt for deg")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 10) {
                recommendedCard(
                    icon: "bolt.fill",
                    label: "Direktebooking",
                    isSelected: draft.instantBookingOnly
                ) {
                    draft.instantBookingOnly.toggle()
                }
                recommendedCard(
                    icon: "key.fill",
                    label: "Innsjekking uten vert",
                    isSelected: draft.noHostCheckIn
                ) {
                    draft.noHostCheckIn.toggle()
                }
                recommendedCard(
                    icon: "pawprint.fill",
                    label: "Tillater kjæledyr",
                    isSelected: draft.petsAllowed
                ) {
                    draft.petsAllowed.toggle()
                }
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type sted")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 8) {
                segmentButton(label: "Hvilken som helst", isSelected: draft.category == nil) {
                    draft.category = nil
                }
                segmentButton(label: "Camping", isSelected: draft.category == .camping) {
                    draft.category = .camping
                }
                segmentButton(label: "Parkering", isSelected: draft.category == .parking) {
                    draft.category = .parking
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

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pris per natt")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Turpris i NOK")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)

            PriceHistogram(
                prices: prices,
                bounds: 0...5000,
                lowerBound: $draft.priceMin,
                upperBound: $draft.priceMax
            )

            HStack(spacing: 12) {
                priceField(label: "Minst", value: draft.priceMin)
                priceField(label: "Maksimalt", value: draft.priceMax, suffix: "+")
            }
        }
    }

    private var bookingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bestillingsalternativer")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            FlowLayout(spacing: 8) {
                chip(label: "Direktebooking", icon: "bolt.fill", isSelected: draft.instantBookingOnly) {
                    draft.instantBookingOnly.toggle()
                }
                chip(label: "Innsjekking uten vert", icon: "key.fill", isSelected: draft.noHostCheckIn) {
                    draft.noHostCheckIn.toggle()
                }
                chip(label: "Gratis kansellering", icon: "calendar.badge.checkmark", isSelected: draft.freeCancellation) {
                    draft.freeCancellation.toggle()
                }
                chip(label: "Tillater kjæledyr", icon: "pawprint.fill", isSelected: draft.petsAllowed) {
                    draft.petsAllowed.toggle()
                }
            }
        }
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fasiliteter")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            FlowLayout(spacing: 8) {
                ForEach(AmenityType.allCases, id: \.self) { amenity in
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

    // MARK: - UI helpers

    private func recommendedCard(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .primary600 : .neutral700)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .primary700 : .neutral700)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func segmentButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .neutral900 : .neutral600)
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
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .underline()

                Spacer()

                Button {
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
