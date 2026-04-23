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
                VStack(spacing: 16) {
                    // Search bar — Airbnb-style pille med sentrert innhold
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.neutral900)
                            Text("Start søket")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.neutral900)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                        .overlay(
                            RoundedRectangle(cornerRadius: 36)
                                .stroke(Color.neutral200.opacity(0.8), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
                    }

                    // Kategori-picker med Tuno-grønn på aktiv state
                    HStack(spacing: 0) {
                        ForEach([VehicleType.motorhome, .car], id: \.self) { type in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selectedVehicle = type
                                }
                                Task { await listingService.fetchHomeListings(vehicleType: type) }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(type.lucideIcon)
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(selectedVehicle == type ? Color.primary600 : .neutral400)
                                        .frame(width: 30, height: 30)
                                        .scaleEffect(selectedVehicle == type ? 1.0 : 0.88)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: selectedVehicle)
                                    Text(type.displayName)
                                        .font(.system(size: 12, weight: selectedVehicle == type ? .semibold : .medium))
                                        .foregroundStyle(selectedVehicle == type ? Color.primary600 : .neutral400)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.primary600)
                                .frame(width: geo.size.width / 2 - 40, height: 2)
                                .offset(
                                    x: selectedVehicle == .motorhome ? 20 : geo.size.width / 2 + 20,
                                    y: 0
                                )
                                .animation(.easeInOut(duration: 0.22), value: selectedVehicle)
                        }
                        .frame(height: 2)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.neutral200.opacity(0.7))
                            .frame(height: 0.5)
                            .offset(y: 1)
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
                    // Nye plasser (alle ekte bruker-annonser, sortert nyest først)
                    if !listingService.featuredListings.isEmpty {
                        ListingSection(
                            title: "Nye plasser",
                            listings: listingService.featuredListings
                        )
                    }

                    // Populære (med rating)
                    if !listingService.popularListings.isEmpty {
                        ListingSection(
                            title: "Populære nå",
                            listings: listingService.popularListings
                        )
                    }

                    // Tilgjengelig i dag (direktebestilling, ikke blokkert)
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
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listingId: listing.id)
        }
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
        // navigationDestination flyttet opp til HomeView-nivå for å unngå
        // SwiftUI-feilen "declared earlier on the stack" når flere
        // ListingSections er på samme skjerm.
    }

    private func toggleFavorite(_ listingId: String) {
        guard let userId = authManager.currentUser?.id else { return }
        Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
    }
}
