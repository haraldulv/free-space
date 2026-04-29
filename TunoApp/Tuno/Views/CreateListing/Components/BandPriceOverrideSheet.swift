import SwiftUI

/// Sheet for å sette pris på en bånd-okkurrens. Brukeren får velge scope:
/// "Bare denne uken", "Alle uker", eller "Velg uker..." (åpner WeekScopePickerSheet).
struct BandPriceOverrideSheet: View {
    let band: WizardPricingBand
    let weekKey: WeekKey
    let basePerHour: Int
    let currentPrice: Int
    let allWeeks: Bool
    let onSave: (Int, WeekScope) -> Void
    let onCancel: () -> Void

    @State private var priceText: String = ""
    @State private var scope: ScopeChoice = .thisWeek
    @State private var customWeeks: Set<WeekKey> = []
    @State private var showCustomPicker = false
    @FocusState private var priceFocused: Bool

    enum ScopeChoice: Hashable {
        case thisWeek
        case allWeeks
        case custom
    }

    private let dayNames = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]

    private var canSave: Bool {
        guard let p = Int(priceText), p > 0 else { return false }
        if scope == .custom, customWeeks.isEmpty { return false }
        return true
    }

    private var weekScope: WeekScope {
        switch scope {
        case .thisWeek: return .specificWeeks([weekKey])
        case .allWeeks: return .allWeeks
        case .custom: return .specificWeeks(customWeeks)
        }
    }

    private var bandLabel: String {
        let mask = band.dayMask
        let selected = (0..<7).filter { (mask & (1 << $0)) != 0 }
        let dayLabel: String
        if selected == [0, 1, 2, 3, 4] { dayLabel = "Hverdager" }
        else if selected == [5, 6] { dayLabel = "Helg" }
        else if selected == [0, 1, 2, 3, 4, 5, 6] { dayLabel = "Alle dager" }
        else { dayLabel = selected.map { dayNames[$0] }.joined(separator: ", ") }
        let sh = String(format: "%02d", band.startHour)
        let eh = String(format: "%02d", band.endHour)
        return "\(dayLabel) \(sh):00–\(eh):00"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    priceSection
                    scopeSection
                }
                .padding(16)
            }
            .navigationTitle("Sett pris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") {
                        if let p = Int(priceText) {
                            onSave(p, weekScope)
                        }
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCustomPicker) {
                CustomWeeksSheet(
                    initialSelection: customWeeks.union(scope == .thisWeek ? [weekKey] : []),
                    onSave: { selected in
                        customWeeks = selected
                        scope = .custom
                        showCustomPicker = false
                    },
                    onCancel: { showCustomPicker = false }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            priceText = "\(currentPrice)"
            scope = allWeeks ? .allWeeks : .thisWeek
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bandLabel)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Standardpris er \(basePerHour) kr/time. Sett en annen pris for valgte uker.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pris")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            HStack(spacing: 10) {
                TextField("\(basePerHour)", text: $priceText)
                    .focused($priceFocused)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary600)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 160)
                    .background(Color.primary50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("kr/time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Spacer()
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gjelder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            VStack(spacing: 8) {
                scopeRow(
                    choice: .thisWeek,
                    title: "Bare uke \(weekKey.weekNum)",
                    subtitle: "Gjelder kun denne ene uken"
                )
                scopeRow(
                    choice: .allWeeks,
                    title: "Alle uker",
                    subtitle: "Bruk denne prisen hver uke fremover"
                )
                scopeRow(
                    choice: .custom,
                    title: customWeeks.isEmpty ? "Velg uker..." : "Valgte uker (\(customWeeks.count))",
                    subtitle: "Sommer-uker, høysesong, eller andre perioder"
                )
            }
        }
    }

    private func scopeRow(choice: ScopeChoice, title: String, subtitle: String) -> some View {
        let selected = scope == choice
        return Button {
            if choice == .custom {
                showCustomPicker = true
            } else {
                scope = choice
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(selected ? Color.primary600 : Color.neutral300, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(Color.primary600)
                            .frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                if choice == .custom {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral400)
                }
            }
            .padding(12)
            .background(selected ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.primary600 : Color.neutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Multi-select uke-velger (gjenbrukbar fra HostCalendarView-logikken).
private struct CustomWeeksSheet: View {
    let initialSelection: Set<WeekKey>
    let onSave: (Set<WeekKey>) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<WeekKey> = []

    private let weeksAhead = 26

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    private var weekList: [(key: WeekKey, label: String)] {
        let cal = Self.osloCalendar
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let mondayThisWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        return (0..<weeksAhead).compactMap { offset in
            guard let monday = cal.date(byAdding: .day, value: offset * 7, to: mondayThisWeek),
                  let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
            let year = cal.component(.yearForWeekOfYear, from: monday)
            let weekNum = cal.component(.weekOfYear, from: monday)
            let label = "\(Self.weekRangeFormatter.string(from: monday))–\(Self.weekRangeFormatter.string(from: sunday))"
            return (WeekKey(year: year, weekNum: weekNum), label)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    quickPicks
                    Divider()
                    weekGrid
                }
                .padding(16)
            }
            .navigationTitle("Velg uker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") { onSave(selected) }
                        .disabled(selected.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selected = initialSelection
        }
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hurtigvalg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
            HStack(spacing: 8) {
                quickPickButton("Sommer 26-32") {
                    let cal = Self.osloCalendar
                    let year = cal.component(.yearForWeekOfYear, from: Date())
                    selected = Set((26...32).map { WeekKey(year: year, weekNum: $0) })
                }
                quickPickButton("Tøm alle") {
                    selected.removeAll()
                }
            }
        }
    }

    private func quickPickButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary700)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary50)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var weekGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(weekList, id: \.key.id) { item in
                weekCell(key: item.key, label: item.label)
            }
        }
    }

    private func weekCell(key: WeekKey, label: String) -> some View {
        let isSelected = selected.contains(key)
        return Button {
            if isSelected { selected.remove(key) } else { selected.insert(key) }
        } label: {
            VStack(spacing: 2) {
                Text("Uke \(key.weekNum)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .neutral900)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .neutral500)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.primary600 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
