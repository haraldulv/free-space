import Foundation
import SwiftUI

@MainActor
class FavoritesService: ObservableObject {
    @Published var favoriteIds: Set<String> = []

    func loadFavorites(userId: String) async {
        do {
            let favs: [Favorite] = try await supabase
                .from("favorites")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            favoriteIds = Set(favs.map(\.listingId))
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }

    func toggle(listingId: String, userId: String) async {
        let wasFavorited = favoriteIds.contains(listingId)

        // Optimistic update
        if wasFavorited {
            favoriteIds.remove(listingId)
        } else {
            favoriteIds.insert(listingId)
        }

        do {
            if wasFavorited {
                try await supabase
                    .from("favorites")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("listing_id", value: listingId)
                    .execute()
            } else {
                try await supabase
                    .from("favorites")
                    .insert(["user_id": userId, "listing_id": listingId])
                    .execute()
            }
        } catch {
            // Revert on failure
            if wasFavorited {
                favoriteIds.insert(listingId)
            } else {
                favoriteIds.remove(listingId)
            }
            print("Failed to toggle favorite: \(error)")
        }
    }
}
