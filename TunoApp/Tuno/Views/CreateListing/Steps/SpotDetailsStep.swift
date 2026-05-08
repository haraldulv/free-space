import SwiftUI

/// Mini-wizard for kjøretøy-detaljer per plass — én plass per slide.
/// Beskrivelse, kjøretøytyper, maks lengde. Pris er flyttet til neste hovedsteg.
struct SpotDetailsStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        spotHeader(index: index)
                        if index > 0 {
                            CopyFromPreviousSpotButton(label: "Bruk samme detaljer som plass \(index)") {
                                copyFromPrevious(currentIndex: index)
                            }
                        }
                        SpotVehicleContent(form: form, index: index)
                        if form.category == .parking {
                            ParkingTypeRow(selected: $form.parkingType)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.28), value: form.currentSpotIndex)
        .onAppear {
            form.ensureSpotCountMatchesSpots()
        }
    }

    private func spotHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        return VStack(alignment: .leading, spacing: 0) {
            Text(total == 1 ? "Detaljer om plassen" : "Plass \(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
        }
    }

    private func copyFromPrevious(currentIndex: Int) {
        let prev = currentIndex - 1
        guard
            form.spotMarkers.indices.contains(prev),
            form.spotMarkers.indices.contains(currentIndex)
        else { return }
        let src = form.spotMarkers[prev]
        form.spotMarkers[currentIndex].description = src.description
        form.spotMarkers[currentIndex].vehicleType = src.vehicleType
        form.spotMarkers[currentIndex].vehicleMaxLength = src.vehicleMaxLength
    }
}

/// Horisontal rad med 3 ParkingType-ikoner. Valgfri (tap igjen avvelger).
/// Vises kun for parkering-kategori.
private struct ParkingTypeRow: View {
    @Binding var selected: ParkingType?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type plass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)

            HStack(spacing: 8) {
                chip(.garage, icon: "house.fill", label: "Garasje")
                chip(.outdoor, icon: "tree.fill", label: "Utendørs")
                chip(.parkingHouse, icon: "building.2.fill", label: "P-hus")
            }
        }
    }

    @ViewBuilder
    private func chip(_ type: ParkingType, icon: String, label: String) -> some View {
        let isSelected = selected == type
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selected = isSelected ? nil : type
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isSelected ? Color.primary700 : Color.neutral600)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primary700 : Color.neutral700)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
