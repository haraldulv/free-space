import SwiftUI

/// Steg 2 i parkering-wizarden: type plass, antall, dagspris + månedspris,
/// gebyr-oversikt («Du får hele prisen du setter») og en liten
/// inntjenings-kalkulator med belegg-presets.
struct ParkingPriceStep: View {
    @ObservedObject var form: ListingFormModel

    @State private var dailyText: String = ""
    @State private var monthlyText: String = ""
    @State private var noteText: String = ""
    /// Belegg-preset for kalkulatoren (andel av dagene som leies ut ved dagsleie).
    @State private var occupancy: Double = 0.6

    /// Fokus-kjede for feltene. numberPad har ingen returtast, så en egen
    /// «Neste felt»-bar (safeAreaInset, se feedback_swiftui_keyboard_toolbar)
    /// tar brukeren videre.
    private enum Field: Hashable { case daily, package, note }
    @FocusState private var focusedField: Field?

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
                    priceField(title: "Dagsleie", unit: "kr per dag", text: $dailyText, field: .daily) { value in
                        form.parkingDailyPrice = value
                    }
                    priceField(title: "Fast pakke (valgfritt)", unit: "kr for hele pakken", text: $monthlyText, field: .package) { value in
                        form.parkingMonthlyPrice = value
                    }

                    if (form.parkingMonthlyPrice ?? 0) > 0 {
                        packageEditor
                    }
                }

                if let day = form.parkingDailyPrice, day > 0 {
                    FeeBreakdownCard(subtotal: day, unitLabel: "dag")
                }

                // Utleier skal VITE at prisforslag kan komme (Kim-møtet:
                // «tydelig for begge parter»).
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.neutral700)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Leietakere kan foreslå pris for lengre perioder")
                            .font(.tuno(.body))
                            .foregroundStyle(.neutral900)
                        Text("Du får forslaget i meldinger og bestemmer selv: godta, avslå, eller foreslå en annen pris.")
                            .font(.tuno(.caption))
                            .foregroundStyle(.neutral600)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paperCard)
                .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                        .stroke(Color.paperLine, lineWidth: 1)
                )

                // Kalkulatoren er død vekt uten dagspris; vis den først når
                // den har noe å estimere.
                if (form.parkingDailyPrice ?? 0) > 0 {
                    calculatorCard
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: (form.parkingDailyPrice ?? 0) > 0)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .onAppear {
            if let d = form.parkingDailyPrice, d > 0 { dailyText = "\(d)" }
            if let m = form.parkingMonthlyPrice, m > 0 { monthlyText = "\(m)" }
            if !form.parkingPackageNote.isEmpty { noteText = form.parkingPackageNote }
            if form.parkingType == nil { form.parkingType = .outdoor }
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                keyboardBar
            }
        }
    }

    // MARK: - Tastatur-navigasjon

    private var nextField: Field? {
        switch focusedField {
        case .daily: return .package
        case .package: return (form.parkingMonthlyPrice ?? 0) > 0 ? .note : nil
        default: return nil
        }
    }

    private var keyboardBar: some View {
        HStack {
            if let next = nextField {
                Button {
                    focusedField = next
                } label: {
                    HStack(spacing: 5) {
                        Text("Neste felt")
                            .font(.tuno(.label))
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.neutral900)
                }
            }
            Spacer()
            Button("Ferdig") {
                focusedField = nil
            }
            .font(.tuno(.label))
            .foregroundStyle(.neutral900)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Kim-pakken: dager + melding

    /// Pakke-detaljer: hvor mange dager pakken gjelder (2-30) og en valgfri
    /// melding/forbehold som leietaker ser før betaling, f.eks.
    /// «Plassen kan brukes man-fre 08-18».
    private var packageEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hvor mange dager gjelder pakken?")
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral700)
                HStack(spacing: 16) {
                    stepperButton(systemName: "minus") {
                        if form.parkingPackageDays > 2 { form.parkingPackageDays -= 1 }
                    }
                    Text(form.parkingPackageDays == 30 ? "30 dager (månedsplass)" : "\(form.parkingPackageDays) dager")
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                        .frame(minWidth: 120)
                        .contentTransition(.numericText())
                    stepperButton(systemName: "plus") {
                        if form.parkingPackageDays < 30 { form.parkingPackageDays += 1 }
                    }
                    Spacer()
                }
                Text("F.eks. 20 dager hvis plassen bare kan brukes på hverdager.")
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Melding til leietaker (valgfritt)")
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral700)
                TextField(
                    "F.eks. Plassen kan brukes man-fre 08-18.",
                    text: $noteText,
                    axis: .vertical
                )
                .focused($focusedField, equals: .note)
                .font(.tuno(.body))
                .lineLimit(2...4)
                .padding(12)
                .background(Color.paperCard)
                .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                        .stroke(Color.paperLine, lineWidth: 1)
                )
                .onChange(of: noteText) { _, newValue in
                    form.parkingPackageNote = newValue
                }
                Text("Vises for leietaker før betaling.")
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)
            }
        }
        .padding(14)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
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

    private func priceField(title: String, unit: String, text: Binding<String>, field: Field, onChange: @escaping (Int?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.tuno(.label))
                .foregroundStyle(.neutral600)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: field)
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
