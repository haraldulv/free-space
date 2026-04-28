import SwiftUI
import UIKit

/// Wizard-steg for time-bånd-prising (kun parkering per time).
/// Brukeren oppretter prisbånd og velger om de gjelder alle uker eller
/// et utvalg spesifikke ISO-uker via multi-select sheet.
struct PriceRulesStep: View {
    enum Phase { case ask, editing }

    @ObservedObject var form: ListingFormModel
    @State private var phase: Phase = .ask
    @State private var showAddBandSheet = false
    @State private var bandSheetPrefill: BandPrefill?
    /// Bånd-id hvis vi viser uke-velger for et eksisterende bånd; nil ellers.
    @State private var weekScopeBandId: UUID?

    private let weeksAhead = 12

    private var basePriceHint: Int {
        form.spotMarkers.first?.price ?? 50
    }

    static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        Group {
            switch phase {
            case .ask: askPhase
            case .editing: editingPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .onAppear {
            if !form.pricingBands.isEmpty { phase = .editing }
        }
        .sheet(isPresented: $showAddBandSheet) {
            AddHourlyBandSheet(
                basePrice: basePriceHint,
                prefill: bandSheetPrefill,
            ) { dayMask, startHour, endHour, price in
                form.pricingBands.append(
                    WizardPricingBand(
                        dayMask: dayMask,
                        startHour: startHour,
                        endHour: endHour,
                        price: price,
                        weekScope: .allWeeks
                    )
                )
            }
        }
        .sheet(item: Binding(
            get: { weekScopeBandId.map { IdentifiedUUID(value: $0) } },
            set: { weekScopeBandId = $0?.value }
        )) { wrap in
            if let idx = form.pricingBands.firstIndex(where: { $0.id == wrap.value }) {
                WeekScopePickerSheet(
                    band: form.pricingBands[idx],
                    weekList: weekList,
                    onSave: { newScope in
                        form.pricingBands[idx].weekScope = newScope
                        weekScopeBandId = nil
                    },
                    onCancel: { weekScopeBandId = nil }
                )
            }
        }
    }

    // MARK: - Ask phase

    private var askPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vil du variere prisen?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Mange tar høyere pris i rushtiden eller helger. Du kan også beholde én fast pris hele uken.")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                askChoiceCard(
                    icon: "checkmark.circle.fill",
                    title: "Nei, fast pris",
                    subtitle: "Bruk samme pris hele uken og hopp videre.",
                    accent: .neutral900
                ) {
                    form.pricingBands.removeAll()
                    form.goNext()
                }

                askChoiceCard(
                    icon: "chart.bar.fill",
                    title: "Ja, varier prisen",
                    subtitle: "Sett ulike priser for tidsbånd og spesifikke uker.",
                    accent: .primary600
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) { phase = .editing }
                }
            }
            .padding(.horizontal, 16)

            Spacer()
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

    // MARK: - Editing phase

    private var editingPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            editingHeader

            ScrollView {
                LazyVStack(spacing: 14) {
                    if !form.pricingBands.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(form.pricingBands) { band in
                                bandCard(band)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    quickAddSection
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
                .padding(.top, 4)
            }
        }
    }

    private var editingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    form.pricingBands.removeAll()
                    phase = .ask
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tilbake til fast pris")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.neutral600)
            }
            .buttonStyle(.plain)

            Text("Sett priser for tidsperioder")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Hvert prisbånd gjelder alle uker som standard. Tap på \"Gjelder\"-teksten på et bånd for å begrense til bestemte uker.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Band card

    private func bandCard(_ band: WizardPricingBand) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primary50)
                        .frame(width: 32, height: 32)
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatBandLabel(band))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("\(band.price) kr/time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral600)
                }
                Spacer()
                Button {
                    form.pricingBands.removeAll { $0.id == band.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.neutral100))
                }
                .buttonStyle(.plain)
            }

            // Scope-pille tap-bart — åpner uke-velger sheet
            Button {
                weekScopeBandId = band.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                    Text(scopeText(band.weekScope))
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.primary700)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary50)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    private func scopeText(_ scope: WeekScope) -> String {
        switch scope {
        case .allWeeks:
            return "Gjelder alle uker"
        case .specificWeeks(let weeks):
            if weeks.isEmpty { return "Gjelder ingen uker" }
            if weeks.count == 1, let w = weeks.first { return "Gjelder uke \(w.weekNum)" }
            let nums = weeks.sorted { $0.weekNum < $1.weekNum }.map { String($0.weekNum) }
            return "Gjelder uke \(nums.joined(separator: ", "))"
        }
    }

    // MARK: - Quick add (hurtigvalg + custom)

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legg til prisbånd")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(BandPrefill.defaults) { prefill in
                    Button {
                        bandSheetPrefill = prefill
                        showAddBandSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prefill.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.neutral900)
                            Text(prefill.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral500)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

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
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.primary50)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func formatBandLabel(_ band: WizardPricingBand) -> String {
        let weekdaysMask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
        let weekendMask = (1 << 5) | (1 << 6)
        let allMask = weekdaysMask | weekendMask
        let mask = band.dayMask
        let dayPart: String
        if mask == allMask { dayPart = "Alle dager" }
        else if mask == weekdaysMask { dayPart = "Hverdager" }
        else if mask == weekendMask { dayPart = "Helg" }
        else {
            let names = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
            dayPart = (0..<7).compactMap { i in (mask & (1 << i)) != 0 ? names[i] : nil }.joined(separator: ", ")
        }
        let sh = String(format: "%02d", band.startHour)
        let eh = String(format: "%02d", band.endHour)
        return "\(dayPart) · \(sh):00–\(eh):00"
    }

    /// Liste av kommende ISO-uker (12 framover), brukt av WeekScopePickerSheet.
    var weekList: [WeekKey] {
        let cal = Self.osloCalendar
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let mondayThisWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        return (0..<weeksAhead).compactMap { offset in
            guard let monday = cal.date(byAdding: .day, value: offset * 7, to: mondayThisWeek) else { return nil }
            let year = cal.component(.yearForWeekOfYear, from: monday)
            let weekNum = cal.component(.weekOfYear, from: monday)
            return WeekKey(year: year, weekNum: weekNum)
        }
    }
}

// MARK: - Helpers (publish + uke-sheet)

extension PriceRulesStep {
    /// ISO-yyyy-MM-dd for mandag/søndag i en gitt ISO-uke. Brukes ved
    /// publisering for å sette start_date/end_date på listing_pricing_rules.
    static func dateRangeForWeek(year: Int, week: Int) -> (start: String, end: String)? {
        let cal = osloCalendar
        var comps = DateComponents()
        comps.weekday = 2
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        guard let monday = cal.date(from: comps),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
        return (isoFormatter.string(from: monday), isoFormatter.string(from: sunday))
    }
}

private struct IdentifiedUUID: Identifiable {
    let value: UUID
    var id: UUID { value }
}

/// Sheet for å velge hvilke uker et bånd gjelder for. Hurtigvalg "Alle uker",
/// "Bare denne uken", "Sommer (uke 26-32)", samt manuell multi-select.
struct WeekScopePickerSheet: View {
    let band: WizardPricingBand
    let weekList: [WeekKey]
    let onSave: (WeekScope) -> Void
    let onCancel: () -> Void

    @State private var allWeeks: Bool = true
    @State private var selectedWeeks: Set<WeekKey> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    quickPicks
                    Divider()
                    weekGrid
                }
                .padding(20)
            }
            .navigationTitle("Velg uker")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { onCancel() }
                        .foregroundStyle(.neutral600)
                }
            }
        }
        .onAppear {
            switch band.weekScope {
            case .allWeeks:
                allWeeks = true
                selectedWeeks = []
            case .specificWeeks(let set):
                allWeeks = false
                selectedWeeks = set
            }
        }
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hurtigvalg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                quickPickRow(label: "Alle uker", isSelected: allWeeks) {
                    allWeeks = true
                    selectedWeeks = []
                }
                quickPickRow(label: "Bare denne uken", isSelected: !allWeeks && selectedWeeks == Set(weekList.prefix(1))) {
                    allWeeks = false
                    selectedWeeks = Set(weekList.prefix(1))
                }
                quickPickRow(label: "Sommer (uke 26-32)", isSelected: !allWeeks && selectedWeeks == summerWeeks) {
                    allWeeks = false
                    selectedWeeks = summerWeeks
                }
            }
        }
    }

    private var summerWeeks: Set<WeekKey> {
        Set(weekList.filter { $0.weekNum >= 26 && $0.weekNum <= 32 })
    }

    private func quickPickRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .primary600 : .neutral300)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private var weekGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Velg uker manuelt")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(weekList) { week in
                    weekCell(week)
                }
            }
        }
    }

    private func weekCell(_ week: WeekKey) -> some View {
        let isSelected = !allWeeks && selectedWeeks.contains(week)
        return Button {
            allWeeks = false
            if selectedWeeks.contains(week) {
                selectedWeeks.remove(week)
            } else {
                selectedWeeks.insert(week)
            }
        } label: {
            VStack(spacing: 2) {
                Text("Uke \(week.weekNum)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .neutral900)
                if let monday = mondayOf(week) {
                    Text(PriceRulesStep.weekRangeFormatter.string(from: monday))
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .neutral500)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.neutral900 : Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func mondayOf(_ week: WeekKey) -> Date? {
        var comps = DateComponents()
        comps.weekday = 2
        comps.weekOfYear = week.weekNum
        comps.yearForWeekOfYear = week.year
        return PriceRulesStep.osloCalendar.date(from: comps)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                if allWeeks {
                    onSave(.allWeeks)
                } else {
                    onSave(.specificWeeks(selectedWeeks))
                }
            } label: {
                Text("Lagre")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? Color.primary600 : Color.neutral400)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    private var canSave: Bool {
        if allWeeks { return true }
        return !selectedWeeks.isEmpty
    }
}
