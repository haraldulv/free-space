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
                            ParkingDimensionsCard(form: form, index: index)
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
        form.spotMarkers[currentIndex].vehicleTypes = src.vehicleTypes
        form.spotMarkers[currentIndex].vehicleMaxLength = src.vehicleMaxLength
        form.spotMarkers[currentIndex].vehicleMaxWidth = src.vehicleMaxWidth
        form.spotMarkers[currentIndex].vehicleMaxHeight = src.vehicleMaxHeight
    }
}

/// Kompakt mål-card for parkering. Bredde og lengde vises for alle
/// parkeringstyper. Høyde vises kun for garasje + p-hus hvor takhøyde er
/// en reell begrensning.
private struct ParkingDimensionsCard: View {
    @ObservedObject var form: ListingFormModel
    let index: Int

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(index) ? form.spotMarkers[index] : nil
    }

    private var showHeight: Bool {
        form.parkingType == .garage || form.parkingType == .parkingHouse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Mål")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("(valgfritt)")
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
            }
            Text("Hjelper gjester å vite om kjøretøyet passer.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)

            DimensionRow(
                label: "Lengde",
                value: Binding(
                    get: { spot?.vehicleMaxLength ?? 0 },
                    set: { form.spotMarkers[index].vehicleMaxLength = $0 > 0 ? $0 : nil }
                ),
                maxValue: 30
            )

            DimensionRow(
                label: "Bredde",
                value: Binding(
                    get: { spot?.vehicleMaxWidth ?? 0 },
                    set: { form.spotMarkers[index].vehicleMaxWidth = $0 > 0 ? $0 : nil }
                ),
                maxValue: 10
            )

            if showHeight {
                DimensionRow(
                    label: "Høyde",
                    value: Binding(
                        get: { spot?.vehicleMaxHeight ?? 0 },
                        set: { form.spotMarkers[index].vehicleMaxHeight = $0 > 0 ? $0 : nil }
                    ),
                    maxValue: 10
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
    }
}

/// Kompakt label + meter-tall + unit-pill rad. Tap åpner numberPad.
private struct DimensionRow: View {
    let label: String
    @Binding var value: Int
    let maxValue: Int
    @FocusState private var focused: Bool
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.neutral900)
                .frame(width: 70, alignment: .leading)
            Spacer()
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary700)
                    .frame(width: 50)
                Text("m")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.neutral500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Color.primary600 : Color.neutral200, lineWidth: focused ? 1.5 : 1))
        }
        .onAppear { text = value > 0 ? "\(value)" : "" }
        .onChange(of: text) { _, newValue in
            let cleaned = newValue.filter(\.isNumber)
            if cleaned != newValue { text = cleaned; return }
            let parsed = min(maxValue, max(0, Int(cleaned) ?? 0))
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { _, newValue in
            if !focused { text = newValue > 0 ? "\(newValue)" : "" }
        }
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
