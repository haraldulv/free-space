import Foundation
import SwiftUI

/// Lagrer brukerens nylige søk så de kan vises som forslag i WhereSheet
/// når input-feltet er tomt. Persisteres til UserDefaults, max 5 entries.
@MainActor
final class RecentSearchesStore: ObservableObject {
    static let shared = RecentSearchesStore()

    @Published var entries: [RecentSearch] = []

    private let key = "tuno.recentSearches"
    private let maxEntries = 5

    private init() {
        load()
    }

    func add(placeName: String, category: String, checkIn: Date?, checkOut: Date?, lat: Double, lng: Double) {
        let trimmed = placeName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let entry = RecentSearch(
            id: UUID().uuidString,
            placeName: trimmed,
            category: category,
            checkIn: checkIn,
            checkOut: checkOut,
            lat: lat,
            lng: lng,
            savedAt: Date()
        )

        // Fjern duplikat på sted-navn så samme sted ikke vises flere ganger
        entries.removeAll { $0.placeName.caseInsensitiveCompare(entry.placeName) == .orderedSame }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func remove(_ id: String) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentSearch].self, from: data) else {
            return
        }
        entries = decoded
    }
}

struct RecentSearch: Codable, Identifiable, Hashable {
    let id: String
    let placeName: String
    let category: String
    let checkIn: Date?
    let checkOut: Date?
    let lat: Double
    let lng: Double
    let savedAt: Date

    var dateRangeLabel: String? {
        guard let ci = checkIn, let co = checkOut else { return nil }
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return "\(df.string(from: ci))–\(df.string(from: co))"
    }
}
