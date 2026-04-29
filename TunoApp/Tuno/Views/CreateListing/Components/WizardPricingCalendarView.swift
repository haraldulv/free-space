import SwiftUI

/// Kalender-redigerer for pris-variasjon i wizarden (PriceRulesStep "Ja, varier").
/// Speiler HostCalendarView fra Profil → Kalender, men jobber mot form-state
/// i stedet for DB. Tap-anker for multi-select. Bottom action-bar med "Sett pris"
/// + "Fjern overstyring".
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel

    @State private var selectedDates: Set<String> = []
    @State private var rangeAnchor: String?
    @State private var showPriceSheet = false
    @State private var anchorPulse = false

    private let monthsAhead = 12

    private var basePrice: Int {
        form.spotMarkers.first.flatMap {
            $0.pricePerHour ?? $0.pricePerNight ?? $0.price
        } ?? 0
    }

    private var unitLabel: String {
        let s = form.spotMarkers.first
        if (s?.pricePerHour ?? 0) > 0 { return "kr/time" }
        return "kr/døgn"
    }

    private var overrides: [String: Int] {
        Dictionary(uniqueKeysWithValues: form.listingDateOverrides.map { ($0.date, $0.price) })
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        return cal
    }

    private var visibleMonthList: [Date] {
        let cal = Self.osloCalendar
        let now = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let firstOfMonth = cal.date(from: comps) else { return [] }
        return (0..<monthsAhead).compactMap { offset in
            cal.date(byAdding: .month, value: offset, to: firstOfMonth)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerHint
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    ForEach(visibleMonthList, id: \.self) { monthStart in
                        monthSection(monthStart)
                    }
                }
                .padding(.bottom, selectedDates.isEmpty ? 20 : 160)
            }

            if !selectedDates.isEmpty {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDates.isEmpty)
        .sheet(isPresented: $showPriceSheet) {
            WizardPriceSheet(
                basePrice: basePrice,
                unitLabel: unitLabel,
                selectedCount: selectedDates.count,
                onSave: { newPrice in
                    applyPriceOverride(newPrice)
                    showPriceSheet = false
                }
            )
            .presentationDetents([.fraction(0.35)])
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                anchorPulse.toggle()
            }
        }
    }

    // MARK: - Header

    private var headerHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.primary600)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("Standardpris \(basePrice) \(unitLabel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Tap én dag for å starte, tap en annen for å markere et område. Sett pris for valgte datoer.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Month section

    private func monthSection(_ monthStart: Date) -> some View {
        let cal = Self.osloCalendar
        let title = Self.monthNameFormatter.string(from: monthStart).capitalized
        let weekdays = ["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"]
        let firstWeekdayBit = (cal.component(.weekday, from: monthStart) + 5) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 16)

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<(firstWeekdayBit + daysInMonth), id: \.self) { idx in
                    if idx < firstWeekdayBit {
                        Color.clear.frame(height: 50)
                    } else {
                        let day = idx - firstWeekdayBit + 1
                        if let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                            dayCell(date)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let iso = Self.isoFormatter.string(from: date)
        let isSelected = selectedDates.contains(iso)
        let isAnchor = rangeAnchor == iso
        let override = overrides[iso]
        let priceShown = override ?? basePrice
        let isOverride = override != nil

        return Button {
            handleTap(iso: iso)
        } label: {
            VStack(spacing: 2) {
                Text("\(Self.osloCalendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : .neutral900)
                Text("\(priceShown)")
                    .font(.system(size: 10, weight: isOverride ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isOverride ? Color(hex: "#10b981") : .neutral500))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(cellBackground(isSelected: isSelected, isAnchor: isAnchor, isOverride: isOverride))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isAnchor ? Color.primary600 : Color.clear, lineWidth: isAnchor ? 2 : 0)
                    .scaleEffect(isAnchor && anchorPulse ? 1.04 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func cellBackground(isSelected: Bool, isAnchor: Bool, isOverride: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isSelected { return Color.primary600.opacity(0.85) }
        if isOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    // MARK: - Tap handling

    private func handleTap(iso: String) {
        if let anchor = rangeAnchor {
            // Anker er satt: fyll range fra anker til iso.
            let range = isoRange(from: anchor, to: iso)
            for d in range { selectedDates.insert(d) }
            rangeAnchor = nil
        } else {
            if selectedDates.contains(iso) {
                selectedDates.remove(iso)
                if selectedDates.isEmpty { rangeAnchor = nil }
            } else {
                selectedDates.insert(iso)
                rangeAnchor = iso
            }
        }
    }

    private func isoRange(from start: String, to end: String) -> [String] {
        let lo = min(start, end)
        let hi = max(start, end)
        guard let loDate = Self.isoFormatter.date(from: lo),
              let hiDate = Self.isoFormatter.date(from: hi) else { return [start, end] }
        let cal = Self.osloCalendar
        var result: [String] = []
        var cursor = loDate
        while cursor <= hiDate {
            result.append(Self.isoFormatter.string(from: cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(selectedDates.count) \(selectedDates.count == 1 ? "dag" : "dager") valgt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Button("Tøm") {
                    selectedDates.removeAll()
                    rangeAnchor = nil
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary600)
            }

            HStack(spacing: 10) {
                Button {
                    showPriceSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 13))
                        Text("Sett pris")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    clearOverrides()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13))
                        Text("Fjern overst.")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.neutral700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(Rectangle().fill(Color.neutral200).frame(height: 1), alignment: .top)
        .shadow(color: .black.opacity(0.06), radius: 10, y: -4)
    }

    // MARK: - Apply

    private func applyPriceOverride(_ price: Int) {
        for date in selectedDates {
            if let idx = form.listingDateOverrides.firstIndex(where: { $0.date == date }) {
                form.listingDateOverrides[idx].price = price
            } else {
                form.listingDateOverrides.append(WizardDateOverride(date: date, price: price))
            }
        }
        selectedDates.removeAll()
        rangeAnchor = nil
    }

    private func clearOverrides() {
        for date in selectedDates {
            form.listingDateOverrides.removeAll { $0.date == date }
        }
        selectedDates.removeAll()
        rangeAnchor = nil
    }
}

/// Pris-sheet for å sette pris på valgte datoer i wizard-kalenderen.
struct WizardPriceSheet: View {
    let basePrice: Int
    let unitLabel: String
    let selectedCount: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var price: Int = 0
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sett pris for \(selectedCount) \(selectedCount == 1 ? "dag" : "dager")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Standardpris er \(basePrice) \(unitLabel). Sett en annen pris for de valgte datoene.")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }

                HStack(spacing: 10) {
                    TextField("\(basePrice)", text: $text)
                        .focused($isFocused)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary600)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(unitLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") {
                        if let p = Int(text), p > 0 {
                            onSave(p)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled((Int(text) ?? 0) <= 0)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
