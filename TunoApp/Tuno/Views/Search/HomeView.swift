import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var listingService = ListingService()
    @State private var searchText = ""
    @State private var showWhereSheet = false
    @State private var showSearch = false
    @State private var selectedCategory: ListingCategory = .camping

    // State som videreføres fra Hvor-modal til SearchView
    @State private var pendingQuery: String = ""
    @State private var pendingCheckIn: Date?
    @State private var pendingCheckOut: Date?
    @State private var pendingStartHour: Int?
    @State private var pendingEndHour: Int?
    @State private var pendingBookingPref: BookingPreference = .all
    @State private var pendingVehicles: Set<VehicleType> = [.motorhome]
    @State private var pendingPlace: PlacePrediction?
    @State private var pendingUseMyLocation: Bool = false
    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search bar + vehicle picker
                VStack(spacing: 16) {
                    // Search bar — Airbnb-style pille med sentrert innhold.
                    // Åpner WhereSheet (full-screen) først; brukeren går videre
                    // til SearchView/kart kun ved å trykke Søk i modalen.
                    Button {
                        showWhereSheet = true
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

                    // Kategori-picker: Camping (telt-ikon) / Parkering (bil-ikon)
                    HStack(spacing: 0) {
                        ForEach([ListingCategory.camping, .parking], id: \.self) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selectedCategory = category
                                }
                                Task { await listingService.fetchHomeListings(category: category) }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(category.lucideIcon)
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(selectedCategory == category ? Color.primary600 : .neutral400)
                                        .frame(width: 30, height: 30)
                                        .scaleEffect(selectedCategory == category ? 1.0 : 0.88)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: selectedCategory)
                                    Text(category.tabLabel)
                                        .font(.system(size: 12, weight: selectedCategory == category ? .semibold : .medium))
                                        .foregroundStyle(selectedCategory == category ? Color.primary600 : .neutral400)
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
                                    x: selectedCategory == .camping ? 20 : geo.size.width / 2 + 20,
                                    y: 0
                                )
                                .animation(.easeInOut(duration: 0.22), value: selectedCategory)
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
        .fullScreenCover(isPresented: $showWhereSheet) {
            WhereSheet(
                isPresented: $showWhereSheet,
                category: $selectedCategory,
                query: $pendingQuery,
                checkIn: $pendingCheckIn,
                checkOut: $pendingCheckOut,
                startHour: $pendingStartHour,
                endHour: $pendingEndHour,
                bookingPref: $pendingBookingPref,
                vehicles: $pendingVehicles,
                placesService: placesService,
                locationManager: locationManager,
                onSelectPlace: { prediction in
                    pendingPlace = prediction
                    pendingUseMyLocation = false
                },
                onUseMyLocation: {
                    pendingPlace = nil
                    pendingUseMyLocation = true
                },
                onSearch: {
                    showWhereSheet = false
                    // Liten pause så sheet rekker å lukke før kart presenteres
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showSearch = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(
                initialQuery: pendingQuery,
                initialCheckIn: pendingCheckIn,
                initialCheckOut: pendingCheckOut,
                initialStartHour: pendingStartHour,
                initialEndHour: pendingEndHour,
                initialBookingPref: pendingBookingPref,
                initialVehicles: pendingVehicles,
                initialCategory: selectedCategory,
                initialPlace: pendingPlace,
                useMyLocationOnAppear: pendingUseMyLocation
            )
        }
        .task {
            await listingService.fetchHomeListings(category: selectedCategory)
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
