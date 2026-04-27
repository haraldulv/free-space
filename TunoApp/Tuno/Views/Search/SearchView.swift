import SwiftUI
import CoreLocation

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Hovedsøk-skjerm i Airbnb-stil:
/// - Full-screen kart i bunnen
/// - Svevende søkepille + filter-knapp øverst
/// - "Søk i dette området"-pille som vises ved pan
/// - Swipebar bottom-card carousel når en boble er valgt
/// - List/kart-toggle som FAB nederst
struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var listingService = ListingService()
    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var visitedStore = VisitedListingsStore.shared

    // Søke-state
    @State private var query = ""
    @State private var checkIn: Date?
    @State private var checkOut: Date?
    @State private var guests: Int = 0
    @State private var filters = SearchFilters()

    // Kart-state
    @State private var showMap = true
    @State private var isSatellite = false
    @State private var searchLat: Double?
    @State private var searchLng: Double?
    @State private var searchZoom: Float?
    @State private var navigationPath = NavigationPath()
    @State private var selectedListingIndex: Int? = nil
    @State private var hasInitialLocation = false

    // Pan-tracking for "Søk i dette området"-pille
    @State private var lastSearchedCenter: CLLocationCoordinate2D?
    @State private var lastSearchedRadius: Double = 30
    @State private var pendingPanCenter: (lat: Double, lng: Double, radius: Double)?
    @State private var showSearchHere = false

    // Sheet-flagg
    @State private var showWhereSheet = false
    @State private var showFiltersSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                if showMap {
                    mapLayer
                } else {
                    listLayer
                }

                topBar
                    .zIndex(2)

                if showMap && showSearchHere {
                    searchHereLayer
                        .zIndex(3)
                }

                bottomLayer
                    .zIndex(2)
            }
            .background(Color.neutral50)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listingId: listing.id)
            }
            .sheet(isPresented: $showWhereSheet) {
                WhereSheet(
                    isPresented: $showWhereSheet,
                    query: $query,
                    checkIn: $checkIn,
                    checkOut: $checkOut,
                    guests: $guests,
                    placesService: placesService,
                    locationManager: locationManager,
                    onSelectPlace: handleSelectPlace,
                    onUseMyLocation: goToMyLocation,
                    onSearch: performSearch
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFiltersSheet) {
                FiltersSheet(
                    isPresented: $showFiltersSheet,
                    filters: $filters,
                    prices: priceArray,
                    resultCount: filteredListings.count,
                    onApply: performSearch
                )
                .presentationDetents([.large])
            }
            .task {
                if hasInitialLocation { return }
                locationManager.requestPermission()
                if let loc = locationManager.userLocation {
                    setSearchCenter(lat: loc.latitude, lng: loc.longitude, zoom: 12)
                    hasInitialLocation = true
                    await searchAt(lat: loc.latitude, lng: loc.longitude)
                } else {
                    await searchAt(lat: nil, lng: nil)
                }
            }
            .onReceive(locationManager.$userLocation) { newLoc in
                guard let loc = newLoc, !hasInitialLocation else { return }
                hasInitialLocation = true
                setSearchCenter(lat: loc.latitude, lng: loc.longitude, zoom: 12)
                performSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
                dismiss()
            }
        }
    }

    // MARK: - Layers

    private var mapLayer: some View {
        SearchMapView(
            listings: filteredListings,
            isSatellite: isSatellite,
            centerLat: searchLat,
            centerLng: searchLng,
            centerZoom: searchZoom,
            selectedListingId: selectedListingIndex.flatMap { filteredListings.indices.contains($0) ? filteredListings[$0].id : nil },
            visitedIds: visitedStore.ids,
            onSelect: { id in
                hideKeyboard()
                if let id, let idx = filteredListings.firstIndex(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedListingIndex = idx
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedListingIndex = nil
                    }
                }
            },
            onRegionChanged: handleRegionChanged
        )
        .ignoresSafeArea()
    }

    private var listLayer: some View {
        Group {
            if listingService.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if filteredListings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    HStack {
                        Text("\(filteredListings.count) plasser funnet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 90)
                    .padding(.bottom, 8)

                    LazyVStack(spacing: 16) {
                        ForEach(filteredListings) { listing in
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .background(Color.white)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.neutral300)
            Text("Ingen resultater")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.neutral500)
            Text("Prøv et annet sted eller fjern filtre")
                .font(.system(size: 14))
                .foregroundStyle(.neutral400)
            Spacer()
        }
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                SearchPill(
                    primary: query.isEmpty ? "Hvor vil du dra?" : query,
                    secondary: searchPillSubtitle,
                    onTap: {
                        hideKeyboard()
                        showWhereSheet = true
                    }
                )

                FilterCircleButton(activeCount: filters.activeCount) {
                    hideKeyboard()
                    showFiltersSheet = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var searchHereLayer: some View {
        VStack {
            Spacer().frame(height: 70)
            SearchHerePill(isLoading: listingService.isLoading) {
                triggerPendingSearch()
            }
            Spacer()
        }
    }

    private var bottomLayer: some View {
        VStack {
            Spacer()

            if showMap, let idx = selectedListingIndex, !filteredListings.isEmpty {
                MapBottomCardCarousel(
                    listings: filteredListings,
                    selectedIndex: Binding(
                        get: { idx },
                        set: { newIdx in
                            selectedListingIndex = newIdx
                            // Pann kartet til den nye listingens posisjon
                            if filteredListings.indices.contains(newIdx),
                               let lat = filteredListings[newIdx].lat,
                               let lng = filteredListings[newIdx].lng {
                                searchLat = lat
                                searchLng = lng
                                searchZoom = max(searchZoom ?? 11, 12)
                            }
                        }
                    ),
                    onTap: { listing in
                        navigationPath.append(listing)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack {
                Spacer()
                ListMapToggleFAB(showingMap: showMap) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMap.toggle()
                        selectedListingIndex = nil
                    }
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Computed

    /// Klient-side filtrering basert på SearchFilters. Server-search
    /// håndterer query+lat+lng+vehicle+amenities+instant; resterende
    /// filtre (pris, kategori, multi-vehicle, ekstra booking-options)
    /// gjøres her.
    private var filteredListings: [Listing] {
        listingService.searchResults.filter { listing in
            if let cat = filters.category, listing.category != cat { return false }
            if !filters.vehicleTypes.isEmpty {
                if let t = listing.vehicleType, !filters.vehicleTypes.contains(t) { return false }
            }
            let price = listing.price ?? 0
            if price < filters.priceMin || (filters.priceMax < 5000 && price > filters.priceMax) { return false }
            if filters.instantBookingOnly && listing.instantBooking != true { return false }
            if !filters.amenities.isEmpty {
                let listingAmenities = Set((listing.amenities ?? []).compactMap(AmenityType.init(rawValue:)))
                if !filters.amenities.isSubset(of: listingAmenities) { return false }
            }
            return true
        }
    }

    private var priceArray: [Int] {
        listingService.searchResults.compactMap { $0.price }.filter { $0 > 0 }
    }

    private var searchPillSubtitle: String {
        var parts: [String] = []
        if let i = checkIn, let o = checkOut {
            let df = DateFormatter()
            df.dateFormat = "d. MMM"
            df.locale = Locale(identifier: "nb_NO")
            parts.append("\(df.string(from: i))–\(df.string(from: o))")
        } else {
            parts.append("Når som helst")
        }
        if guests > 0 {
            parts.append("\(guests) gjest\(guests == 1 ? "" : "er")")
        } else {
            parts.append("Hvem som helst")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Search actions

    private func setSearchCenter(lat: Double, lng: Double, zoom: Float) {
        searchLat = lat
        searchLng = lng
        searchZoom = zoom
        lastSearchedCenter = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        showSearchHere = false
    }

    private func handleRegionChanged(lat: Double, lng: Double, radius: Double) {
        // Beregn distanse fra siste søkte senter; vis pille hvis vesentlig flytt.
        if let last = lastSearchedCenter {
            let dx = lat - last.latitude
            let dy = lng - last.longitude
            let approxKm = sqrt(dx * dx + dy * dy) * 111  // rough degrees → km
            if approxKm > lastSearchedRadius * 0.4 {
                pendingPanCenter = (lat, lng, radius)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSearchHere = true
                }
            }
        }
        // Auto-søk fortsatt aktiv (debounced i Coordinator)
        Task { await searchAt(lat: lat, lng: lng, radiusKm: radius) }
        lastSearchedCenter = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        lastSearchedRadius = radius
    }

    private func triggerPendingSearch() {
        if let p = pendingPanCenter {
            Task { await searchAt(lat: p.lat, lng: p.lng, radiusKm: p.radius) }
            pendingPanCenter = nil
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showSearchHere = false
        }
    }

    private func performSearch() {
        Task { await searchAt(lat: searchLat, lng: searchLng, radiusKm: 30) }
    }

    private func searchAt(lat: Double?, lng: Double?, radiusKm: Double = 30) async {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let amenitiesArg = filters.amenities.isEmpty ? nil : filters.amenities
        let vehicleArg = filters.vehicleTypes.first ?? .motorhome
        await listingService.search(
            query: query.isEmpty ? nil : query,
            vehicleType: vehicleArg,
            lat: lat,
            lng: lng,
            radiusKm: lat != nil ? radiusKm : 20,
            checkIn: checkIn.map { df.string(from: $0) },
            checkOut: checkOut.map { df.string(from: $0) },
            amenities: amenitiesArg,
            instantOnly: filters.instantBookingOnly
        )
    }

    private func handleSelectPlace(_ prediction: PlacePrediction) {
        Task {
            if let detail = await placesService.getPlaceDetail(placeId: prediction.id) {
                setSearchCenter(lat: detail.lat, lng: detail.lng, zoom: 11)
                await searchAt(lat: detail.lat, lng: detail.lng)
                if !showMap {
                    withAnimation { showMap = true }
                }
            }
        }
    }

    private func goToMyLocation() {
        if let loc = locationManager.userLocation {
            setSearchCenter(lat: loc.latitude, lng: loc.longitude, zoom: 12)
            query = "Min posisjon"
            performSearch()
        } else {
            locationManager.requestLocation()
            Task {
                for _ in 0..<50 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if let loc = locationManager.userLocation {
                        setSearchCenter(lat: loc.latitude, lng: loc.longitude, zoom: 12)
                        query = "Min posisjon"
                        performSearch()
                        return
                    }
                }
            }
        }
    }

    private func toggleFavorite(_ listingId: String) {
        guard let userId = authManager.currentUser?.id else { return }
        Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
    }
}

// MARK: - Date Range Picker Sheet

struct DateRangePickerSheet: View {
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    let onDone: () -> Void

    @State private var tempCheckIn = Date()
    @State private var tempCheckOut = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var selectingCheckOut = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Nullstill") {
                    checkIn = nil
                    checkOut = nil
                    onDone()
                }
                .font(.system(size: 15))
                .foregroundStyle(.neutral500)

                Spacer()

                Text("Velg datoer")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Bruk") {
                    checkIn = tempCheckIn
                    checkOut = tempCheckOut
                    onDone()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary600)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                DateTab(label: "Innsjekk", date: tempCheckIn, isActive: !selectingCheckOut) {
                    selectingCheckOut = false
                }
                DateTab(label: "Utsjekk", date: tempCheckOut, isActive: selectingCheckOut) {
                    selectingCheckOut = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            DatePicker(
                "",
                selection: selectingCheckOut ? $tempCheckOut : $tempCheckIn,
                in: selectingCheckOut ? Calendar.current.date(byAdding: .day, value: 1, to: tempCheckIn)!... : Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 12)
            .environment(\.locale, Locale(identifier: "nb_NO"))
            .environment(\.calendar, {
                var cal = Calendar(identifier: .gregorian)
                cal.firstWeekday = 2
                return cal
            }())
            .onChange(of: tempCheckIn) { _, newValue in
                if tempCheckOut <= newValue {
                    tempCheckOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue)!
                }
                selectingCheckOut = true
            }

            Spacer()
        }
        .onAppear {
            if let checkIn { tempCheckIn = checkIn }
            if let checkOut { tempCheckOut = checkOut }
        }
    }
}

struct DateTab: View {
    let label: String
    let date: Date
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? .primary600 : .neutral400)
                Text(formatDate(date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isActive ? .neutral900 : .neutral500)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.primary50 : Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }
}

// MARK: - Map Listing Card

struct MapListingCard: View {
    let listing: Listing
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let imageUrl = listing.images?.first, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.neutral100)
                        }
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.neutral100)
                        .frame(width: 88, height: 88)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)

                    if let city = listing.city {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(city)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.neutral500)
                    }

                    HStack(spacing: 6) {
                        Text("\(listing.displayPriceText) kr/\(listing.priceUnit?.displayName ?? "natt")")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.neutral900)

                        if let spots = listing.spots, spots > 1 {
                            Text("\(spots)p")
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral400)
                        }

                        if listing.instantBooking == true {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("Direkte")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.primary600)
                        }
                    }
                }

                Spacer()
            }
            .padding(10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
