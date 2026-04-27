import Foundation
import SwiftUI

/// Persisterer hvilke annonser brukeren har åpnet, så bobler i kartsøket
/// kan vises gråere etter første tap. UserDefaults-basert — varighet er
/// permanent (kan utvides med "nullstill" eller TTL senere).
@MainActor
final class VisitedListingsStore: ObservableObject {
    static let shared = VisitedListingsStore()

    @Published private(set) var ids: Set<String> = []

    private let storageKey = "tuno.visitedListingIds"

    private init() {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        ids = Set(raw.split(separator: ",").map(String.init))
    }

    func has(_ id: String) -> Bool { ids.contains(id) }

    func markVisited(_ id: String) {
        guard !ids.contains(id) else { return }
        ids.insert(id)
        persist()
    }

    /// Brukes i innstillinger ("nullstill historikk") senere.
    func clear() {
        ids.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(ids.joined(separator: ","), forKey: storageKey)
    }
}
