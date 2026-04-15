import SwiftUI
import UIKit

/// Airbnb-aktig range-kalender bygget rundt UICalendarView.
/// Første trykk velger innsjekk (nullstiller utsjekk), andre trykk velger utsjekk.
/// Trykk på dato før innsjekk nullstiller og starter på nytt.
/// Bookede og listing-blokkerte datoer er ikke-velgbare og vises greyed ut.
struct BookingCalendarView: UIViewRepresentable {
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    let blockedDates: Set<String>
    let minDate: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar(identifier: .gregorian)
        view.locale = Locale(identifier: "nb")
        view.tintColor = UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 1) // #46C185
        view.availableDateRange = DateInterval(start: minDate, end: Date().addingTimeInterval(60 * 60 * 24 * 365 * 2))
        view.fontDesign = .default

        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        context.coordinator.multiSelection = selection
        context.coordinator.calendarView = view
        context.coordinator.applyCurrentSelection()

        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyCurrentSelection()
        // Re-oppdater dekorasjoner (range-highlighting) når bindings endres utenfra
        uiView.reloadDecorations(forDateComponents: context.coordinator.visibleMonthComponents(), animated: false)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionMultiDateDelegate {
        var parent: BookingCalendarView
        weak var calendarView: UICalendarView?
        weak var multiSelection: UICalendarSelectionMultiDate?

        private let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }()

        private var calendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC") ?? .current
            return cal
        }

        init(parent: BookingCalendarView) {
            self.parent = parent
        }

        func applyCurrentSelection() {
            guard let selection = multiSelection else { return }
            var components: [DateComponents] = []
            if let ci = parent.checkIn {
                components.append(calendar.dateComponents([.year, .month, .day], from: ci))
            }
            if let co = parent.checkOut {
                // Utsjekk-datoen regnes som den siste natten som er inkludert — vi viser dagen FØR check-out som sluttpunkt
                if let last = calendar.date(byAdding: .day, value: -1, to: co) {
                    components.append(calendar.dateComponents([.year, .month, .day], from: last))
                }
            }
            let current = selection.selectedDates.map { dc -> String in
                let date = calendar.date(from: dc) ?? Date()
                return dayFormatter.string(from: date)
            }.sorted()
            let next = components.map { dc -> String in
                let date = calendar.date(from: dc) ?? Date()
                return dayFormatter.string(from: date)
            }.sorted()
            if current != next {
                selection.setSelectedDates(components, animated: true)
            }
        }

        func visibleMonthComponents() -> [DateComponents] {
            // Re-dekorer en bred fremtid så range-highlighting er i sync
            var out: [DateComponents] = []
            let now = Date()
            for monthOffset in -1...13 {
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }
                let comps = calendar.dateComponents([.year, .month], from: monthStart)
                guard let firstOfMonth = calendar.date(from: comps),
                      let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { continue }
                for day in range {
                    if let d = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                        out.append(calendar.dateComponents([.year, .month, .day], from: d))
                    }
                }
            }
            return out
        }

        // MARK: Delegate — disable blokkerte datoer

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let ci = parent.checkIn, let co = parent.checkOut else { return nil }
            guard let date = calendar.date(from: dateComponents) else { return nil }
            // Hvis datoen ligger STRIKT mellom innsjekk og utsjekk-1 — vis en liten prikk
            let startOfCI = calendar.startOfDay(for: ci)
            let lastNight = calendar.date(byAdding: .day, value: -1, to: co) ?? co
            let startOfLast = calendar.startOfDay(for: lastNight)
            if date > startOfCI && date < startOfLast {
                return .default(color: UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 1), size: .small)
            }
            return nil
        }

        // MARK: Multi-date selection delegate

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canSelectDate dateComponents: DateComponents) -> Bool {
            guard let date = calendar.date(from: dateComponents) else { return false }
            // Ikke tillat datoer før minDate
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: parent.minDate) { return false }
            // Ikke tillat blokkerte datoer
            let key = dayFormatter.string(from: date)
            return !parent.blockedDates.contains(key)
        }

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
            true
        }

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
            guard let date = calendar.date(from: dateComponents) else { return }
            handleTap(date: date, selection: selection)
        }

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
            guard let date = calendar.date(from: dateComponents) else { return }
            handleTap(date: date, selection: selection)
        }

        private func handleTap(date: Date, selection: UICalendarSelectionMultiDate) {
            let tapped = calendar.startOfDay(for: date)
            let ci = parent.checkIn.map { calendar.startOfDay(for: $0) }

            // Første trykk, eller har allerede fullført range: start nytt valg
            if parent.checkIn == nil || parent.checkOut != nil {
                parent.checkIn = tapped
                parent.checkOut = nil
                syncSelection(for: tapped, to: nil, on: selection)
                return
            }

            // Har kun innsjekk — velg utsjekk eller flytt innsjekk
            if let start = ci {
                if tapped <= start {
                    // Flytt innsjekk
                    parent.checkIn = tapped
                    parent.checkOut = nil
                    syncSelection(for: tapped, to: nil, on: selection)
                } else {
                    // Sjekk at det ikke er blokkerte datoer MELLOM innsjekk og tapped
                    if rangeContainsBlocked(from: start, toLastNight: tapped) {
                        // Ikke tillat, flytt innsjekk til tapped
                        parent.checkIn = tapped
                        parent.checkOut = nil
                        syncSelection(for: tapped, to: nil, on: selection)
                        return
                    }
                    // Utsjekk = dagen etter siste natten
                    let checkOutDate = calendar.date(byAdding: .day, value: 1, to: tapped) ?? tapped
                    parent.checkOut = checkOutDate
                    syncSelection(for: start, to: tapped, on: selection)
                }
            }
            calendarView?.reloadDecorations(forDateComponents: visibleMonthComponents(), animated: true)
        }

        private func rangeContainsBlocked(from start: Date, toLastNight lastNight: Date) -> Bool {
            var cursor = start
            while cursor <= lastNight {
                let key = dayFormatter.string(from: cursor)
                if parent.blockedDates.contains(key) { return true }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return false
        }

        private func syncSelection(for checkIn: Date, to lastNight: Date?, on selection: UICalendarSelectionMultiDate) {
            var components: [DateComponents] = [calendar.dateComponents([.year, .month, .day], from: checkIn)]
            if let last = lastNight {
                components.append(calendar.dateComponents([.year, .month, .day], from: last))
            }
            selection.setSelectedDates(components, animated: true)
        }
    }
}
