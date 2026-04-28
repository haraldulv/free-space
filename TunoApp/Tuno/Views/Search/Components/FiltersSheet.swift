import SwiftUI

/// Hvilke booking-typer brukeren vil se. Tre-tilstand så bruker kan
/// eksplisitt velge "kun direkte", "kun forespørsel" eller begge deler.
enum BookingPreference: String, Equatable, CaseIterable {
    case all          // Alle annonser
    case directOnly   // Kun direktebooking
    case requestOnly  // Kun forespørsel
}

/// Modeltype for søk + filter-valg. Delt mellom WhereSheet (søkepille)
/// og FiltersSheet (filter-knapp). Ansvarsfordeling:
/// - WhereSheet eier: category, vehicleTypes, bookingPreference (kjernen i søket)
/// - FiltersSheet eier: priceMin/priceMax, amenities (forfining)
struct SearchFilters: Equatable {
    var category: ListingCategory? = nil
    var vehicleTypes: Set<VehicleType> = []
    var priceMin: Int = 0
    var priceMax: Int = 5000
    var bookingPreference: BookingPreference = .all
    var amenities: Set<AmenityType> = []

    /// Antall aktive filtre satt FRA FiltersSheet (badge på filter-knappen).
    /// Kategori/kjøretøy/bookingtype telles ikke fordi de styres av WhereSheet.
    var activeCount: Int {
        var n = 0
        if priceMin > 0 || priceMax < 5000 { n += 1 }
        if !amenities.isEmpty { n += 1 }
        return n
    }
}

/// Filter-modal som forfiner søket. Inneholder bare ting som IKKE finnes
/// i søkepillen (WhereSheet): pris og fasiliteter.
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
        .onAppear { draft = filters }
    }

    // MARK: - Sections

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pris")
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
                    // Reset bare det FiltersSheet eier — kategori/kjøretøy/booking
                    // styres av WhereSheet og skal ikke nullstilles herfra.
                    draft.priceMin = 0
                    draft.priceMax = 5000
                    draft.amenities = []
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
