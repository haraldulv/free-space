import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var listingService = ListingService()
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var selectedCategory: ListingCategory = .camping

    // State som videreføres fra Hvor-modal til SearchView
    @State private var pendingQuery: String = ""
    @State private var pendingCheckIn: Date?
    @State private var pendingCheckOut: Date?
    @State private var pendingLat: Double?
    @State private var pendingLng: Double?
    @State private var pendingBookingPref: BookingPreference = .all
    @State private var pendingVehicles: Set<VehicleType> = [.motorhome, .campervan]
    @State private var pendingPlace: PlacePrediction?
    @State private var pendingUseMyLocation: Bool = false
    /// Når satt til true åpner SearchView direkte til kart (uten WhereSheet).
    /// Brukes for "Se alle"-knappene som skal hoppe rett til kart-resultater.
    @State private var pendingSkipWhereSheet: Bool = false
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
                        // Åpne SearchView direkte med WhereSheet aktivert. Tidligere
                        // skjedde det i to trinn (HomeView WhereSheet → 0.25s sleep →
                        // SearchView), men det ga et kort glimt av forsiden mellom
                        // overgangene. Nå er alt inni ett fullScreenCover.
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

                    // Kategori-picker: Camping (telt-ikon) / Parkering (bil-ikon)
                    HStack(spacing: 0) {
                        ForEach([ListingCategory.camping, .parking], id: \.self) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selectedCategory = category
                                    // Reset default kjøretøy for senere søk via pillen.
                                    pendingVehicles = (category == .camping) ? [.motorhome, .campervan] : [.car]
                                }
                                Task { await listingService.fetchHomeListings(category: category, userLat: locationManager.userLocation?.latitude, userLng: locationManager.userLocation?.longitude) }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(category.categoryIcon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 36, height: 36)
                                        .opacity(selectedCategory == category ? 1.0 : 0.5)
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
                    // Nær deg — kun for parkering, og kun hvis brukerlokasjon finnes
                    if selectedCategory == .parking, !listingService.nearbyListings.isEmpty {
                        ListingSection(
                            title: "Nær deg",
                            listings: listingService.nearbyListings,
                            onSeeAll: {
                                // Åpne kart-søket direkte (skip WhereSheet) sentrert på brukerens posisjon
                                if let loc = locationManager.userLocation {
                                    pendingLat = loc.latitude
                                    pendingLng = loc.longitude
                                    pendingUseMyLocation = true
                                }
                                pendingQuery = "Min posisjon"
                                pendingCheckIn = nil
                                pendingCheckOut = nil
                                pendingSkipWhereSheet = true
                                showSearch = true
                            }
                        )
                    }

                    // Ledige nå — kun for parkering
                    if selectedCategory == .parking, !listingService.availableNowListings.isEmpty {
                        ListingSection(
                            title: "Ledige nå",
                            listings: listingService.availableNowListings,
                            onSeeAll: {
                                // Åpne kart direkte rundt brukerens posisjon — ingen datoer
                                // (vis ALLE som er ledige uavhengig av dato, hurtig oversikt).
                                pendingCheckIn = nil
                                pendingCheckOut = nil
                                if let loc = locationManager.userLocation {
                                    pendingLat = loc.latitude
                                    pendingLng = loc.longitude
                                    pendingUseMyLocation = true
                                }
                                pendingQuery = "Min posisjon"
                                pendingSkipWhereSheet = true
                                showSearch = true
                            }
                        )
                    }

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
                    if selectedCategory != .parking, !listingService.availableTodayListings.isEmpty {
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
            SearchView(
                initialQuery: pendingQuery,
                initialCheckIn: pendingCheckIn,
                initialCheckOut: pendingCheckOut,
                initialLat: pendingLat,
                initialLng: pendingLng,
                initialBookingPref: pendingBookingPref,
                initialVehicles: pendingVehicles,
                initialCategory: selectedCategory,
                initialPlace: pendingPlace,
                useMyLocationOnAppear: pendingUseMyLocation,
                openWhereSheetOnAppear: !pendingSkipWhereSheet
            )
        }
        .onChange(of: showSearch) { _, isShown in
            // Reset skip-flagget når SearchView lukkes så neste vanlig søk
            // (via "Start søket"-pillen) åpner WhereSheet som før.
            if !isShown { pendingSkipWhereSheet = false }
        }
        .task {
            // Restore søkestate fra SearchContextStore — bruker som går tilbake
            // til forsiden får samme kategori/sted/datoer/kjøretøy som forrige søk.
            let ctx = SearchContextStore.shared
            if let cat = ctx.category, let parsed = ListingCategory(rawValue: cat) {
                selectedCategory = parsed
            }
            pendingQuery = ctx.query
            pendingCheckIn = ctx.checkIn
            pendingCheckOut = ctx.checkOut
            pendingLat = ctx.placeLat
            pendingLng = ctx.placeLng
            if let pref = BookingPreference(rawValue: ctx.bookingPref) {
                pendingBookingPref = pref
            }
            let restoredVehicles = Set(ctx.vehicles.compactMap { VehicleType(rawValue: $0) })
            let categoryAvailable = Set(VehicleType.available(for: selectedCategory))
            let intersected = restoredVehicles.intersection(categoryAvailable)
            let isDefaultlyAll = intersected.count == categoryAvailable.count
            if !intersected.isEmpty && !isDefaultlyAll {
                pendingVehicles = intersected
            } else {
                pendingVehicles = (selectedCategory == .camping) ? [.motorhome] : [.car]
            }
            // Be om location-permission for "Nær deg"-seksjonen.
            locationManager.requestPermission()
            await listingService.fetchHomeListings(category: selectedCategory, userLat: locationManager.userLocation?.latitude, userLng: locationManager.userLocation?.longitude)
            // Prefetch forsidebilder i bakgrunnen så Home ikke flickrer ved retur.
            prefetchHomeImages()
        }
        .onReceive(locationManager.$userLocation) { newLoc in
            // Når brukerlokasjon kommer inn (etter permission-prompt eller GPS-fix),
            // re-fetch så "Nær deg"-seksjonen kan populeres.
            guard newLoc != nil else { return }
            Task {
                await listingService.fetchHomeListings(
                    category: selectedCategory,
                    userLat: newLoc?.latitude,
                    userLng: newLoc?.longitude
                )
                prefetchHomeImages()
            }
        }
    }

    /// Prefetch første bildet fra hver listing i alle home-seksjonene. URLCache
    /// blir warm før cellene rendres → CachedAsyncImage treffer cache synkront
    /// og kortene flickrer ikke lengre når man kommer tilbake til Home.
    private func prefetchHomeImages() {
        let listings = listingService.nearbyListings
            + listingService.availableNowListings
            + listingService.featuredListings
            + listingService.popularListings
            + listingService.availableTodayListings
        let urls = listings.compactMap { $0.images.first.flatMap(URL.init(string:)) }
        ImagePrefetcher.prefetch(urls: urls)
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ListingSection: View {
    let title: String
    let listings: [Listing]
    /// Valgfri "Se alle"-handler. Hvis satt vises en pil-knapp ved siden av tittelen.
    var onSeeAll: (() -> Void)? = nil
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.neutral900)
                if let onSeeAll {
                    Button(action: onSeeAll) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.neutral400)
                            .padding(.leading, 2)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingCard(
                                listing: listing,
                                isFavorited: favoritesService.favoriteIds.contains(listing.id),
                                onFavoriteToggle: { _ in toggleFavorite(listing.id) },
                                referenceLat: locationManager.userLocation?.latitude,
                                referenceLng: locationManager.userLocation?.longitude
                            )
                            .frame(width: 185, height: 250)
                            .clipped()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear { locationManager.requestPermission() }
        }
    }

    private func toggleFavorite(_ listingId: String) {
        guard let userId = authManager.currentUser?.id else { return }
        Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
    }
}
