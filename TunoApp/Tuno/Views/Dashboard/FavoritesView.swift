import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
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
                                ListingCard(
                                    listing: listing,
                                    isFavorited: favoritesService.favoriteIds.contains(listing.id),
                                    onFavoriteToggle: { _ in toggleFavorite(listing.id) }
                                )
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
        .onChange(of: favoritesService.favoriteIds) {
            Task { await loadFavorites() }
        }
    }

    private func loadFavorites() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            let ids = Array(favoritesService.favoriteIds)
            if !ids.isEmpty {
                let listings: [Listing] = try await supabase
                    .from("listings")
                    .select()
                    .in("id", values: ids)
                    .execute()
                    .value
                favorites = listings
            } else {
                favorites = []
            }
        } catch {
            print("Failed to load favorites: \(error)")
        }
        isLoading = false
    }

    private func toggleFavorite(_ listingId: String) {
        guard let userId = authManager.currentUser?.id else { return }
        Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
    }
}
