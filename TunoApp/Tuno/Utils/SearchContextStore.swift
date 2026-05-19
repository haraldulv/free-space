import Foundation
import SwiftUI

/// Holder valgte søke-parametere på tvers av navigasjon. Persisteres i
/// UserDefaults så søket gjenoppstår etter app-restart eller når bruker
/// går tilbake til forsiden.
///
/// State som BookingView trenger (datoer) leses også herfra slik at
/// pre-fill ikke trenger duplikat input.
@MainActor
final class SearchContextStore: ObservableObject {
    static let shared = SearchContextStore()

    @Published var category: String? { didSet { persist() } }
    @Published var query: String { didSet { persist() } }
    @Published var checkIn: Date? { didSet { persist() } }
    @Published var checkOut: Date? { didSet { persist() } }
    @Published var placeName: String? { didSet { persist() } }
    @Published var placeLat: Double? { didSet { persist() } }
    @Published var placeLng: Double? { didSet { persist() } }
    @Published var bookingPref: String { didSet { persist() } }
    @Published var vehicles: [String] { didSet { persist() } }

    private let key = "tuno.searchContext"

    private init() {
        let d = UserDefaults.standard
        self.category = d.string(forKey: "\(key).category")
        self.query = d.string(forKey: "\(key).query") ?? ""
        // Innsjekk default-er til today når det ikke er noen lagret dato,
        // eller når den lagrede er i fortiden (kalenderen blokkerer fortid
        // og booking gir ikke mening). Utsjekk droppes til nil hvis forbi
        // eller ≤ checkIn — brukeren fyller inn den selv.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let storedIn = d.object(forKey: "\(key).checkIn") as? Date
        let storedOut = d.object(forKey: "\(key).checkOut") as? Date
        let resolvedIn: Date = {
            if let s = storedIn, cal.startOfDay(for: s) >= today { return s }
            return today
        }()
        self.checkIn = resolvedIn
        if let s = storedOut, cal.startOfDay(for: s) > cal.startOfDay(for: resolvedIn) {
            self.checkOut = s
        } else {
            self.checkOut = nil
        }
        self.placeName = d.string(forKey: "\(key).placeName")
        self.placeLat = (d.object(forKey: "\(key).placeLat") as? NSNumber)?.doubleValue
        self.placeLng = (d.object(forKey: "\(key).placeLng") as? NSNumber)?.doubleValue
        self.bookingPref = d.string(forKey: "\(key).bookingPref") ?? "all"
        self.vehicles = d.stringArray(forKey: "\(key).vehicles") ?? []
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(category, forKey: "\(key).category")
        d.set(query, forKey: "\(key).query")
        d.set(checkIn, forKey: "\(key).checkIn")
        d.set(checkOut, forKey: "\(key).checkOut")
        d.set(placeName, forKey: "\(key).placeName")
        if let lat = placeLat { d.set(lat, forKey: "\(key).placeLat") } else { d.removeObject(forKey: "\(key).placeLat") }
        if let lng = placeLng { d.set(lng, forKey: "\(key).placeLng") } else { d.removeObject(forKey: "\(key).placeLng") }
        d.set(bookingPref, forKey: "\(key).bookingPref")
        d.set(vehicles, forKey: "\(key).vehicles")
    }

    func clear() {
        category = nil
        query = ""
        checkIn = nil
        checkOut = nil
        placeName = nil
        placeLat = nil
        placeLng = nil
        bookingPref = "all"
        vehicles = []
    }
}
