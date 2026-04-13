import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var listingService = ListingService()
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var selectedVehicle: VehicleType = .motorhome

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search bar + vehicle picker
                VStack(spacing: 14) {
                    // Search bar
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.neutral500)
                            Text("Hvor skal du?")
                                .font(.system(size: 15))
                                .foregroundStyle(.neutral400)
                            Spacer()
                        }
                        .padding(14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    }

                    // Vehicle type picker
                    HStack(spacing: 0) {
                        ForEach([VehicleType.motorhome, .car], id: \.self) { type in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedVehicle = type
                                }
                                Task { await listingService.fetchHomeListings(vehicleType: type) }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 20))
                                    Text(type.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(selectedVehicle == type ? .primary600 : .neutral400)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.primary600)
                                .frame(width: geo.size.width / 2, height: 2)
                                .offset(x: selectedVehicle == .motorhome ? 0 : geo.size.width / 2)
                                .animation(.easeInOut(duration: 0.2), value: selectedVehicle)
                        }
                        .frame(height: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if listingService.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if listingService.popularListings.isEmpty && listingService.featuredListings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundStyle(.neutral300)
                        Text("Ingen plasser å vise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(.top, 40)
                } else {
                    // Popular listings
                    if !listingService.popularListings.isEmpty {
                        ListingSection(
                            title: "Populære i Norge",
                            listings: listingService.popularListings
                        )
                    }

                    // Featured
                    if !listingService.featuredListings.isEmpty {
                        ListingSection(
                            title: "Fremhevede i Norge",
                            listings: listingService.featuredListings
                        )
                    }

                    // Available today
                    if !listingService.availableTodayListings.isEmpty {
                        ListingSection(
                            title: "Tilgjengelig i dag",
                            listings: listingService.availableTodayListings
                        )
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.neutral50)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showSearch) {
            SearchView()
        }
        .task {
            await listingService.fetchHomeListings(vehicleType: selectedVehicle)
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ListingSection: View {
    let title: String
    let listings: [Listing]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingCard(
                                listing: listing,
                                isFavorited: favoritesService.favoriteIds.contains(listing.id),
                                onFavoriteToggle: { _ in toggleFavorite(listing.id) }
                            )
                            .frame(width: 200)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listingId: listing.id)
        }
    }

    private func toggleFavorite(_ listingId: String) {
        guard let userId = authManager.currentUser?.id else { return }
        Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
    }
}
