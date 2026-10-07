import SwiftUI

/// Steg 2 i parkering-wizarden: type plass, antall, dagspris + månedspris,
/// gebyr-oversikt («Du får hele prisen du setter») og en liten
/// inntjenings-kalkulator med belegg-presets.
struct ParkingPriceStep: View {
    @ObservedObject var form: ListingFormModel

    @State private var dailyText: String = ""
    @State private var monthlyText: String = ""
    /// Belegg-preset for kalkulatoren (andel av dagene som leies ut ved dagsleie).
    @State private var occupancy: Double = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plass og pris")
                        .font(.tuno(.title))
                        .foregroundStyle(.neutral900)
                    Text("Du setter prisen. Tuno-gebyret legges på toppen for leietaker, så du får hele prisen du setter.")
                        .font(.tuno(.body))
                        .foregroundStyle(.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Type plass
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hva slags plass er det?")
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                    HStack(spacing: 8) {
                        typeCapsule(.outdoor, label: "Utendørs")
                        typeCapsule(.garage, label: "Garasje")
                        typeCapsule(.parkingHouse, label: "P-hus")
                    }
                }

                // Antall plasser
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hvor mange plasser?")
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                    HStack(spacing: 16) {
                        stepperButton(systemName: "minus") {
                            if form.spots > 1 { form.spots -= 1 }
                        }
                        Text("\(form.spots)")
                            .font(.tuno(.title))
                            .foregroundStyle(.neutral900)
                            .frame(minWidth: 40)
                            .contentTransition(.numericText())
                        stepperButton(systemName: "plus") {
                            if form.spots < 5 { form.spots += 1 }
                        }
                        Spacer()
                    }
                }

                // Priser
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pris")
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                    priceField(title: "Dagsleie", unit: "kr per dag", text: $dailyText) { value in
                        form.parkingDailyPrice = value
                    }
                    priceField(title: "Fast månedsplass", unit: "kr per måned", text: $monthlyText) { value in
                        form.parkingMonthlyPrice = value
                    }
                }

                if let day = form.parkingDailyPrice, day > 0 {
                    FeeBreakdownCard(subtotal: day, unitLabel: "dag")
                }

                calculatorCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .onAppear {
            if let d = form.parkingDailyPrice, d > 0 { dailyText = "\(d)" }
            if let m = form.parkingMonthlyPrice, m > 0 { monthlyText = "\(m)" }
            if form.parkingType == nil { form.parkingType = .outdoor }
        }
    }

    // MARK: - Kalkulator

    private var estimatedMonthly: Int? {
        guard let day = form.parkingDailyPrice, day > 0 else { return nil }
        let viaDays = Int((Double(day) * 30.0 * occupancy).rounded())
        let viaMonth = form.parkingMonthlyPrice ?? 0
        return max(viaDays, viaMonth) * max(1, form.spots)
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hva kan du tjene?")
                .font(.tuno(.heading))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                occupancyChip(0.3, label: "Lavt belegg")
                occupancyChip(0.6, label: "Middels")
                occupancyChip(0.85, label: "Høyt")
            }

            if let estimate = estimatedMonthly {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimert per måned")
                        .font(.tuno(.label))
                        .foregroundStyle(Color.inkMuted)
                    Text("ca. \(estimate) kr")
                        .font(.tuno(.display))
                        .foregroundStyle(Color.mint)
                }
            } else {
                Text("Sett en dagspris for å se estimatet.")
                    .font(.tuno(.body))
                    .foregroundStyle(Color.inkMuted)
            }

            Text("Estimat, ikke en garanti. Avhenger av beliggenhet og etterspørsel.")
                .font(.tuno(.caption))
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.card))
    }

    private func occupancyChip(_ value: Double, label: String) -> some View {
        let isSelected = abs(occupancy - value) < 0.01
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { occupancy = value }
        } label: {
            Text(label)
                .font(.tuno(.label))
                .foregroundStyle(isSelected ? Color.mintInk : Color.inkText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.mint : Color.inkElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Felt-komponenter

    private func typeCapsule(_ type: ParkingType, label: String) -> some View {
        let isSelected = form.parkingType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { form.parkingType = type }
        } label: {
            Text(label)
                .font(.tuno(.body))
                .foregroundStyle(isSelected ? .white : .neutral900)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.ink : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.ink : Color.neutral200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func priceField(title: String, unit: String, text: Binding<String>, onChange: @escaping (Int?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.tuno(.label))
                .foregroundStyle(.neutral600)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .keyboardType(.numberPad)
                    .font(.tuno(.title))
                    .foregroundStyle(.neutral900)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue { text.wrappedValue = digits }
                        onChange(Int(digits))
                    }
                Text(unit)
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral500)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: TunoRadius.control)
                    .stroke(Color.neutral200, lineWidth: 1)
            )
        }
    }
}
