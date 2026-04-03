import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var favorites: [Listing] = []
    @State private var isLoading = true
    @State private var showLogin = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthPromptView(
                    icon: "heart",
                    message: "Logg inn for å se favorittene dine",
                    showLogin: $showLogin
                )
            } else if isLoading {
                ProgressView()
            } else if favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen favoritter ennå")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Utforsk plasser og legg til favoritter")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(favorites) { listing in
                            NavigationLink(value: listing) {
                                ListingCard(listing: listing, isFavorited: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailView(listingId: listing.id)
                }
            }
        }
        .navigationTitle("Favoritter")
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .task {
            await loadFavorites()
        }
    }

    private func loadFavorites() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            let favs: [Favorite] = try await supabase
                .from("favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let listingIds = favs.map(\.listingId)
            if !listingIds.isEmpty {
                let listings: [Listing] = try await supabase
                    .from("listings")
                    .select()
                    .in("id", values: listingIds)
                    .execute()
                    .value
                favorites = listings
            }
        } catch {
            print("Failed to load favorites: \(error)")
        }
        isLoading = false
    }
}
