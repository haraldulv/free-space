import SwiftUI

/// Mini-wizard-steg 8 (per plass): "Vil du variere prisen?".
/// Ask-fase: Nei / Ja. Editing-fase: WizardPricingCalendarView med bånd-bars
/// per uke, brukeren tapper bånd → BandPriceOverrideSheet.
struct SpotPriceVariationStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var phasePerSpot: [String: Phase] = [:]

    enum Phase { case ask, editing }

    private var spot: SpotMarker? {
        form.spotMarkers.indices.contains(form.currentSpotIndex)
            ? form.spotMarkers[form.currentSpotIndex]
            : nil
    }

    private var spotId: String? { spot?.id }

    private var phase: Phase {
        guard let id = spotId else { return .ask }
        return phasePerSpot[id] ?? defaultPhase(for: id)
    }

    private func defaultPhase(for spotId: String) -> Phase {
        // Hvis brukeren allerede har overstyringer (gikk tilbake), gjenoppta editing.
        form.availability(for: spotId).bandPriceOverrides.isEmpty ? .ask : .editing
    }

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                slide(for: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.28), value: form.currentSpotIndex)
    }

    @ViewBuilder
    private func slide(for index: Int) -> some View {
        if let spot = form.spotMarkers[safe: index], let id = spot.id {
            let isAsk = (phasePerSpot[id] ?? defaultPhase(for: id)) == .ask
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: index, isAsk: isAsk)
                    if isAsk {
                        askContent(spotId: id)
                            .padding(.horizontal, 24)
                    } else {
                        backToFastPriceButton(spotId: id)
                            .padding(.horizontal, 24)
                        WizardPricingCalendarView(form: form, spotId: id)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func header(for index: Int, isAsk: Bool) -> some View {
        let total = form.spotMarkers.count
        VStack(alignment: .leading, spacing: 6) {
            if isAsk {
                Text(total == 1 ? "Vil du variere prisen?" : "Vil du variere prisen for plass \(index + 1)?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Mange tar høyere pris i rushtiden eller helger. Du kan også beholde én fast pris hele uken.")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                    .lineSpacing(2)
            } else {
                Text(total == 1 ? "Pris-variasjon" : "Pris-variasjon for plass \(index + 1)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func askContent(spotId: String) -> some View {
        VStack(spacing: 12) {
            askChoiceCard(
                icon: "checkmark.circle.fill",
                title: "Nei, fast pris",
                subtitle: "Bruk samme pris hele uken og hopp videre.",
                accent: .neutral900
            ) {
                var avail = form.availability(for: spotId)
                avail.bandPriceOverrides.removeAll()
                form.setAvailability(avail, for: spotId)
                form.goNext()
            }

            askChoiceCard(
                icon: "chart.bar.fill",
                title: "Ja, varier prisen",
                subtitle: "Sett ulike priser for tidsbånd og spesifikke uker.",
                accent: .primary600
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phasePerSpot[spotId] = .editing
                }
            }
        }
    }

    @ViewBuilder
    private func backToFastPriceButton(spotId: String) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    var avail = form.availability(for: spotId)
                    avail.bandPriceOverrides.removeAll()
                    form.setAvailability(avail, for: spotId)
                    phasePerSpot[spotId] = .ask
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tilbake til fast pris")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.neutral600)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func askChoiceCard(icon: String, title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
