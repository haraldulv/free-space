import SwiftUI

/// "Lengre opphold"-steg (parkering only).
///
/// Lar verten sette pris-pakker pr. plass:
///   - Standard 1 uke (valgfritt) — pris for 7 påfølgende fulle dager.
///   - Standard 1 måned (valgfritt) — pris for 30 påfølgende fulle dager.
/// I tillegg kan verten legge til custom pakker via "Legg til pakke":
///   - DAY: 1-6 dager
///   - WEEK: 1-3 uker
///   - MONTH: 1-11 måneder
///   - YEAR: 1-3 år
///
/// Duplikater (samme periodType + periodValue) er ikke tillatt.
///
/// 1-dags-pakken vises som locked read-only på toppen — settes i pris-steget.
struct SpotDiscountsStep: View {
    @ObservedObject var form: ListingFormModel

    @State private var sharedAcrossSpots: Bool = true
    @State private var addPackageContext: AddPackageContext? = nil

    var body: some View {
        WizardScreen(
            title: "Leieperioder",
            subtitle: "Velg hvilke perioder du tilbyr."
        ) {
            VStack(spacing: 16) {
                if form.spotMarkers.count > 1 {
                    sharedToggle
                }

                if sharedAcrossSpots || form.spotMarkers.count <= 1 {
                    spotPackageCard(spotIndex: 0, applyToAll: true)
                } else {
                    ForEach(Array(form.spotMarkers.enumerated()), id: \.offset) { idx, spot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? spot.label! : "Plass \(idx + 1)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.neutral500)
                            spotPackageCard(spotIndex: idx, applyToAll: false)
                        }
                    }
                }
            }
        }
        .onAppear {
            if form.spotMarkers.count > 1, !allSpotsHaveSamePackages {
                sharedAcrossSpots = false
            }
        }
        .sheet(item: $addPackageContext) { ctx in
            AddPricePackageSheet(
                existing: existingPackages(at: ctx.spotIndex),
                onAdd: { newPackage in
                    addPackage(newPackage, spotIndex: ctx.spotIndex, applyToAll: ctx.applyToAll)
                    addPackageContext = nil
                },
                onCancel: {
                    addPackageContext = nil
                }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(28)
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
                        applyFirstSpotPackagesToAll()
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
    private func spotPackageCard(spotIndex: Int, applyToAll: Bool) -> some View {
        VStack(spacing: 8) {
            // 4 ENS toggleable standard-perioder
            periodToggleRow(label: "1 dag", periodType: .day, periodValue: 1, spotIndex: spotIndex, applyToAll: applyToAll)
            periodToggleRow(label: "1 uke", periodType: .week, periodValue: 1, spotIndex: spotIndex, applyToAll: applyToAll)
            periodToggleRow(label: "1 måned", periodType: .month, periodValue: 1, spotIndex: spotIndex, applyToAll: applyToAll)
            periodToggleRow(label: "1 år", periodType: .year, periodValue: 1, spotIndex: spotIndex, applyToAll: applyToAll)

            // Custom pakker
            let customPkgs = customPackages(at: spotIndex)
            ForEach(customPkgs) { pkg in
                customPackageRow(pkg, spotIndex: spotIndex, applyToAll: applyToAll)
            }

            // "Legg til pakke"
            Button {
                addPackageContext = AddPackageContext(spotIndex: spotIndex, applyToAll: applyToAll)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Legg til pakke")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.primary600)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.primary50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    /// ENS layout for alle 4 standard-perioder. Tydelig avkrysning til venstre,
    /// label i midten, fixed-bredde pris-input til høyre. Tap på rad toggler.
    @ViewBuilder
    private func periodToggleRow(
        label: String,
        periodType: PricePackagePeriodType,
        periodValue: Int,
        spotIndex: Int,
        applyToAll: Bool
    ) -> some View {
        let binding = bindingFor(periodType: periodType, periodValue: periodValue, spotIndex: spotIndex, applyToAll: applyToAll)
        let isEnabled = (binding.wrappedValue ?? 0) > 0
        let basePrice = form.spotMarkers.indices.contains(spotIndex)
            ? (form.spotMarkers[spotIndex].price ?? 0)
            : 0
        let suggested = Self.suggestedPrice(forTier: periodType, periodValue: periodValue, dailyPrice: basePrice)
        let showSuggestion = !isEnabled && suggested > 0 && !(periodType == .day && periodValue == 1)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Hele venstre-siden (sjekkboks + label) toggler raden.
                Button {
                    if isEnabled {
                        binding.wrappedValue = nil
                    } else {
                        binding.wrappedValue = suggested > 0 ? suggested : (basePrice > 0 ? basePrice : nil)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isEnabled ? Color.primary600 : Color.neutral300)
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isEnabled ? .neutral900 : .neutral500)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // KrStepper er alltid hit-testable. Bruker kan tappe pris-feltet
                // direkte for å skrive et tall — pakken aktiveres automatisk når
                // verdien blir > 0.
                KrStepper(value: binding, step: 50, minValue: 0, maxValue: nil, unitLabel: "kr", placeholder: "0")
                    .frame(width: 170)
                    .opacity(isEnabled ? 1 : 0.6)
            }

            if showSuggestion {
                Button {
                    binding.wrappedValue = suggested
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Foreslått: \(Self.formatKr(suggested))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary50)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isEnabled ? Color.white : Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? Color.primary600 : Color.neutral200, lineWidth: isEnabled ? 1.5 : 1)
        )
    }

    /// Standard rabattskala for lengre opphold. Brukes som auto-forslag i UI.
    /// Uke = 10% rabatt, måned = 25%, år = 40%. Avrundes til nærmeste 50 kr.
    static func suggestedPrice(forTier tier: PricePackagePeriodType, periodValue: Int, dailyPrice: Int) -> Int {
        guard dailyPrice > 0 else { return 0 }
        let raw: Double
        switch tier {
        case .day: raw = Double(dailyPrice * periodValue)
        case .week: raw = Double(dailyPrice) * 7.0 * Double(periodValue) * 0.9
        case .month: raw = Double(dailyPrice) * 30.0 * Double(periodValue) * 0.75
        case .year: raw = Double(dailyPrice) * 365.0 * Double(periodValue) * 0.6
        }
        let rounded = Int((raw / 50.0).rounded()) * 50
        return max(rounded, 50)
    }

    static func formatKr(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") kr"
    }

    /// Felles binding-helper. For DAY-1: lagres på spot.price (som beholder
    /// basis-prisen). For andre: lagres i pricePackages-arrayen.
    private func bindingFor(
        periodType: PricePackagePeriodType,
        periodValue: Int,
        spotIndex: Int,
        applyToAll: Bool
    ) -> Binding<Int?> {
        if periodType == .day && periodValue == 1 {
            return Binding<Int?>(
                get: {
                    guard form.spotMarkers.indices.contains(spotIndex) else { return nil }
                    let p = form.spotMarkers[spotIndex].price ?? 0
                    return p > 0 ? p : nil
                },
                set: { newValue in
                    let indices = applyToAll ? Array(form.spotMarkers.indices) : [spotIndex]
                    for i in indices {
                        form.spotMarkers[i].price = (newValue ?? 0) > 0 ? newValue : nil
                    }
                }
            )
        }
        return packageBinding(
            periodType: periodType,
            periodValue: periodValue,
            spotIndex: spotIndex,
            applyToAll: applyToAll
        )
    }

    @ViewBuilder
    private func customPackageRow(_ pkg: PricePackage, spotIndex: Int, applyToAll: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pkg.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("\(pkg.priceNok) kr")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary600)
            }
            Spacer()
            Button {
                removePackage(pkg, spotIndex: spotIndex, applyToAll: applyToAll)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.neutral500)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.neutral200, lineWidth: 1)
        )
    }

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.primary600)
            Text("Pakkene gjelder kun fulle perioder. Hvis bookingen er 35 dager, beregnes det som 1 måned + 5 dager til standardpris.")
                .font(.system(size: 12))
                .foregroundStyle(.neutral600)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Package mutations

    private func packageBinding(periodType: PricePackagePeriodType, periodValue: Int, spotIndex: Int, applyToAll: Bool) -> Binding<Int?> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(spotIndex) else { return nil }
                return form.spotMarkers[spotIndex].pricePackages?.first { $0.periodType == periodType && $0.periodValue == periodValue }?.priceNok
            },
            set: { newValue in
                if let v = newValue, v > 0 {
                    let pkg = PricePackage(periodType: periodType, periodValue: periodValue, priceNok: v)
                    upsertPackage(pkg, spotIndex: spotIndex, applyToAll: applyToAll)
                } else {
                    removePackage(.init(periodType: periodType, periodValue: periodValue, priceNok: 0), spotIndex: spotIndex, applyToAll: applyToAll)
                }
            }
        )
    }

    private func customPackages(at spotIndex: Int) -> [PricePackage] {
        guard form.spotMarkers.indices.contains(spotIndex) else { return [] }
        let all = form.spotMarkers[spotIndex].pricePackages ?? []
        // Standard pakker: WEEK-1 og MONTH-1. Resten er custom.
        return all.filter { pkg in
            !(pkg.periodType == .week && pkg.periodValue == 1)
                && !(pkg.periodType == .month && pkg.periodValue == 1)
        }.sortedForDisplay
    }

    private func existingPackages(at spotIndex: Int) -> [PricePackage] {
        guard form.spotMarkers.indices.contains(spotIndex) else { return [] }
        return form.spotMarkers[spotIndex].pricePackages ?? []
    }

    private func upsertPackage(_ pkg: PricePackage, spotIndex: Int, applyToAll: Bool) {
        let indices = applyToAll ? Array(form.spotMarkers.indices) : [spotIndex]
        for i in indices {
            var packages = form.spotMarkers[i].pricePackages ?? []
            packages.removeAll { $0.periodType == pkg.periodType && $0.periodValue == pkg.periodValue }
            packages.append(pkg)
            form.spotMarkers[i].pricePackages = packages.sortedForDisplay
            // Mirror til legacy-felter for backward compat med eldre web/iOS-leser.
            mirrorLegacyPriceFields(spotIndex: i)
        }
    }

    private func addPackage(_ pkg: PricePackage, spotIndex: Int, applyToAll: Bool) {
        upsertPackage(pkg, spotIndex: spotIndex, applyToAll: applyToAll)
    }

    private func removePackage(_ pkg: PricePackage, spotIndex: Int, applyToAll: Bool) {
        let indices = applyToAll ? Array(form.spotMarkers.indices) : [spotIndex]
        for i in indices {
            var packages = form.spotMarkers[i].pricePackages ?? []
            packages.removeAll { $0.periodType == pkg.periodType && $0.periodValue == pkg.periodValue }
            form.spotMarkers[i].pricePackages = packages.isEmpty ? nil : packages
            mirrorLegacyPriceFields(spotIndex: i)
        }
    }

    /// Speile pricePackages tilbake til weeklyPrice/monthlyPrice for bakoverkompat.
    /// Eksisterende lese-paths (lib/pricing.ts, ListingDetailView) faller fortsatt tilbake
    /// på disse hvis pricePackages er tomt.
    private func mirrorLegacyPriceFields(spotIndex i: Int) {
        guard form.spotMarkers.indices.contains(i) else { return }
        let pkgs = form.spotMarkers[i].pricePackages ?? []
        form.spotMarkers[i].weeklyPrice = pkgs.first { $0.periodType == .week && $0.periodValue == 1 }?.priceNok
        form.spotMarkers[i].monthlyPrice = pkgs.first { $0.periodType == .month && $0.periodValue == 1 }?.priceNok
        // 3/6 mnd og år eksisterer ikke som standard-tier i ny UI, men beholdes
        // som legacy-mapping fra custom-pakker hvis tilstede.
        form.spotMarkers[i].threeMonthPrice = pkgs.first { $0.periodType == .month && $0.periodValue == 3 }?.priceNok
        form.spotMarkers[i].sixMonthPrice = pkgs.first { $0.periodType == .month && $0.periodValue == 6 }?.priceNok
        form.spotMarkers[i].yearPrice = pkgs.first { $0.periodType == .year && $0.periodValue == 1 }?.priceNok
        form.spotMarkers[i].dailyPrice = nil
        form.spotMarkers[i].discountDayPct = nil
        form.spotMarkers[i].discountWeekPct = nil
        form.spotMarkers[i].discountMonthPct = nil
    }

    private var allSpotsHaveSamePackages: Bool {
        guard let first = form.spotMarkers.first else { return true }
        let firstSet = Set(first.pricePackages ?? [])
        return form.spotMarkers.allSatisfy { Set($0.pricePackages ?? []) == firstSet }
    }

    private func applyFirstSpotPackagesToAll() {
        guard let first = form.spotMarkers.first else { return }
        let pkgs = first.pricePackages
        for i in form.spotMarkers.indices {
            form.spotMarkers[i].pricePackages = pkgs
            mirrorLegacyPriceFields(spotIndex: i)
        }
    }
}

struct AddPackageContext: Identifiable {
    let id = UUID()
    let spotIndex: Int
    let applyToAll: Bool
}

// MARK: - InlineRentalPeriodsView
//
// Kompakt versjon av leieperioder-UI til bruk inline i SpotPriceStep.
// Viser 4 standard-tiers (1 uke / 1 måned / 1 år), ekskluderer 1 dag som er
// dagsprisen øverst på samme side. Custom-pakker og "felles for alle plasser"
// holdes ute her — kun avansert i full EditListingView.
struct InlineRentalPeriodsView: View {
    @ObservedObject var form: ListingFormModel
    let spotIndex: Int
    var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 8) {
            tierRow(label: "1 uke", periodType: .week, idSuffix: "week")
            tierRow(label: "1 måned", periodType: .month, idSuffix: "month")
            tierRow(label: "1 år", periodType: .year, idSuffix: "year")
        }
    }

    @ViewBuilder
    private func tierRow(label: String, periodType: PricePackagePeriodType, idSuffix: String) -> some View {
        let binding = packageBinding(periodType: periodType, periodValue: 1)
        let isEnabled = (binding.wrappedValue ?? 0) > 0
        let basePrice = form.spotMarkers.indices.contains(spotIndex)
            ? (form.spotMarkers[spotIndex].price ?? 0) : 0
        let suggested = SpotDiscountsStep.suggestedPrice(forTier: periodType, periodValue: 1, dailyPrice: basePrice)
        let showSuggestion = !isEnabled && suggested > 0
        let rowId = "tier_\(idSuffix)_\(spotIndex)"

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if isEnabled {
                        binding.wrappedValue = nil
                    } else {
                        binding.wrappedValue = suggested > 0 ? suggested : basePrice
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isEnabled ? Color.primary600 : Color.neutral300)
                        Text(label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isEnabled ? .neutral900 : .neutral500)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                KrStepper(
                    value: binding,
                    step: 50,
                    minValue: 0,
                    maxValue: nil,
                    unitLabel: "kr",
                    placeholder: "0",
                    onFocusChange: { focused in
                        guard focused else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scrollProxy?.scrollTo(rowId, anchor: .center)
                            }
                        }
                    }
                )
                .frame(width: 190)
                .opacity(isEnabled ? 1 : 0.6)
            }

            if showSuggestion {
                Button {
                    binding.wrappedValue = suggested
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Foreslått: \(SpotDiscountsStep.formatKr(suggested))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary700)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary50)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isEnabled ? Color.white : Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isEnabled ? Color.primary600 : Color.neutral200, lineWidth: isEnabled ? 1.5 : 1))
        .id(rowId)
    }

    private func packageBinding(periodType: PricePackagePeriodType, periodValue: Int) -> Binding<Int?> {
        Binding(
            get: {
                guard form.spotMarkers.indices.contains(spotIndex) else { return nil }
                return form.spotMarkers[spotIndex].pricePackages?.first {
                    $0.periodType == periodType && $0.periodValue == periodValue
                }?.priceNok
            },
            set: { newValue in
                var packages = form.spotMarkers[spotIndex].pricePackages ?? []
                packages.removeAll { $0.periodType == periodType && $0.periodValue == periodValue }
                if let v = newValue, v > 0 {
                    packages.append(PricePackage(periodType: periodType, periodValue: periodValue, priceNok: v))
                }
                form.spotMarkers[spotIndex].pricePackages = packages.isEmpty ? nil : packages.sortedForDisplay
                mirrorLegacyPriceFields(spotIndex: spotIndex)
            }
        )
    }

    private func mirrorLegacyPriceFields(spotIndex i: Int) {
        guard form.spotMarkers.indices.contains(i) else { return }
        let pkgs = form.spotMarkers[i].pricePackages ?? []
        form.spotMarkers[i].weeklyPrice = pkgs.first { $0.periodType == .week && $0.periodValue == 1 }?.priceNok
        form.spotMarkers[i].monthlyPrice = pkgs.first { $0.periodType == .month && $0.periodValue == 1 }?.priceNok
        form.spotMarkers[i].yearPrice = pkgs.first { $0.periodType == .year && $0.periodValue == 1 }?.priceNok
    }
}

// MARK: - Add package sheet

struct AddPricePackageSheet: View {
    let existing: [PricePackage]
    let onAdd: (PricePackage) -> Void
    let onCancel: () -> Void

    @State private var periodType: PricePackagePeriodType = .day
    @State private var periodValue: Int = 1
    @State private var price: Int? = nil
    @State private var validationError: String? = nil
    @FocusState private var priceFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            // Topp-bar
            HStack {
                Button("Avbryt", action: onCancel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary600)
                Spacer()
                Text("Egen pakke")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Color.clear.frame(width: 50, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            // Type + Antall — én rad
            HStack(spacing: 10) {
                segmentedPicker(label: "Type", selection: $periodType, options: PricePackagePeriodType.allCases) { t in
                    t.displayName
                }
                .onChange(of: periodType) { _, _ in
                    periodValue = periodType.allowedValues.lowerBound
                    validationError = nil
                }

                segmentedPicker(label: "Antall", selection: $periodValue, options: Array(periodType.allowedValues)) { v in
                    "\(v) \(unitLabel(periodType: periodType, value: v))"
                }
            }
            .padding(.horizontal, 20)

            // Pris-input
            VStack(spacing: 6) {
                HStack {
                    TextField("0", value: $price, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .focused($priceFocused)
                    Text("kr")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.neutral500)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(priceFocused ? Color.primary600 : Color.neutral200, lineWidth: priceFocused ? 1.5 : 1)
                )
                if let err = validationError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            Button {
                validateAndAdd()
            } label: {
                Text("Legg til")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((price ?? 0) > 0 ? Color.neutral900 : Color.neutral400)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled((price ?? 0) <= 0)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear { priceFocused = true }
    }

    @ViewBuilder
    private func segmentedPicker<T: Hashable>(
        label: String,
        selection: Binding<T>,
        options: [T],
        labelFor: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button(labelFor(opt)) { selection.wrappedValue = opt }
                }
            } label: {
                HStack {
                    Text(labelFor(selection.wrappedValue))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral500)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
            }
        }
    }

    private func unitLabel(periodType: PricePackagePeriodType, value: Int) -> String {
        switch periodType {
        case .day: return value == 1 ? "dag" : "dager"
        case .week: return value == 1 ? "uke" : "uker"
        case .month: return value == 1 ? "måned" : "måneder"
        case .year: return value == 1 ? "år" : "år"
        }
    }

    private func validateAndAdd() {
        guard let p = price, p > 0 else {
            validationError = "Pris må være større enn 0."
            return
        }
        let candidate = PricePackage(periodType: periodType, periodValue: periodValue, priceNok: p)
        if existing.hasDuplicate(candidate) {
            validationError = "Du har allerede en pakke for \(candidate.label)."
            return
        }
        onAdd(candidate)
    }
}
