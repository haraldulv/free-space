import SwiftUI

/// Editor for pris-regler på én annonse. Speiler web PricingRulesPanel.
/// - Camping (per natt): helg-pris (én regel) + sesong-perioder.
/// - Parkering per time: time-bånd-regler (flere) + sesong/helg gjelder ikke i v1.
/// - Parkering per døgn: samme som camping (helg + sesong).
struct PricingRulesEditorView: View {
    let listingId: String
    let basePrice: Int
    /// Pris-enhet for visning og hvilke seksjoner som vises.
    var priceUnit: PriceUnit = .natt

    private var unitLabel: String { priceUnit.displayName }
    private var isHourly: Bool { priceUnit == .hour }

    @Environment(\.dismiss) var dismiss
    @State private var rules: [PricingService.Rule] = []
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?

    // Helg-state (camping/døgn)
    @State private var weekendEnabled = false
    @State private var weekendPriceText = ""
    @State private var weekendDirty = false

    // Ny sesong-state
    @State private var newSeasonStart = Date()
    @State private var newSeasonEnd = Date()
    @State private var newSeasonPriceText = ""

    // Time-bånd-state
    @State private var showAddBandSheet = false
    @State private var bandSheetPrefill: BandPrefill?

    private var weekendRule: PricingService.Rule? {
        rules.first(where: { $0.kind == "weekend" })
    }

    private var seasonRules: [PricingService.Rule] {
        rules
            .filter { $0.kind == "season" }
            .sorted { ($0.start_date ?? "") < ($1.start_date ?? "") }
    }

    private var hourlyBandRules: [PricingService.Rule] {
        rules
            .filter { $0.kind == "hourly" }
            .sorted {
                let a = ($0.day_mask ?? 0)
                let b = ($1.day_mask ?? 0)
                if a != b { return a < b }
                return ($0.start_hour ?? 0) < ($1.start_hour ?? 0)
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            introText

                            if isHourly {
                                hourlyBandSection
                            } else {
                                weekendSection
                                seasonSection
                            }

                            if let error {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Prisregler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAddBandSheet) {
                AddHourlyBandSheet(
                    basePrice: basePrice,
                    prefill: bandSheetPrefill,
                ) { dayMask, startHour, endHour, price in
                    Task { await addHourlyBand(dayMask: dayMask, startHour: startHour, endHour: endHour, price: price) }
                }
            }
        }
    }

    private var introText: some View {
        Group {
            if isHourly {
                Text("Standardpris er \(basePrice) kr/time. Legg til time-bånd som gjelder bestemte dager og klokkeslett.")
            } else {
                Text("Annonsens standardpris er \(basePrice) kr/\(unitLabel). Legg til helg-pris eller sesong-regler som overstyrer.")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.neutral600)
    }

    // MARK: - Helg-seksjon

    private var weekendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Helg-pris")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Fredag, lørdag og søndag får egen pris. Presedens: sesong > helg > standard.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { weekendEnabled },
                    set: { newVal in
                        weekendEnabled = newVal
                        weekendDirty = true
                    }
                ))
                .labelsHidden()
                .tint(.primary600)
            }

            if weekendEnabled {
                HStack(spacing: 8) {
                    TextField("F.eks. \(Int(Double(basePrice) * 1.25))", text: $weekendPriceText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 140)
                        .onChange(of: weekendPriceText) { _, _ in weekendDirty = true }
                    Text("kr/\(unitLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
            }

            if weekendDirty {
                Button {
                    Task { await saveWeekend() }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().scaleEffect(0.7).tint(.white) }
                        Text("Lagre helg-pris")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary600)
                    .clipShape(Capsule())
                }
                .disabled(saving)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Sesong-seksjon

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sesong-pris")
                    .font(.system(size: 16, weight: .semibold))
                Text("Sett pris for en periode (f.eks. sommeruker). Overstyrer helg og standard.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            ForEach(seasonRules) { rule in
                seasonRuleRow(rule)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Legg til sesong")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.neutral700)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Fra").font(.system(size: 11)).foregroundStyle(.neutral500)
                        DatePicker("", selection: $newSeasonStart, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Til").font(.system(size: 11)).foregroundStyle(.neutral500)
                        DatePicker("", selection: $newSeasonEnd, in: newSeasonStart..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Pris", text: $newSeasonPriceText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 100)
                    Text("kr/\(unitLabel)").font(.system(size: 13)).foregroundStyle(.neutral500)
                    Spacer()
                    Button {
                        Task { await addSeason() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Legg til")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(canAddSeason ? Color.primary600 : Color.neutral300)
                        .clipShape(Capsule())
                    }
                    .disabled(!canAddSeason || saving)
                }
            }
            .padding(12)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private var canAddSeason: Bool {
        guard let price = Int(newSeasonPriceText), price > 0 else { return false }
        return newSeasonStart <= newSeasonEnd
    }

    private func seasonRuleRow(_ rule: PricingService.Rule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.primary600)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                if let s = rule.start_date, let e = rule.end_date {
                    Text("\(s) – \(e)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral900)
                }
                Text("\(rule.price) kr/\(unitLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)
            }
            Spacer()
            Button {
                Task { await removeRule(rule) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .disabled(saving)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
    }

    // MARK: - Hourly-bånd-seksjon

    private var hourlyBandSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Time-bånd")
                    .font(.system(size: 16, weight: .semibold))
                Text("Legg til pris for bestemte dager og klokkeslett — f.eks. arbeidstid, kveld eller helg. Bånd uten dekning bruker standardprisen.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }

            // Eksisterende bånd
            if !hourlyBandRules.isEmpty {
                VStack(spacing: 8) {
                    ForEach(hourlyBandRules) { rule in
                        hourlyBandRow(rule)
                    }
                }
            }

            // Default-knapper
            VStack(alignment: .leading, spacing: 8) {
                Text("Hurtigvalg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(BandPrefill.defaults) { prefill in
                        Button {
                            bandSheetPrefill = prefill
                            showAddBandSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prefill.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.neutral900)
                                Text(prefill.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.neutral500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Free form-knapp
            Button {
                bandSheetPrefill = nil
                showAddBandSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Legg til eget bånd")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary700)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.primary50)
                .clipShape(Capsule())
            }
            .disabled(saving)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func hourlyBandRow(_ rule: PricingService.Rule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundStyle(Color.primary600)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text(formatBandLabel(rule))
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral900)
                Text("\(rule.price) kr/time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral600)
            }
            Spacer()
            Button {
                Task { await removeRule(rule) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .disabled(saving)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
    }

    private func formatBandLabel(_ rule: PricingService.Rule) -> String {
        let mask = rule.day_mask ?? 0
        let sh = rule.start_hour ?? 0
        let eh = rule.end_hour ?? 0
        let dayPart = formatDayMask(mask)
        return "\(dayPart) · \(twoDigit(sh)):00–\(twoDigit(eh)):00"
    }

    private func twoDigit(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    private func formatDayMask(_ mask: Int) -> String {
        let weekdaysMask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
        let weekendMask = (1 << 5) | (1 << 6)
        let allMask = weekdaysMask | weekendMask
        if mask == allMask { return "Alle dager" }
        if mask == weekdaysMask { return "Hverdager" }
        if mask == weekendMask { return "Helg" }
        let names = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
        return (0..<7).compactMap { i in (mask & (1 << i)) != 0 ? names[i] : nil }.joined(separator: ", ")
    }

    // MARK: - Actions

    private func load() async {
        loading = true
        rules = await PricingService.fetchRules(listingId: listingId)
        if let w = weekendRule {
            weekendEnabled = true
            weekendPriceText = String(w.price)
        } else {
            weekendEnabled = false
            weekendPriceText = String(Int(Double(basePrice) * 1.25))
        }
        weekendDirty = false
        loading = false
    }

    private func saveWeekend() async {
        error = nil
        saving = true
        defer { saving = false }
        let price: Int? = weekendEnabled ? Int(weekendPriceText) : nil
        if weekendEnabled && (price ?? 0) <= 0 {
            error = "Ugyldig pris."
            return
        }
        do {
            try await PricingService.setWeekendPrice(listingId: listingId, price: price)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addSeason() async {
        error = nil
        guard canAddSeason, let price = Int(newSeasonPriceText) else {
            error = "Sjekk pris og datoer."
            return
        }
        saving = true
        defer { saving = false }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Europe/Oslo")
        let start = fmt.string(from: newSeasonStart)
        let end = fmt.string(from: newSeasonEnd)
        do {
            try await PricingService.addSeasonRule(
                listingId: listingId,
                startDate: start,
                endDate: end,
                price: price,
            )
            newSeasonPriceText = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addHourlyBand(dayMask: Int, startHour: Int, endHour: Int, price: Int) async {
        error = nil
        saving = true
        defer { saving = false }
        do {
            try await PricingService.addHourlyBandRule(
                listingId: listingId,
                dayMask: dayMask,
                startHour: startHour,
                endHour: endHour,
                price: price,
            )
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func removeRule(_ rule: PricingService.Rule) async {
        error = nil
        saving = true
        defer { saving = false }
        do {
            try await PricingService.removeRule(ruleId: rule.id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Default-bånd

struct BandPrefill: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let dayMask: Int
    let startHour: Int
    let endHour: Int

    static let weekdaysMask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
    static let weekendMask = (1 << 5) | (1 << 6)
    static let allDaysMask = weekdaysMask | weekendMask

    static let defaults: [BandPrefill] = [
        BandPrefill(
            id: "weekday-work",
            label: "Hverdager arbeidstid",
            subtitle: "Man–Fre · 09–17",
            dayMask: weekdaysMask,
            startHour: 9, endHour: 17,
        ),
        BandPrefill(
            id: "weekday-evening",
            label: "Hverdager kveld",
            subtitle: "Man–Fre · 17–22",
            dayMask: weekdaysMask,
            startHour: 17, endHour: 22,
        ),
        BandPrefill(
            id: "weekend-day",
            label: "Helg dag",
            subtitle: "Lør–Søn · 09–22",
            dayMask: weekendMask,
            startHour: 9, endHour: 22,
        ),
        BandPrefill(
            id: "all-night",
            label: "Alle dager natt",
            subtitle: "Man–Søn · 22–24",
            dayMask: allDaysMask,
            startHour: 22, endHour: 24,
        ),
    ]
}

// MARK: - Add bånd-sheet

struct AddHourlyBandSheet: View {
    let basePrice: Int
    let prefill: BandPrefill?
    let onSave: (_ dayMask: Int, _ startHour: Int, _ endHour: Int, _ price: Int) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedDays: Set<Int> = []
    @State private var startHour: Int = 9
    @State private var endHour: Int = 17
    @State private var priceText: String = ""

    private let dayNames = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]

    private var dayMask: Int {
        selectedDays.reduce(0) { $0 | (1 << $1) }
    }

    private var canSave: Bool {
        guard let p = Int(priceText), p > 0 else { return false }
        return !selectedDays.isEmpty && endHour > startHour
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    daysSection
                    hoursSection
                    priceSection
                }
                .padding(16)
            }
            .navigationTitle(prefill?.label ?? "Nytt bånd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") {
                        if let price = Int(priceText) {
                            onSave(dayMask, startHour, endHour, price)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let prefill {
                // Bygg Set fra dayMask
                selectedDays = Set((0..<7).filter { (prefill.dayMask & (1 << $0)) != 0 })
                startHour = prefill.startHour
                endHour = prefill.endHour
            }
        }
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dager")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let selected = selectedDays.contains(i)
                    Button {
                        if selected { selectedDays.remove(i) }
                        else { selectedDays.insert(i) }
                    } label: {
                        Text(dayNames[i])
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? Color.primary600 : Color.neutral50)
                            .foregroundStyle(selected ? .white : .neutral700)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Klokkeslett")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fra").font(.system(size: 12)).foregroundStyle(.neutral500)
                    Stepper(value: $startHour, in: 0...23) {
                        Text("\(twoDigit(startHour)):00")
                            .font(.system(size: 15, weight: .medium))
                            .monospacedDigit()
                    }
                    .onChange(of: startHour) { _, newVal in
                        if endHour <= newVal { endHour = min(24, newVal + 1) }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Til").font(.system(size: 12)).foregroundStyle(.neutral500)
                    Stepper(value: $endHour, in: max(1, startHour + 1)...24) {
                        Text("\(twoDigit(endHour)):00")
                            .font(.system(size: 15, weight: .medium))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pris")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 8) {
                TextField("F.eks. \(basePrice)", text: $priceText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 140)
                Text("kr/time")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                Spacer()
            }
        }
    }

    private func twoDigit(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
