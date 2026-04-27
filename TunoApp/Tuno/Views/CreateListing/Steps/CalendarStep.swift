import SwiftUI
import UIKit

/// Forenklet kalender-steg for wizarden — siden listing'en ikke er lagret enda,
/// hånderer vi bare blokkering på listing-nivå (ikke per-plass, ikke pricing-rules,
/// ingen booked-datoer). Per-plass og pricing-rules kan settes etter publisering.
///
/// **Camping**: tap én dag = blokkér hele dagen. Tap to dager = blokkér rekkevidden.
/// **Parkering**: tap én dag åpner et time-grid under kalenderen. Quick-actions for
/// vanlige mønstre (hele dag, natt, arbeidstid).
struct CalendarStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var rangeAnchor: String?
    @State private var anchorPulse = false
    /// Dato som er valgt for time-redigering (kun parkering).
    @State private var selectedDateForHours: String?

    private var isParking: Bool { form.category == .parking }

    private let monthsAhead = 12

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

    private static let prettyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d. MMMM"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            statusBar

            ScrollView {
                LazyVStack(spacing: 22) {
                    ForEach(visibleMonthList, id: \.self) { monthStart in
                        monthSection(monthStart)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                anchorPulse.toggle()
            }
        }
        .sheet(item: Binding(
            get: { selectedDateForHours.map { IdentifiedDate(value: $0) } },
            set: { selectedDateForHours = $0?.value }
        )) { wrapper in
            HoursPickerSheet(
                form: form,
                date: wrapper.value,
                onClose: { selectedDateForHours = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Når er plassene dine ledige?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text(isParking
                 ? "Tap en dag for å blokkere timer. Tap to dager for å blokkere hele rekkevidden."
                 : "Tap på datoer du IKKE vil leie ut. Du kan endre dette når som helst etter publisering.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 12, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(form.blockedDates.isEmpty ? .neutral600 : .primary700)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(form.blockedDates.isEmpty ? Color.neutral100 : Color.primary50)
            .clipShape(Capsule())

            Spacer()

            if !form.blockedDates.isEmpty {
                Button {
                    withAnimation { form.blockedDates.removeAll() }
                } label: {
                    Text("Nullstill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral600)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.neutral100)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var statusText: String {
        if form.blockedDates.isEmpty {
            return isParking ? "Alle timer åpne" : "Alle datoer åpne"
        }
        let fullDays = form.blockedDates.filter { $0.count == 10 }.count
        let hours = form.blockedDates.filter { $0.count == 13 }.count
        if hours == 0 {
            return "\(fullDays) dag\(fullDays == 1 ? "" : "er") blokkert"
        }
        if fullDays == 0 {
            return "\(hours) time\(hours == 1 ? "" : "r") blokkert"
        }
        return "\(fullDays) dag\(fullDays == 1 ? "" : "er") + \(hours) time\(hours == 1 ? "" : "r")"
    }

    // MARK: - Måneds-liste

    private var visibleMonthList: [Date] {
        let cal = Self.osloCalendar
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return (0..<monthsAhead).compactMap { offset in
            cal.date(byAdding: .month, value: offset, to: startOfMonth)
        }
    }

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(Self.monthNameFormatter.string(from: monthStart).capitalized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.neutral900)
                Spacer()
            }
            .padding(.horizontal, 24)

            HStack(spacing: 0) {
                ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            let days = daysInMonthGrid(monthStart)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let iso = Self.isoFormatter.string(from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday
        let isFullDay = form.blockedDates.isFullDayBlocked(iso)
        let blockedHours = form.blockedDates.blockedHours(on: iso)
        let hasPartial = !isFullDay && !blockedHours.isEmpty
        let isAnchor = rangeAnchor == iso
        let dayNumber = Self.osloCalendar.component(.day, from: date)

        Button {
            handleTap(iso: iso)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(isPast: isPast, isFullDay: isFullDay, hasPartial: hasPartial, isAnchor: isAnchor))

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isAnchor ? Color.primary600 : Color.clear, lineWidth: isAnchor ? 2.5 : 0)

                VStack(spacing: 2) {
                    Text("\(dayNumber)")
                        .font(.system(size: 14, weight: isFullDay || isAnchor ? .bold : .medium))
                        .foregroundStyle(textColor(isPast: isPast, isFullDay: isFullDay))
                    if isFullDay {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.neutral500)
                    } else if hasPartial {
                        Text("\(blockedHours.count)t")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.primary700)
                    }
                }
            }
            .frame(height: 44)
            .scaleEffect(isAnchor && anchorPulse ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func cellBackground(isPast: Bool, isFullDay: Bool, hasPartial: Bool, isAnchor: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.22) }
        if isFullDay { return Color.neutral200 }
        if hasPartial { return Color.primary50 }
        if isPast { return Color.clear }
        return Color.neutral50
    }

    private func textColor(isPast: Bool, isFullDay: Bool) -> Color {
        if isPast { return .neutral300 }
        if isFullDay { return .neutral500 }
        return .neutral900
    }

    private func handleTap(iso: String) {
        // Parkering: tap → åpne time-velger sheet (med mindre vi er i range-modus)
        if isParking && rangeAnchor == nil {
            selectedDateForHours = iso
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        // Camping (eller andre tap i range-modus for parkering): toggle hele dagen / range
        if let anchor = rangeAnchor {
            if anchor == iso {
                form.blockedDates.toggleFullDay(iso)
                rangeAnchor = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                let range = isoRange(from: anchor, to: iso)
                withAnimation(.easeInOut(duration: 0.18)) {
                    for d in range { form.blockedDates.insert(d) }
                    rangeAnchor = nil
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            if form.blockedDates.contains(iso) {
                form.blockedDates.toggleFullDay(iso)
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    form.blockedDates.toggleFullDay(iso)
                    rangeAnchor = iso
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func isoRange(from a: String, to b: String) -> [String] {
        guard let dateA = Self.isoFormatter.date(from: a),
              let dateB = Self.isoFormatter.date(from: b) else { return [] }
        let (start, end) = dateA < dateB ? (dateA, dateB) : (dateB, dateA)
        let cal = Self.osloCalendar
        var cursor = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        var result: [String] = []
        while cursor <= last {
            result.append(Self.isoFormatter.string(from: cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func daysInMonthGrid(_ monthStart: Date) -> [Date?] {
        let cal = Self.osloCalendar
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let dayCount = range.count

        let firstWeekday = cal.component(.weekday, from: monthStart)
        // Mandag = 2 i Gregorian → konverter slik at mandag = 0
        let leadingBlanks = (firstWeekday + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for d in 1...dayCount {
            if let day = cal.date(byAdding: .day, value: d - 1, to: monthStart) {
                result.append(day)
            }
        }
        return result
    }
}

private struct IdentifiedDate: Identifiable {
    let value: String
    var id: String { value }
}

/// Sheet for å redigere blokkerte timer på én dato (kun parkering).
private struct HoursPickerSheet: View {
    @ObservedObject var form: ListingFormModel
    let date: String
    let onClose: () -> Void

    private static let prettyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d. MMMM"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var prettyDate: String {
        if let d = Self.isoFormatter.date(from: date) {
            return Self.prettyFormatter.string(from: d).capitalized
        }
        return date
    }

    private var blockedHours: Set<Int> { form.blockedDates.blockedHours(on: date) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    quickActions
                    Divider()
                    hoursGrid
                }
                .padding(20)
            }
            .navigationTitle(prettyDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { onClose() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hurtigvalg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)

            FlowLayout(spacing: 8) {
                quickButton("Hele dagen", systemImage: "moon.fill") {
                    form.blockedDates.toggleFullDay(date)
                    onClose()
                }
                quickButton("Natt (22-06)", systemImage: "moon.stars.fill") {
                    form.blockedDates.blockHourRange(date: date, from: 22, through: 23)
                    form.blockedDates.blockHourRange(date: date, from: 0, through: 5)
                }
                quickButton("Arbeidstid (08-17)", systemImage: "briefcase.fill") {
                    form.blockedDates.blockHourRange(date: date, from: 8, through: 16)
                }
                quickButton("Tøm dag", systemImage: "trash") {
                    form.blockedDates.clearDate(date)
                }
            }
        }
    }

    private func quickButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 12))
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.neutral700)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.neutral100)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var hoursGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                ForEach(0..<24, id: \.self) { hour in
                    hourCell(hour: hour)
                }
            }
        }
    }

    private func hourCell(hour: Int) -> some View {
        let isBlocked = blockedHours.contains(hour)
        return Button {
            form.blockedDates.toggleHour(date: date, hour: hour)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 13, weight: isBlocked ? .bold : .medium))
                .foregroundStyle(isBlocked ? .neutral500 : .neutral900)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isBlocked ? Color.neutral200 : Color.neutral50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isBlocked ? Color.clear : Color.neutral200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
