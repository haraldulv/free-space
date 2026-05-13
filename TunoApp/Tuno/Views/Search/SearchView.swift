import SwiftUI
import CoreLocation
import MapKit

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

    // Init-input som brukes en gang i .task for å sette opp søket
    private let initialQuery: String
    private let initialCheckIn: Date?
    private let initialCheckOut: Date?
    /// Hvis satt, bruker disse rett som søke-senter (uten å trenge placeId-
    /// lookup). Brukes for å restaurere et tidligere søk fra
    /// SearchContextStore — placeId lagres ikke der, kun lat/lng.
    private let initialLat: Double?
    private let initialLng: Double?
    private let initialBookingPref: BookingPreference
    private let initialVehicles: Set<VehicleType>
    private let initialCategory: ListingCategory?
    private let initialPlace: PlacePrediction?
    private let useMyLocationOnAppear: Bool
    /// Når true åpnes WhereSheet umiddelbart ved presentasjon (forsidens
    /// pille bruker dette for å gå direkte fra forsiden til kart-flow uten
    /// dobbel fullScreenCover).
    private let openWhereSheetOnAppear: Bool

    init(
        initialQuery: String = "",
        initialCheckIn: Date? = nil,
        initialCheckOut: Date? = nil,
        initialLat: Double? = nil,
        initialLng: Double? = nil,
        initialBookingPref: BookingPreference = .all,
        initialVehicles: Set<VehicleType> = [.motorhome],
        initialCategory: ListingCategory? = nil,
        initialPlace: PlacePrediction? = nil,
        useMyLocationOnAppear: Bool = false,
        openWhereSheetOnAppear: Bool = false
    ) {
        self.initialQuery = initialQuery
        self.initialCheckIn = initialCheckIn
        self.initialCheckOut = initialCheckOut
        self.initialLat = initialLat
        self.initialLng = initialLng
        self.initialBookingPref = initialBookingPref
        self.initialVehicles = initialVehicles
        self.initialCategory = initialCategory
        self.initialPlace = initialPlace
        self.useMyLocationOnAppear = useMyLocationOnAppear
        self.openWhereSheetOnAppear = openWhereSheetOnAppear
        _showWhereSheet = State(initialValue: false)
        // Ved åpning fra forside-pille: render WhereSheet INLINE (ikke som
        // fullScreenCover) til brukeren har lukket den første gang. Inline
        // unngår cover-presentasjonsanimasjonen og gir umiddelbar visning.
        _hasDismissedInitialSheet = State(initialValue: !openWhereSheetOnAppear)
        _query = State(initialValue: initialQuery)
        _checkIn = State(initialValue: initialCheckIn)
        _checkOut = State(initialValue: initialCheckOut)
        var f = SearchFilters()
        f.bookingPreference = initialBookingPref
        f.vehicleTypes = initialVehicles
        if let cat = initialCategory { f.category = cat }
        _filters = State(initialValue: f)
        _vehicles = State(initialValue: initialVehicles)
        _bookingPref = State(initialValue: initialBookingPref)
    }

    // Søke-state
    @State private var query = ""
    @State private var checkIn: Date?
    @State private var checkOut: Date?
    @State private var flexibility: Int = 0
    @State private var vehicles: Set<VehicleType> = [.motorhome]
    @State private var bookingPref: BookingPreference = .all
    @State private var filters = SearchFilters()

    // Kart-state
    @State private var isSatellite = false
    @State private var searchLat: Double?
    @State private var searchLng: Double?
    @State private var searchZoom: Float?
    /// Eksakt span (i grader) når et Google Places-treff har viewport-bounds.
    /// Overrider zoom-heuristikken så f.eks. "Solli plass" zoomer til kvartal-
    /// nivå mens "Oslo" viser hele byen (TU-83). Nil → bruk searchZoom som før.
    @State private var searchSpan: Double?
    /// Brukerens valgte søkesenter — IKKE oppdatert ved kart-panning eller
    /// carousel-swipe. Brukes som referanse-koordinat for "X km fra deg"-
    /// avstand på listing-kort, så avstanden ikke endrer seg under brukeren.
    @State private var originLat: Double?
    @State private var originLng: Double?
    @State private var navigationPath = NavigationPath()
    @State private var selectedListingIndex: Int? = nil
    @State private var hasInitialLocation = false

    // Pan-tracking for "Søk i dette området"-pille
    @State private var lastSearchedCenter: CLLocationCoordinate2D?
    @State private var lastSearchedRadius: Double = 30
    @State private var pendingPanCenter: (lat: Double, lng: Double, radius: Double)?
    @State private var showSearchHere = false
    /// Faktisk synlig kart-region (oppdateres umiddelbart via SearchMapView's
    /// onVisibleRegionChanged-callback). Brukes til å vise riktig antall
    /// "X plasser" i bottom-drawer som reflekterer hva som er i viewporten.
    @State private var mapVisibleRegion: MKCoordinateRegion?

    // Sheet-flagg
    @State private var showWhereSheet = false
    @State private var showFiltersSheet = false
    /// Når SearchView åpnes med `openWhereSheetOnAppear=true` (forside-pille)
    /// vil SwiftUI rendre body (kart + topBar) ETT frame før fullScreenCover
    /// legger WhereSheet over. Det gir et synlig kart-glimt. Vi gater alle
    /// search-lag bak denne flaggen til WhereSheet er lukket første gang.
    @State private var hasDismissedInitialSheet: Bool

    /// Vis WhereSheet som overlay over kartet (blur-effekten i sheet-en
    /// trenger noe synlig bak for å fungere). True ved åpning fra forsiden
    /// (før første dismiss) og når brukeren tapper søkepillen i kartet.
    private var whereSheetVisible: Bool { showWhereSheet || !hasDismissedInitialSheet }

    var body: some View {
        ZStack {
            mainSearchUI

            if whereSheetVisible {
                WhereSheet(
                    isPresented: Binding(
                        get: { whereSheetVisible },
                        set: { newValue in
                            if !newValue {
                                showWhereSheet = false
                                hasDismissedInitialSheet = true
                            }
                        }
                    ),
                    category: Binding(
                        get: { filters.category ?? .camping },
                        set: { filters.category = $0 }
                    ),
                    query: $query,
                    checkIn: $checkIn,
                    checkOut: $checkOut,
                    flexibility: $flexibility,
                    bookingPref: $bookingPref,
                    vehicles: $vehicles,
                    openingHoursFilter: $filters.openingHours,
                    placesService: placesService,
                    locationManager: locationManager,
                    onSelectPlace: handleSelectPlace,
                    onUseMyLocation: goToMyLocation,
                    onSearch: {
                        filters.bookingPreference = bookingPref
                        filters.vehicleTypes = vehicles
                        showWhereSheet = false
                        hasDismissedInitialSheet = true
                        performSearch()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: whereSheetVisible)
        .task {
            if hasInitialLocation { return }
            // Restaurert søk fra SearchContextStore: hopp rett til lagret
            // sted uten å vente på placeId-lookup.
            if let lat = initialLat, let lng = initialLng {
                setSearchCenter(lat: lat, lng: lng, zoom: 11)
                hasInitialLocation = true
                await searchAt(lat: lat, lng: lng)
                return
            }
            // Hvis brukeren valgte et sted i Hvor-modalen, gå dit først
            if let place = initialPlace {
                if let detail = await placesService.getPlaceDetail(placeId: place.id) {
                    if let v = detail.viewport {
                        setSearchRegion(lat: detail.lat, lng: detail.lng, viewport: v)
                    } else {
                        setSearchCenter(lat: detail.lat, lng: detail.lng, zoom: 11)
                    }
                    hasInitialLocation = true
                    await searchAt(lat: detail.lat, lng: detail.lng)
                    return
                }
            }
            locationManager.requestPermission()
            if useMyLocationOnAppear || hasInitialLocation == false {
                if let loc = locationManager.userLocation {
                    setSearchCenter(lat: loc.latitude, lng: loc.longitude, zoom: 12)
                    hasInitialLocation = true
                    await searchAt(lat: loc.latitude, lng: loc.longitude)
                    return
                }
            }
            await searchAt(lat: nil, lng: nil)
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

    private var mainSearchUI: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                mapLayer

                if selectedListingIndex == nil {
                    BottomListDrawer(
                        listings: visibleListings,
                        isFavorited: { id in favoritesService.favoriteIds.contains(id) },
                        onFavorite: toggleFavorite,
                        onSelect: { listing in
                            navigationPath.append(listing)
                        },
                        referenceLat: locationManager.userLocation?.latitude,
                        referenceLng: locationManager.userLocation?.longitude
                    )
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                topBar
                    .zIndex(2)

                if showSearchHere {
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
            centerSpan: searchSpan,
            selectedListingId: selectedListingIndex.flatMap { filteredListings.indices.contains($0) ? filteredListings[$0].id : nil },
            visitedIds: visitedStore.ids,
            searchNights: searchNightsCount,
            onSelect: { id in
                hideKeyboard()
                if let id, let idx = filteredListings.firstIndex(where: { $0.id == id }) {
                    // Marker boblen som besøkt umiddelbart, så den nedtones
                    // ved neste tap (uten å vente på at brukeren åpner detaljvisning).
                    visitedStore.markVisited(id)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedListingIndex = idx
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedListingIndex = nil
                    }
                }
            },
            onRegionChanged: handleRegionChanged,
            onVisibleRegionChanged: { region in
                mapVisibleRegion = region
            }
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .background(.regularMaterial, in: Circle())
                        }
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
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

                VStack(spacing: 10) {
                    FilterCircleButton(activeCount: filters.activeCount(dynamicMaxPrice: dynamicMaxPriceForBadge)) {
                        hideKeyboard()
                        showFiltersSheet = true
                    }
                    MapTypeToggleButton(isSatellite: isSatellite) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isSatellite.toggle()
                        }
                    }
                    .frame(width: 48, height: 48)
                    MyLocationButton(onTap: {
                        hideKeyboard()
                        goToMyLocation()
                    })
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

            if let idx = selectedListingIndex, !carouselListings.isEmpty {
                // Clamp idx hvis carousel-set har endret seg (f.eks. ved pan)
                let safeIdx = min(max(idx, 0), carouselListings.count - 1)
                MapBottomCardCarousel(
                    listings: carouselListings,
                    selectedIndex: Binding(
                        get: { safeIdx },
                        set: { newIdx in
                            selectedListingIndex = newIdx
                            // Ingen pan/zoom på sveip — vi viser kun listings
                            // som er i synlig kart-område (carouselListings)
                            // så brukeren havner aldri "langt vekk".
                        }
                    ),
                    onTap: { listing in
                        navigationPath.append(listing)
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedListingIndex = nil
                        }
                    },
                    isFavorited: { id in favoritesService.favoriteIds.contains(id) },
                    onFavoriteToggle: toggleFavorite,
                    referenceLat: locationManager.userLocation?.latitude,
                    referenceLng: locationManager.userLocation?.longitude
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Computed

    /// Antall døgn brukeren har søkt etter (utsjekk - innsjekk + 1). Nil hvis
    /// ingen periode er valgt. Brukes til å vise totalpris i prisbobler.
    private var searchNightsCount: Int? {
        guard let inDate = checkIn, let outDate = checkOut else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let span = (cal.dateComponents([.day], from: inDate, to: outDate).day ?? 0) + 1
        return span > 1 ? span : nil
    }

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
            // Bruk cached displayPrice (samme kilde som histogrammet) — fall
            // tilbake på listing.price for backward compat med eldre annonser.
            let price = listing.displayPrice ?? listing.price ?? 0
            if price < filters.priceMin || (filters.priceMax > 0 && price > filters.priceMax) { return false }
            switch filters.bookingPreference {
            case .all: break
            case .directOnly: if listing.instantBooking != true { return false }
            case .requestOnly: if listing.instantBooking == true { return false }
            }
            if !filters.amenities.isEmpty {
                let listingAmenities = Set((listing.amenities ?? []).compactMap(AmenityType.init(rawValue:)))
                if !filters.amenities.isSubset(of: listingAmenities) { return false }
            }
            if !filters.rentalPeriodTypes.isEmpty {
                let derived = Set(listing.derivedPeriodTypes)
                if filters.rentalPeriodTypes.isDisjoint(with: derived) { return false }
            }
            // Parkering: ikke filtrer på pris-pakke. Alt som har ledig
            // kapasitet i intervallet skal vises uansett om utleier har
            // dag-, uke-, måneds- eller årspris.
            return true
        }
    }

    /// Listings begrenset til de som faktisk er i kartets synlige bounding
    /// box. Brukes av bottom-drawer så "X plasser" reflekterer kartet, ikke
    /// debouncet søk-radius.
    private var visibleListings: [Listing] {
        guard let region = mapVisibleRegion else { return filteredListings }
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lngMin = region.center.longitude - region.span.longitudeDelta / 2
        let lngMax = region.center.longitude + region.span.longitudeDelta / 2

        let inRegion = filteredListings.compactMap { l -> (Listing, Double)? in
            guard let lat = l.lat, let lng = l.lng,
                  lat >= latMin, lat <= latMax,
                  lng >= lngMin, lng <= lngMax else { return nil }
            let d = haversineDistanceKm(
                lat1: region.center.latitude,
                lng1: region.center.longitude,
                lat2: lat,
                lng2: lng
            )
            return (l, d)
        }
        return inRegion.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    /// Listings i kartets synlige bounding box (samme som visibleListings)
    /// men med fallback til alle filteredListings hvis ingen er i region
    /// (f.eks. mid-pan før region-callback har firet). Brukes for carousel
    /// så sveip ikke gir tomt resultat.
    private var carouselListings: [Listing] {
        let visible = visibleListings
        return visible.isEmpty ? filteredListings : visible
    }

    private var priceArray: [Int] {
        // Bruker displayPrice (cached headline-pris) når tilgjengelig så også
        // måneds-/års-pakker er med i histogrammet. Faller tilbake på price for
        // gamle annonser før migrasjonen.
        listingService.searchResults
            .compactMap { $0.displayPrice ?? $0.price }
            .filter { $0 > 0 }
    }

    /// Beregner samme dynamicMaxPrice som FiltersSheet bruker, så badge på
    /// filter-knappen reflekterer korrekt om pris-filteret er aktivt.
    private var dynamicMaxPriceForBadge: Int {
        guard let m = priceArray.max() else { return 1000 }
        return ((m + 999) / 1000) * 1000
    }

    private var searchPillSubtitle: String {
        var parts: [String] = []
        // Kategori — vises først for tydelighet
        if let cat = filters.category {
            parts.append(cat == .camping ? "Camping" : "Parkering")
        }
        if let i = checkIn, let o = checkOut {
            let df = DateFormatter()
            df.dateFormat = "d. MMM"
            df.locale = Locale(identifier: "nb_NO")
            parts.append("\(df.string(from: i))–\(df.string(from: o))")
        } else {
            parts.append("Når som helst")
        }
        if vehicles.isEmpty {
            parts.append("Alle kjøretøy")
        } else if vehicles.count == 1, let v = vehicles.first {
            parts.append(v.displayName)
        } else {
            parts.append("\(vehicles.count) kjøretøy")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Search actions

    private func setSearchCenter(lat: Double, lng: Double, zoom: Float) {
        searchLat = lat
        searchLng = lng
        searchZoom = zoom
        searchSpan = nil
        originLat = lat
        originLng = lng
        lastSearchedCenter = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        showSearchHere = false
    }

    /// Sentrér kartet på et Google Places-treff og bruk stedets viewport for
    /// nøyaktig zoom-nivå. Span clampes til 0.01–0.5 grader (~1–55 km) så
    /// veldig spesifikke adresser ikke pixel-zoomer (TU-83).
    private func setSearchRegion(lat: Double, lng: Double, viewport: PlaceViewport) {
        let latDelta = abs(viewport.neLat - viewport.swLat)
        let lngDelta = abs(viewport.neLng - viewport.swLng)
        let span = max(0.01, min(0.5, max(latDelta, lngDelta) * 1.2))
        searchLat = lat
        searchLng = lng
        searchSpan = span
        searchZoom = Float(log2(360.0 / max(span, 0.0001)))
        originLat = lat
        originLng = lng
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
        // Lagre valgte datoer/tider i SearchContextStore så BookingView kan
        // pre-fylle dem når brukeren tapper en annonse fra søkeresultatet.
        let store = SearchContextStore.shared
        store.checkIn = checkIn
        store.checkOut = checkOut
        store.category = filters.category?.rawValue
        store.query = query
        store.placeName = query.isEmpty ? nil : query
        store.placeLat = searchLat
        store.placeLng = searchLng
        store.bookingPref = filters.bookingPreference.rawValue
        store.vehicles = filters.vehicleTypes.map { $0.rawValue }

        // Lagre i recent searches (ignorer "I nærheten"-søk uten konkret sted)
        if !query.isEmpty, let lat = searchLat, let lng = searchLng {
            RecentSearchesStore.shared.add(
                placeName: query,
                category: filters.category?.rawValue ?? "camping",
                checkIn: checkIn,
                checkOut: checkOut,
                lat: lat,
                lng: lng
            )
        }

        Task { await searchAt(lat: searchLat, lng: searchLng, radiusKm: 30) }
    }

    private func searchAt(lat: Double?, lng: Double?, radiusKm: Double = 30) async {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let amenitiesArg = filters.amenities.isEmpty ? nil : filters.amenities
        // Server-søket tar én kjøretøytype i dag — bruk første valgte. Multi-select
        // håndteres så klient-side i `filteredListings`.
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
            instantOnly: filters.bookingPreference == .directOnly,
            flexibilityDays: flexibility,
            openingHours: filters.openingHours
        )
    }

    private func handleSelectPlace(_ prediction: PlacePrediction) {
        Task {
            if let detail = await placesService.getPlaceDetail(placeId: prediction.id) {
                if let v = detail.viewport {
                    setSearchRegion(lat: detail.lat, lng: detail.lng, viewport: v)
                } else {
                    setSearchCenter(lat: detail.lat, lng: detail.lng, zoom: 11)
                }
                await searchAt(lat: detail.lat, lng: detail.lng)
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
                        Text("\(listing.displayPriceText) kr/\(listing.priceUnit?.displayName ?? "døgn")")
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
