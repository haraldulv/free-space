import SwiftUI

/// Mini-wizard-steg 8 (per plass): "Vil du variere prisen?".
/// Ask-fase: Nei / Ja. Editing-fase: WizardPricingCalendarView.
///
/// Viser KUN gjeldende plass via form.currentSpotIndex (ingen TabView page).
/// Mini-wizard-navigasjon mellom plasser styres av WizardNavBar.
/// — Tidligere TabView-wrapping forårsaket nested ScrollView-konflikt med
/// kalenderens egen ScrollView, som gjorde at både ask + editing rendret
/// overlappende.
struct SpotPriceVariationStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var phasePerSpot: [String: Phase] = [:]

    enum Phase { case ask, editing }

    private var currentSpot: SpotMarker? {
        form.spotMarkers[safe: form.currentSpotIndex]
    }

    var body: some View {
        Group {
            if let spot = currentSpot, let id = spot.id {
                let isAsk = (phasePerSpot[id] ?? defaultPhase(for: id)) == .ask
                if isAsk {
                    askPhase(spotId: id, index: form.currentSpotIndex)
                } else {
                    editingPhase(spotId: id, index: form.currentSpotIndex)
                }
            } else {
                EmptyView()
            }
        }
        .id("\(currentSpot?.id ?? "")-\(phasePerSpot[currentSpot?.id ?? ""] ?? .ask)")
        .animation(.easeInOut(duration: 0.22), value: phasePerSpot)
    }

    private func defaultPhase(for spotId: String) -> Phase {
        form.availability(for: spotId).bandPriceOverrides.isEmpty ? .ask : .editing
    }

    // MARK: - Ask

    @ViewBuilder
    private func askPhase(spotId: String, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                askHeader(index: index)
                    .padding(.top, 8)

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
                    phasePerSpot[spotId] = .editing
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func askHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        VStack(alignment: .leading, spacing: 8) {
            Text(total == 1 ? "Vil du variere prisen?" : "Vil du variere prisen for plass \(index + 1)?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
                .fixedSize(horizontal: false, vertical: true)
            Text("Mange tar høyere pris i rushtiden eller helger. Du kan også beholde én fast pris hele uken.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Editing

    @ViewBuilder
    private func editingPhase(spotId: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                editingHeader(index: index)
                Button {
                    var avail = form.availability(for: spotId)
                    avail.bandPriceOverrides.removeAll()
                    form.setAvailability(avail, for: spotId)
                    phasePerSpot[spotId] = .ask
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // WizardPricingCalendarView har sin egen ScrollView — INGEN outer
            // ScrollView, ellers kolliderer SwiftUI-layout og rendrer ask +
            // editing overlappende.
            WizardPricingCalendarView(form: form, spotId: spotId)
        }
    }

    @ViewBuilder
    private func editingHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        Text(total == 1 ? "Pris-variasjon" : "Pris-variasjon for plass \(index + 1)")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.neutral900)
    }
}

extension SpotPriceVariationStep.Phase: Equatable {}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
