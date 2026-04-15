import SwiftUI
import UIKit

/// Airbnb-aktig range-kalender bygget rundt UICalendarView.
/// Bruker UICalendarSelectionSingleDate for at blokkerte datoer skal greyes ut
/// visuelt (MultiDate.canSelectDate oppdaterer ikke utseendet). Selve seleksjons-
/// ringen fjernes etter hvert tap — visuell tilbakemelding skjer via dekorasjoner.
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
        let cal = Calendar(identifier: .gregorian)
        let end = cal.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        view.availableDateRange = DateInterval(start: minDate, end: end)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        context.coordinator.singleSelection = selection
        context.coordinator.calendarView = view

        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        // Refresh dekorasjoner når bindings endres utenfra (f.eks. reset)
        uiView.reloadDecorations(forDateComponents: context.coordinator.decorableComponents(), animated: false)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: BookingCalendarView
        weak var calendarView: UICalendarView?
        weak var singleSelection: UICalendarSelectionSingleDate?

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

        /// Datoer som bør oppdateres ved re-dekorering
        func decorableComponents() -> [DateComponents] {
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

        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dc = dateComponents, let date = calendar.date(from: dc) else { return false }
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: parent.minDate) { return false }
            let key = dayFormatter.string(from: date)
            return !parent.blockedDates.contains(key)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dc = dateComponents, let date = calendar.date(from: dc) else { return }
            handleTap(date: date, selection: selection)
            // Nullstill Apple-seleksjonsringen — vi tegner alt selv via dekorasjoner
            DispatchQueue.main.async {
                selection.setSelected(nil, animated: false)
            }
        }

        // MARK: Tap-logikk

        private func handleTap(date: Date, selection: UICalendarSelectionSingleDate) {
            let tapped = calendar.startOfDay(for: date)

            // Første trykk, eller har allerede fullført range: start nytt valg
            if parent.checkIn == nil || parent.checkOut != nil {
                parent.checkIn = tapped
                parent.checkOut = nil
                calendarView?.reloadDecorations(forDateComponents: decorableComponents(), animated: true)
                return
            }

            if let start = parent.checkIn.map({ calendar.startOfDay(for: $0) }) {
                if tapped <= start {
                    parent.checkIn = tapped
                    parent.checkOut = nil
                } else if rangeContainsBlocked(from: start, toLastNight: tapped) {
                    parent.checkIn = tapped
                    parent.checkOut = nil
                } else {
                    // Utsjekk = dagen etter siste natten
                    let checkOutDate = calendar.date(byAdding: .day, value: 1, to: tapped) ?? tapped
                    parent.checkOut = checkOutDate
                }
                calendarView?.reloadDecorations(forDateComponents: decorableComponents(), animated: true)
            }
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

        // MARK: Dekorasjoner (endepunkter + range)

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = calendar.date(from: dateComponents) else { return nil }
            let startOfDay = calendar.startOfDay(for: date)

            guard let ci = parent.checkIn else { return nil }
            let startOfCI = calendar.startOfDay(for: ci)
            let lastNight = parent.checkOut.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            let startOfLast = lastNight.map { calendar.startOfDay(for: $0) }

            let isEndpoint = (startOfDay == startOfCI) || (startOfLast != nil && startOfDay == startOfLast!)
            let isMiddle = startOfLast != nil && startOfDay > startOfCI && startOfDay < startOfLast!

            if isEndpoint {
                return .customView {
                    let dot = UIView()
                    dot.translatesAutoresizingMaskIntoConstraints = false
                    dot.backgroundColor = UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 1)
                    dot.layer.cornerRadius = 4
                    let container = UIView()
                    container.addSubview(dot)
                    NSLayoutConstraint.activate([
                        dot.widthAnchor.constraint(equalToConstant: 8),
                        dot.heightAnchor.constraint(equalToConstant: 8),
                        dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                        dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    ])
                    return container
                }
            }
            if isMiddle {
                return .default(color: UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 0.55), size: .small)
            }
            return nil
        }
    }
}
