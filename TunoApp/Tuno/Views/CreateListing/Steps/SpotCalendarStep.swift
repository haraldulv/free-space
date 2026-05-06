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
                    icon: "calendar.badge.checkmark",
                    title: "Sett opp kalender",
                    subtitle: "Blokker datoer eller sett egne priser for spesielle perioder.",
                    accent: Color.primary600
                ) {
                    if let id = currentSpotId {
                        phasePerSpot[id] = .editing
                    }
                }

                askChoiceCard(
                    icon: "arrow.right.circle.fill",
                    title: "Hopp over",
                    subtitle: "Annonsen blir åpen alle datoer til standardpris. Du kan justere når som helst fra Profil → Kalender etter publisering.",
                    accent: .neutral900
                ) {
                    form.goNext()
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
            ? "Vil du sette opp kalender?"
            : "Kalender for plass \(form.currentSpotIndex + 1)"
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Du kan blokkere enkeltdager eller sette egne priser for spesielle perioder. Eller bare hoppe over og gjøre dette senere — annonsen er da åpen alle datoer til standardpris.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
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

    // MARK: - Editing phase (fullscreen)

    @ViewBuilder
    private var editingPhase: some View {
        ZStack(alignment: .top) {
            calendarBody

            // Egen top-bar med X (= tilbake) + Ferdig (= advance).
            HStack(alignment: .center, spacing: 10) {
                Button {
                    if let id = currentSpotId { phasePerSpot[id] = .ask }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lukk")

                Spacer()

                Button {
                    form.goNext()
                } label: {
                    Text("Ferdig")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.primary600)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
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
