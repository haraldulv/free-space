import SwiftUI

/// Range-kalender for søket. Pure SwiftUI — bygget på samme tap-anker-pattern
/// som SpotCalendarEditor men strippet til kun checkIn/checkOut-seleksjon.
///
/// Ingen blokkering, ingen prisvisning, ingen åpningstid. 12 måneder fremover,
/// mandag-først, kompakt celle-høyde tilpasset søkesheeten.
struct SearchDateRangePicker: View {
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    /// ISO-dato-strenger (yyyy-MM-dd) som er utilgjengelige — tegnes greyet ut
    /// med X-overlay og er ikke tappbare. Brukes i BookingView for å vise
    /// blokkerte/opptatte dager fra `listing.blockedDates`.
    var blockedDates: Set<String> = []

    private let monthsAhead = 12
    private let cellHeight: CGFloat = 38
    private let cellSpacing: CGFloat = 3

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Oslo")
        return f
    }()

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = Locale(identifier: "nb_NO")
        return f
    }()

    private var visibleMonths: [Date] {
        let cal = Self.osloCalendar
        let now = Date()
        guard let start = cal.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<monthsAhead).compactMap {
            cal.date(byAdding: .month, value: $0, to: start)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
                .padding(.bottom, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(visibleMonths, id: \.self) { month in
                        monthSection(month)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: cellSpacing) {
            ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.monthNameFormatter.string(from: month).capitalized)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.leading, 4)

            VStack(spacing: cellSpacing) {
                ForEach(weeksIn(month: month), id: \.first) { week in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { i in
                            if i < week.count, let date = week[i] {
                                dayCell(date: date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }

    private func weeksIn(month: Date) -> [[Date?]] {
        let cal = Self.osloCalendar
        guard
            let interval = cal.dateInterval(of: .month, for: month),
            let firstDayWeekday = cal.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }
        // Mandag-først: kalkuler offset slik at Mandag = 0.
        let firstWeekdayIndex = (firstDayWeekday + 5) % 7
        let dayCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: firstWeekdayIndex)
        for d in 0..<dayCount {
            if let date = cal.date(byAdding: .day, value: d, to: interval.start) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        var weeks: [[Date?]] = []
        for chunk in stride(from: 0, to: cells.count, by: 7) {
            weeks.append(Array(cells[chunk..<min(chunk + 7, cells.count)]))
        }
        return weeks
    }

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let cal = Self.osloCalendar
        let day = cal.component(.day, from: date)
        let startOfToday = cal.startOfDay(for: Date())
        let dayStart = cal.startOfDay(for: date)
        let isPast = dayStart < startOfToday
        let isBlocked = blockedDates.contains(Self.isoFormatter.string(from: dayStart))

        let inRange = isInRange(date)
        let isStart = isSameDay(date, checkIn)
        let isEnd = isSameDay(date, checkOut)

        Button {
            handleTap(date)
        } label: {
            ZStack {
                // Range-fyll bak (til venstre/høyre for endepunkt-sirkel) — lett grønn
                if inRange && !isStart && !isEnd && !isBlocked {
                    Rectangle()
                        .fill(Color.primary50)
                }
                // Endepunkt-bakgrunn — Tuno-grønn sirkel
                if (isStart || isEnd) && !isBlocked {
                    Circle()
                        .fill(Color.primary600)
                        .padding(2)
                }
                Text("\(day)")
                    .font(.system(size: 14, weight: (isStart || isEnd) ? .bold : .medium))
                    .foregroundStyle(textColor(isPast: isPast, isBlocked: isBlocked, isEndpoint: isStart || isEnd, inRange: inRange))
                    .strikethrough(isBlocked, color: Color.neutral400)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
        .disabled(isPast || isBlocked)
    }

    private func textColor(isPast: Bool, isBlocked: Bool, isEndpoint: Bool, inRange: Bool) -> Color {
        if isPast { return Color.neutral300 }
        if isBlocked { return Color.neutral400 }
        if isEndpoint { return .white }
        if inRange { return Color.primary700 }
        return Color.neutral900
    }

    // MARK: - Range logic

    private func isSameDay(_ a: Date, _ b: Date?) -> Bool {
        guard let b else { return false }
        return Self.osloCalendar.isDate(a, inSameDayAs: b)
    }

    private func isInRange(_ date: Date) -> Bool {
        guard let ci = checkIn, let co = checkOut else { return false }
        let d = Self.osloCalendar.startOfDay(for: date)
        let s = Self.osloCalendar.startOfDay(for: ci)
        let e = Self.osloCalendar.startOfDay(for: co)
        return d >= s && d <= e
    }

    private func handleTap(_ date: Date) {
        let cal = Self.osloCalendar
        let tapped = cal.startOfDay(for: date)
        // Sikkerhetsbelte — .disabled(isBlocked) i dayCell skal hindre tap,
        // men eksterne kall (gesture-bridging osv.) kan likevel havne her.
        if blockedDates.contains(Self.isoFormatter.string(from: tapped)) { return }

        if checkIn == nil {
            checkIn = tapped
            return
        }
        if let ci = checkIn, checkOut == nil {
            let s = cal.startOfDay(for: ci)
            if tapped > s {
                checkOut = tapped
            } else if tapped == s {
                // Tap samme dag → behold (1-dags booking-intensjon, men søk
                // krever to datoer, så vi lar Utsjekk være tom).
            } else {
                // Tap tidligere → ny anchor.
                checkIn = tapped
            }
            return
        }
        // Begge satt — utvide ranget istedenfor å resette.
        // Tap etter checkOut → flytt checkOut frem til tapped.
        // Tap før checkIn → flytt checkIn tilbake til tapped.
        // Tap inne i ranget → start nytt range fra den dagen (ny anchor).
        if let ci = checkIn, let co = checkOut {
            let s = cal.startOfDay(for: ci)
            let e = cal.startOfDay(for: co)
            if tapped > e {
                checkOut = tapped
            } else if tapped < s {
                checkIn = tapped
            } else {
                checkIn = tapped
                checkOut = nil
            }
        }
    }
}
