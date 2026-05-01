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
                let isFirstSpot = form.currentSpotIndex == 0
                let isShared = form.pricingBandsSharedAcrossSpots && form.spotMarkers.count > 1
                // Spot 1+: hvis felles-modus, vis "felles bånd"-info-side i stedet
                // for ask/editing-fasen — bandene er allerede satt fra spot 0.
                if isShared && !isFirstSpot {
                    sharedSpotInfo(spotId: id, index: form.currentSpotIndex)
                } else {
                    let isAsk = (phasePerSpot[id] ?? defaultPhase(for: id)) == .ask
                    if isAsk {
                        askPhase(spotId: id, index: form.currentSpotIndex)
                    } else {
                        editingPhase(spotId: id, index: form.currentSpotIndex)
                    }
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

                if form.spotMarkers.count > 1 && index == 0 {
                    sharedToggle
                }

                askChoiceCard(
                    icon: "checkmark.circle.fill",
                    title: "Nei, fast pris",
                    subtitle: "Bruk samme pris hele uken og hopp videre.",
                    accent: .neutral900
                ) {
                    var avail = form.availability(for: spotId)
                    avail.bandPriceOverrides.removeAll()
                    form.setAvailability(avail, for: spotId)
                    if form.pricingBandsSharedAcrossSpots && form.spotMarkers.count > 1 && index == 0 {
                        form.syncFirstSpotAvailabilityToAll()
                    }
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

    /// Toggle øverst i ask-fasen for spot 0 (kun når flere plasser finnes).
    /// Når på: bånd som settes for spot 0 kopieres automatisk til alle andre.
    private var sharedToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Felles bånd for alle plasser")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(form.pricingBandsSharedAcrossSpots
                     ? "Ett sett med pris-bånd gjelder alle plasser."
                     : "Sett bånd individuelt per plass.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Toggle("", isOn: $form.pricingBandsSharedAcrossSpots)
                .labelsHidden()
                .tint(Color.primary600)
        }
        .padding(16)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neutral200, lineWidth: 1))
    }

    /// Vises på spot 1+ når felles-modus er på. Forteller verten at bandene er
    /// satt fra plass 1, og lar dem hoppe videre eller endre fellesbåndene.
    @ViewBuilder
    private func sharedSpotInfo(spotId: String, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plass \(index + 1) bruker fellesbåndene")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Pris-bånd er felles for alle plasser. Endringer gjøres på plass 1.")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral500)
                }
                .padding(.top, 8)

                askChoiceCard(
                    icon: "arrow.right.circle.fill",
                    title: "Hopp videre",
                    subtitle: "Bruk fellesbåndene og gå til neste steg.",
                    accent: .primary600
                ) {
                    form.goNext()
                }

                askChoiceCard(
                    icon: "slider.horizontal.3",
                    title: "Endre individuelt for denne plassen",
                    subtitle: "Skru av felles-modus og rediger kun denne plassens bånd.",
                    accent: .neutral900
                ) {
                    form.pricingBandsSharedAcrossSpots = false
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
        // Full-skjerm: ingen header, ingen "Tilbake til fast pris"-pille.
        // Kalenderen tar all plass. Wizard-progress-bar skjules via
        // form.fullscreenStep. Brukeren går tilbake via WizardNavBar nederst.
        WizardPricingCalendarView(form: form, spotId: spotId)
            .onAppear { form.fullscreenStep = true }
            .onDisappear {
                form.fullscreenStep = false
                // Felles-modus: synk bandene fra spot 0 til alle andre når
                // editing-fasen forsvinner (brukeren gikk videre eller tilbake).
                if form.pricingBandsSharedAcrossSpots && form.spotMarkers.count > 1 && index == 0 {
                    form.syncFirstSpotAvailabilityToAll()
                }
            }
    }
}

extension SpotPriceVariationStep.Phase: Equatable {}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
