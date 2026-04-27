import SwiftUI

/// Per-plass-blokkering av datoer. Brukes i EditListingView for å la utleier
/// markere datoer hvor en spesifikk plass ikke er tilgjengelig (f.eks. mens
/// hele anlegget er åpent).
struct SpotBlockedDatesSection: View {
    let spotId: String
    @Binding var blockedDates: [String]
    @State private var expanded = false
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                    Text("Blokkerte datoer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral700)
                    if !blockedDates.isEmpty {
                        Text("(\(blockedDates.count))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#dc2626"))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral400)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                HStack {
                    Button { moveMonth(-1) } label: {
                        Image(systemName: "chevron.left").foregroundStyle(.neutral600)
                    }
                    Spacer()
                    Text(monthFormatter.string(from: displayedMonth).capitalized)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { moveMonth(1) } label: {
                        Image(systemName: "chevron.right").foregroundStyle(.neutral600)
                    }
                }

                let weekdays = ["Ma", "Ti", "On", "To", "Fr", "Lo", "So"]
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.neutral500)
                            .frame(maxWidth: .infinity)
                    }
                }

                let days = daysInMonth()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let dateStr = TunoCalendar.dateKey(day)
                            let isBlocked = blockedDates.contains(dateStr)
                            let isPast = day < calendar.startOfDay(for: Date())
                            Button {
                                guard !isPast else { return }
                                if isBlocked {
                                    blockedDates.removeAll { $0 == dateStr }
                                } else {
                                    blockedDates.append(dateStr)
                                }
                            } label: {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.system(size: 12, weight: isBlocked ? .bold : .regular))
                                    .foregroundStyle(isPast ? Color.neutral300 : isBlocked ? Color(hex: "#dc2626") : Color.neutral800)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 30)
                                    .background(isBlocked ? Color(hex: "#fee2e2") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .disabled(isPast)
                        } else {
                            Color.clear.frame(height: 30)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func moveMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}
