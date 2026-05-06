import SwiftUI

/// Mini-wizard-step for kalender per plass. Valgfritt — bruker kan hoppe over
/// og justere senere fra Profil → Kalender.
///
/// Wraper `SpotCalendarEditor` per plass og gir tydelig "skip"-melding.
struct SpotCalendarStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 0) {
                    spotHeader(index: index)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    skipNotice
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    if index > 0 {
                        copyFromPreviousButton(currentIndex: index)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    SpotCalendarEditor(
                        blockedDates: blockedDatesBinding(for: index),
                        datePriceOverrides: overridesBinding(for: index),
                        basePrice: basePrice(for: index)
                    )
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.28), value: form.currentSpotIndex)
    }

    private func spotHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        return VStack(alignment: .leading, spacing: 6) {
            Text(total == 1
                 ? "Blokker datoer eller sett spesialpriser"
                 : "Kalender for plass \(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Du kan blokkere enkeltdager eller sette egne priser for spesielle perioder. Du kan hoppe over dette nå — annonsen blir åpen alle datoer til standardpris.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }

    private var skipNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.primary600)
            Text("Du kan justere kalenderen når som helst fra Profil → Kalender etter publisering.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func copyFromPreviousButton(currentIndex: Int) -> some View {
        CopyFromPreviousSpotButton(label: "Bruk samme kalender som plass \(currentIndex)") {
            copyCalendarFromPrevious(currentIndex: currentIndex)
        }
    }

    // MARK: - Bindings

    private func blockedDatesBinding(for index: Int) -> Binding<[String]> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(index) else { return [] }
                return form.spotMarkers[index].blockedDates ?? []
            },
            set: { newValue in
                guard form.spotMarkers.indices.contains(index) else { return }
                form.spotMarkers[index].blockedDates = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private func overridesBinding(for index: Int) -> Binding<[String: Int]> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(index) else { return [:] }
                return form.spotMarkers[index].datePriceOverrides ?? [:]
            },
            set: { newValue in
                guard form.spotMarkers.indices.contains(index) else { return }
                form.spotMarkers[index].datePriceOverrides = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private func basePrice(for index: Int) -> Int {
        guard form.spotMarkers.indices.contains(index) else { return 0 }
        let spot = form.spotMarkers[index]
        // Parkering: price (kr/dag). Camping: pricePerNight ?? price.
        return spot.pricePerNight ?? spot.price ?? 0
    }

    private func copyCalendarFromPrevious(currentIndex: Int) {
        let prevIndex = currentIndex - 1
        guard
            form.spotMarkers.indices.contains(prevIndex),
            form.spotMarkers.indices.contains(currentIndex)
        else { return }
        let prev = form.spotMarkers[prevIndex]
        form.spotMarkers[currentIndex].blockedDates = prev.blockedDates
        form.spotMarkers[currentIndex].datePriceOverrides = prev.datePriceOverrides
    }
}
