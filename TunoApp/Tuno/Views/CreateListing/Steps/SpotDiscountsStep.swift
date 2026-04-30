import SwiftUI

/// Steg 10 — Rabatter ved lengre opphold (parkering only).
///
/// Lar verten sette prosent-rabatt for: 1 døgn, 1 uke, 1 måned. Et "døgn" er
/// definert som booking som dekker hele dagens band-vindu. "Uke" = 7 påfølgende
/// fulle døgn, "måned" = 30. Booking-API stabler rabatten greedy: month tas
/// først, så week, så enkelt-døgn — slik at en 35-dagers-booking blir
/// 1 måned + 5 enkelt-døgn.
///
/// Default-modus: "Felles for alle plasser" på, så ett input-sett gjelder alle
/// spots. Skrur bruker av toggle, vises per-plass-input.
struct SpotDiscountsStep: View {
    @ObservedObject var form: ListingFormModel

    @State private var sharedAcrossSpots: Bool = true

    var body: some View {
        WizardScreen(
            title: "Rabatter ved lengre opphold",
            subtitle: "Belønn gjester som booker hele dagen, uken eller måneden. La feltene stå tomme om du ikke vil gi rabatt."
        ) {
            VStack(spacing: 16) {
                if form.spotMarkers.count > 1 {
                    sharedToggle
                }

                if sharedAcrossSpots || form.spotMarkers.count <= 1 {
                    discountCard(
                        title: "Alle plasser",
                        subtitle: "Bruk samme rabatt for alle plassene dine",
                        binding: sharedDiscountBinding
                    )
                } else {
                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                        discountCard(
                            title: spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? spot.label! : "Plass \(idx + 1)",
                            subtitle: "Per time: \(spot.pricePerHour ?? 0) kr",
                            binding: spotDiscountBinding(for: idx)
                        )
                    }
                }

                infoCard
            }
        }
        .onAppear {
            // Hvis alle plasser har samme rabatt-verdier, default til shared-modus.
            // Hvis de divergerer, default til per-plass.
            if form.spotMarkers.count > 1, !allSpotsHaveSameDiscounts {
                sharedAcrossSpots = false
            }
        }
    }

    private var sharedToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Felles for alle plasser")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(sharedAcrossSpots ? "Ett rabatt-sett gjelder alle." : "Sett rabatt per plass.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Toggle("", isOn: $sharedAcrossSpots)
                .labelsHidden()
                .tint(Color.primary600)
                .onChange(of: sharedAcrossSpots) { _, newValue in
                    if newValue {
                        // Når toggle slås på: kopier første plass sin rabatt til alle.
                        applyFirstSpotDiscountsToAll()
                    }
                }
        }
        .padding(16)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func discountCard(title: String, subtitle: String, binding: Binding<DiscountTrio>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }

            VStack(spacing: 10) {
                discountRow(label: "1 døgn", caption: "Hele dagens åpningstid", percent: binding.day)
                discountRow(label: "1 uke", caption: "7 påfølgende fulle døgn", percent: binding.week)
                discountRow(label: "1 måned", caption: "30 påfølgende fulle døgn", percent: binding.month)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func discountRow(label: String, caption: String, percent: Binding<Int?>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            PercentInput(value: percent)
        }
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.primary600)
            Text("Rabatten gjelder kun fulle døgn — booking innenfor enkelt-timer betales full timepris. En 35-dagers-booking blir 1 måned + 5 døgn-rabatter.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Bindings

    private var sharedDiscountBinding: Binding<DiscountTrio> {
        Binding(
            get: {
                let s = form.spotMarkers.first
                return DiscountTrio(
                    day: s?.discountDayPct ?? nil,
                    week: s?.discountWeekPct ?? nil,
                    month: s?.discountMonthPct ?? nil
                )
            },
            set: { newValue in
                for i in form.spotMarkers.indices {
                    form.spotMarkers[i].discountDayPct = newValue.day
                    form.spotMarkers[i].discountWeekPct = newValue.week
                    form.spotMarkers[i].discountMonthPct = newValue.month
                }
            }
        )
    }

    private func spotDiscountBinding(for index: Int) -> Binding<DiscountTrio> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(index) else { return DiscountTrio() }
                let s = form.spotMarkers[index]
                return DiscountTrio(day: s.discountDayPct, week: s.discountWeekPct, month: s.discountMonthPct)
            },
            set: { newValue in
                guard form.spotMarkers.indices.contains(index) else { return }
                form.spotMarkers[index].discountDayPct = newValue.day
                form.spotMarkers[index].discountWeekPct = newValue.week
                form.spotMarkers[index].discountMonthPct = newValue.month
            }
        )
    }

    // MARK: - Helpers

    private var allSpotsHaveSameDiscounts: Bool {
        guard let first = form.spotMarkers.first else { return true }
        return form.spotMarkers.allSatisfy { spot in
            spot.discountDayPct == first.discountDayPct
                && spot.discountWeekPct == first.discountWeekPct
                && spot.discountMonthPct == first.discountMonthPct
        }
    }

    private func applyFirstSpotDiscountsToAll() {
        guard let first = form.spotMarkers.first else { return }
        let trio = DiscountTrio(
            day: first.discountDayPct,
            week: first.discountWeekPct,
            month: first.discountMonthPct
        )
        for i in form.spotMarkers.indices {
            form.spotMarkers[i].discountDayPct = trio.day
            form.spotMarkers[i].discountWeekPct = trio.week
            form.spotMarkers[i].discountMonthPct = trio.month
        }
    }
}

/// Container for de tre rabatt-prosentene.
struct DiscountTrio: Equatable {
    var day: Int? = nil
    var week: Int? = nil
    var month: Int? = nil
}

/// Numerisk %-input med suffix og tøm-på-tap.
private struct PercentInput: View {
    @Binding var value: Int?
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("0", text: $text)
                .focused($isFocused)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
                .frame(width: 56)
            Text("%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral500)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.primary600 : Color.neutral200, lineWidth: isFocused ? 1.5 : 1)
        )
        .onAppear {
            text = value.map { "\($0)" } ?? ""
        }
        .onChange(of: value) { _, new in
            if !isFocused {
                text = new.map { "\($0)" } ?? ""
            }
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                // Tøm ved tap så bruker kan skrive nytt tall direkte.
                text = ""
            } else {
                commit()
            }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            value = nil
            text = ""
            return
        }
        let parsed = Int(trimmed) ?? 0
        let clamped = max(0, min(100, parsed))
        value = clamped > 0 ? clamped : nil
        text = clamped > 0 ? "\(clamped)" : ""
    }
}
