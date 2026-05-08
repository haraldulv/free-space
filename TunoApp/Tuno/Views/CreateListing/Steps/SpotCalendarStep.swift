import SwiftUI

/// Mini-wizard-step for kalender per plass. To faser:
///
/// **`.ask`** — vises i normal wizard-modus med Neste/Tilbake. To valg-kort:
///   - "Hopp over" → annonsen er åpen alle dager til standardpris.
///   - "Sett opp kalender" → går til `.editing`.
///
/// **`.editing`** — fullskjerm (form.fullscreenStep = true). Bruker den
/// eksisterende `WizardPricingCalendarView` / `WizardSeasonalCalendarView`.
/// Egen top-bar med X (= tilbake til ask) og Ferdig (= form.goNext()).
struct SpotCalendarStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var phasePerSpot: [String: Phase] = [:]

    enum Phase { case ask, editing }

    private var currentSpotId: String? {
        guard form.spotMarkers.indices.contains(form.currentSpotIndex) else { return nil }
        return form.spotMarkers[form.currentSpotIndex].id
    }

    private var phase: Phase {
        guard let id = currentSpotId else { return .ask }
        return phasePerSpot[id] ?? .ask
    }

    var body: some View {
        Group {
            switch phase {
            case .ask:
                askPhase
            case .editing:
                editingPhase
            }
        }
        .id("\(currentSpotId ?? "")-\(phase)")
        .animation(.easeInOut(duration: 0.22), value: phase)
    }

    // MARK: - Ask phase

    @ViewBuilder
    private var askPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                askHeader
                    .padding(.top, 8)

                askChoiceCard(
                    icon: "arrow.right",
                    title: "Hopp over",
                    subtitle: "Du kan sette opp dette senere",
                    accent: .neutral900
                ) {
                    form.goNext()
                }

                askChoiceCard(
                    icon: "calendar",
                    title: "Sett opp kalender",
                    subtitle: "Blokker datoer eller sett egne priser",
                    accent: Color.primary600
                ) {
                    if let id = currentSpotId {
                        phasePerSpot[id] = .editing
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var askHeader: some View {
        let total = form.spotMarkers.count
        let title = total == 1
            ? "Sett opp kalender?"
            : "Kalender for plass \(form.currentSpotIndex + 1)"
        return VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
        }
    }

    @ViewBuilder
    private func askChoiceCard(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Editing phase (skjul progress-bar, behold WizardNavBar)

    @ViewBuilder
    private var editingPhase: some View {
        // Progress-baren skjules (form.fullscreenStep = true), men
        // WizardNavBar i bunn beholdes — bruker navigerer med Tilbake/Neste
        // som ellers i wizarden. Ingen egen top-bar her.
        calendarBody
            .onAppear { form.fullscreenStep = true }
            .onDisappear { form.fullscreenStep = false }
    }

    @ViewBuilder
    private var calendarBody: some View {
        if let id = currentSpotId {
            if form.category == .camping {
                WizardSeasonalCalendarView(form: form, spotId: id)
            } else {
                WizardPricingCalendarView(form: form, spotId: id)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
