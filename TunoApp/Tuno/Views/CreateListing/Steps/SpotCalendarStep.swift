import SwiftUI

/// Mini-wizard-step for kalender per plass.
///
/// Setter `form.fullscreenStep = true` så progress-bar + WizardNavBar skjules.
/// Bruker den eksisterende `WizardPricingCalendarView` (parkering) /
/// `WizardSeasonalCalendarView` (camping) — de samme fine kontrollerne som er
/// bygget over flere økter, nå hooked til den nye datamodellen
/// (spot.blockedDates + spot.datePriceOverrides, ingen bånd).
///
/// Spot-picker pills øverst lar host velge "Alle plasser" eller én spesifikk
/// plass. I "Alle plasser"-modus kopieres endringer fra den valgte plassen
/// til alle andre.
struct SpotCalendarStep: View {
    @ObservedObject var form: ListingFormModel
    /// Hvilken plass kalenderen redigerer akkurat nå. nil = alle (vises som
    /// første plass under, men endringer propagerer til alle).
    @State private var focusedSpotId: String? = nil
    /// True hvis bruker har sagt "alle plasser" — synk endringer på tvers.
    @State private var allSpotsMode: Bool = true

    private var spotIds: [String] {
        form.spotMarkers.compactMap { $0.id }
    }

    private var canonicalSpotId: String? {
        focusedSpotId ?? spotIds.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            calendarContent

            VStack(spacing: 0) {
                if form.spotMarkers.count > 1 {
                    spotPickerBar
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }
                Spacer()
            }
        }
        .onAppear { form.fullscreenStep = true }
        .onDisappear {
            form.fullscreenStep = false
            // Etter editing: hvis "alle plasser"-modus, kopier kanonisk
            // plass' kalender-data til alle andre.
            if allSpotsMode, let canonical = canonicalSpotId,
               let idx = form.spotMarkers.firstIndex(where: { $0.id == canonical }) {
                let blocked = form.spotMarkers[idx].blockedDates
                let overrides = form.spotMarkers[idx].datePriceOverrides
                for i in form.spotMarkers.indices where form.spotMarkers[i].id != canonical {
                    form.spotMarkers[i].blockedDates = blocked
                    form.spotMarkers[i].datePriceOverrides = overrides
                }
            }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        if let id = canonicalSpotId {
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

    // MARK: - Spot picker pills (Alle plasser / 1 / 2 / ...)

    private var spotPickerBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hvilke plasser?")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pickerPill(
                        label: "Alle plasser",
                        icon: "rectangle.3.group.fill",
                        isSelected: allSpotsMode
                    ) {
                        allSpotsMode = true
                        focusedSpotId = spotIds.first
                    }

                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                        if let id = spot.id {
                            let label = spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false
                                ? spot.label!
                                : "\(idx + 1)"
                            pickerPill(
                                label: label,
                                icon: nil,
                                isSelected: !allSpotsMode && focusedSpotId == id
                            ) {
                                allSpotsMode = false
                                focusedSpotId = id
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pickerPill(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Color.neutral900)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary600 : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}
