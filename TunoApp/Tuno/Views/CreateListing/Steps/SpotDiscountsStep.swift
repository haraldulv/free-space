import SwiftUI

/// "Lengre opphold"-steg (parkering only).
///
/// Lar verten sette en fast pris (kr) for: 1 døgn, 1 uke, 1 måned. Et "døgn" =
/// booking som dekker hele dagens band-vindu. "Uke" = 7 påfølgende fulle døgn,
/// "måned" = 30. Booking-API stabler greedy: month tas først, så week, så
/// enkelt-døgn — slik at en 35-dagers-booking blir 1 måned + 5 enkelt-døgn.
///
/// Default-modus: "Felles for alle plasser" på, så ett pris-sett gjelder alle
/// spots. Skrur bruker av toggle, vises per-plass-input.
struct SpotDiscountsStep: View {
    @ObservedObject var form: ListingFormModel

    @State private var sharedAcrossSpots: Bool = true

    var body: some View {
        WizardScreen(
            title: "Lengre opphold",
            subtitle: "Sett en fast pris for et fullt døgn, en uke eller en måned. Gjør det attraktivt for gjester å booke lenger."
        ) {
            VStack(spacing: 16) {
                if form.spotMarkers.count > 1 {
                    sharedToggle
                }

                if sharedAcrossSpots || form.spotMarkers.count <= 1 {
                    longerStayCard(
                        title: "Alle plasser",
                        subtitle: "Bruk samme priser for alle plassene dine",
                        binding: sharedPriceBinding
                    )
                } else {
                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                        longerStayCard(
                            title: spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? spot.label! : "Plass \(idx + 1)",
                            subtitle: "Per døgn: \(spot.price ?? 0) kr",
                            binding: spotPriceBinding(for: idx)
                        )
                    }
                }

                infoCard
            }
        }
        .onAppear {
            // Hvis alle plasser har samme priser, default til shared-modus.
            if form.spotMarkers.count > 1, !allSpotsHaveSamePrices {
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
                Text(sharedAcrossSpots ? "Ett pris-sett gjelder alle." : "Sett pris per plass.")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
            Spacer()
            Toggle("", isOn: $sharedAcrossSpots)
                .labelsHidden()
                .tint(Color.primary600)
                .onChange(of: sharedAcrossSpots) { _, newValue in
                    if newValue {
                        applyFirstSpotPricesToAll()
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
    private func longerStayCard(title: String, subtitle: String, binding: Binding<LongerStayPrices>) -> some View {
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
                priceRow(
                    label: "1 døgn",
                    caption: "Pris for et helt døgn",
                    baseline: representativeDailyRate,
                    price: binding.daily
                )
                priceRow(
                    label: "1 uke",
                    caption: "Pris for 7 påfølgende fulle døgn",
                    baseline: representativeDailyRate * 7,
                    price: binding.weekly
                )
                priceRow(
                    label: "1 måned",
                    caption: "Pris for 30 påfølgende fulle døgn",
                    baseline: representativeDailyRate * 30,
                    price: binding.monthly
                )
            }

            LongerStayPreviewCard(
                hourlyRate: representativeDailyRate,
                prices: binding.wrappedValue
            )
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }

    /// Representativ døgnpris for forhåndsvisning av "Lengre opphold"-tilbud.
    /// Bruker første spot — alle spots har samme pris i delt-modus.
    private var representativeDailyRate: Int {
        form.spotMarkers.first?.price ?? 0
    }

    @ViewBuilder
    private func priceRow(label: String, caption: String, baseline: Int, price: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
                KrInput(value: price)
            }
            if baseline > 0 {
                Text("Uten tilbud: \(formatKr(baseline))")
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
            }
        }
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.primary600)
            Text("Tilbudet gjelder kun fulle perioder. Hvis bookingen er 35 dager, beregnes det som 1 måned + 5 døgn. Resten betales etter standardpris.")
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

    private var sharedPriceBinding: Binding<LongerStayPrices> {
        Binding(
            get: {
                let s = form.spotMarkers.first
                return LongerStayPrices(
                    daily: s?.dailyPrice ?? nil,
                    weekly: s?.weeklyPrice ?? nil,
                    monthly: s?.monthlyPrice ?? nil
                )
            },
            set: { newValue in
                for i in form.spotMarkers.indices {
                    form.spotMarkers[i].dailyPrice = newValue.daily
                    form.spotMarkers[i].weeklyPrice = newValue.weekly
                    form.spotMarkers[i].monthlyPrice = newValue.monthly
                    // Fjern legacy %-felter når host setter kr-priser, så det
                    // ikke ligger dobbel-konfig i DB.
                    form.spotMarkers[i].discountDayPct = nil
                    form.spotMarkers[i].discountWeekPct = nil
                    form.spotMarkers[i].discountMonthPct = nil
                }
            }
        )
    }

    private func spotPriceBinding(for index: Int) -> Binding<LongerStayPrices> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(index) else { return LongerStayPrices() }
                let s = form.spotMarkers[index]
                return LongerStayPrices(daily: s.dailyPrice, weekly: s.weeklyPrice, monthly: s.monthlyPrice)
            },
            set: { newValue in
                guard form.spotMarkers.indices.contains(index) else { return }
                form.spotMarkers[index].dailyPrice = newValue.daily
                form.spotMarkers[index].weeklyPrice = newValue.weekly
                form.spotMarkers[index].monthlyPrice = newValue.monthly
                form.spotMarkers[index].discountDayPct = nil
                form.spotMarkers[index].discountWeekPct = nil
                form.spotMarkers[index].discountMonthPct = nil
            }
        )
    }

    // MARK: - Helpers

    private var allSpotsHaveSamePrices: Bool {
        guard let first = form.spotMarkers.first else { return true }
        return form.spotMarkers.allSatisfy { spot in
            spot.dailyPrice == first.dailyPrice
                && spot.weeklyPrice == first.weeklyPrice
                && spot.monthlyPrice == first.monthlyPrice
        }
    }

    private func applyFirstSpotPricesToAll() {
        guard let first = form.spotMarkers.first else { return }
        let prices = LongerStayPrices(
            daily: first.dailyPrice,
            weekly: first.weeklyPrice,
            monthly: first.monthlyPrice
        )
        for i in form.spotMarkers.indices {
            form.spotMarkers[i].dailyPrice = prices.daily
            form.spotMarkers[i].weeklyPrice = prices.weekly
            form.spotMarkers[i].monthlyPrice = prices.monthly
        }
    }
}

/// Container for de tre kr-prisene.
struct LongerStayPrices: Equatable {
    var daily: Int? = nil
    var weekly: Int? = nil
    var monthly: Int? = nil

    /// True hvis minst én pris er satt (>0).
    var hasAny: Bool {
        (daily ?? 0) > 0 || (weekly ?? 0) > 0 || (monthly ?? 0) > 0
    }
}

/// Lite preview-kort som viser hva en booking koster med og uten tilbudet,
/// for 1 døgn (24 t), 1 uke (7 d) og 1 måned (30 d). Skjules helt når ingen
/// pris er satt, så steget ikke skummer over for verten som vil hoppe over.
struct LongerStayPreviewCard: View {
    /// Døgn-pris (kr/døgn). Beholder navn `hourlyRate` for kompatibilitet med
    /// kallsteder som ikke har migrert. Etter parkering-per-dag-refaktoren
    /// representerer feltet alltid kr/døgn.
    let hourlyRate: Int
    let prices: LongerStayPrices

    var body: some View {
        if prices.hasAny && hourlyRate > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary600)
                    Text("Slik ser tilbudene ut for gjesten")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.neutral600)
                }
                if let p = prices.daily, p > 0 {
                    previewRow(label: "1 døgn", days: 1, tierPrice: p)
                }
                if let p = prices.weekly, p > 0 {
                    previewRow(label: "1 uke", days: 7, tierPrice: p)
                }
                if let p = prices.monthly, p > 0 {
                    previewRow(label: "1 måned", days: 30, tierPrice: p)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary50.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func previewRow(label: String, days: Int, tierPrice: Int) -> some View {
        let baseTotal = hourlyRate * days
        let savings = max(0, baseTotal - tierPrice)

        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral800)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 6) {
                    Text(formatKr(baseTotal))
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral400)
                        .strikethrough()
                    Text(formatKr(tierPrice))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.neutral900)
                }
                if savings > 0 {
                    Text("Gjest sparer \(formatKr(savings))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary700)
                }
            }
        }
    }
}

func formatKr(_ value: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = " "
    f.maximumFractionDigits = 0
    return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") kr"
}

/// Numerisk kr-input. Tøm-på-tap så bruker kan skrive nytt tall direkte.
struct KrInput: View {
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
                .frame(width: 90)
            Text("kr")
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
        let clamped = max(0, parsed)
        value = clamped > 0 ? clamped : nil
        text = clamped > 0 ? "\(clamped)" : ""
    }
}
