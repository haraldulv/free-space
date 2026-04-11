import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @StateObject private var listingService = ListingService()
    @StateObject private var placesService = PlacesService()
    @StateObject private var locationManager = LocationManager()
    @State private var query = ""
    @State private var selectedVehicle: VehicleType = .motorhome
    @State private var showMap = true
    @State private var isSatellite = true
    @State private var navigationPath = NavigationPath()
    @State private var mapSelectedListing: Listing?
    @State private var searchLat: Double?
    @State private var searchLng: Double?
    @State private var searchZoom: Float?
    @State private var showSuggestions = false
    @State private var isSelectingPlace = false // Prevents onChange re-trigger
    @State private var checkIn: Date?
    @State private var checkOut: Date?
    @State private var showDatePicker = false
    @State private var selectedAmenities: Set<AmenityType> = []
    @State private var showAmenityFilter = false
    @State private var hasInitialLocation = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    searchHeader
                        .zIndex(2)

                    if showMap {
                        mapContent
                    } else {
                        listContent
                    }
                }

                if showSuggestions && !placesService.predictions.isEmpty {
                    autocompleteOverlay
                        .zIndex(10)
                }
            }
            .background(Color.neutral50)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.neutral600)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Søk")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listingId: listing.id)
            }
            .sheet(isPresented: $showDatePicker) {
                DateRangePickerSheet(checkIn: $checkIn, checkOut: $checkOut) {
                    showDatePicker = false
                    performSearch()
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showAmenityFilter) {
                AmenityFilterSheet(selectedAmenities: $selectedAmenities) {
                    showAmenityFilter = false
                    performSearch()
                }
                .presentationDetents([.medium])
            }
            .task {
                // Go to user location on launch
                locationManager.requestPermission()
                if let loc = locationManager.userLocation {
                    searchLat = loc.latitude
                    searchLng = loc.longitude
                    searchZoom = 12
                    hasInitialLocation = true
                    await listingService.search(vehicleType: selectedVehicle, lat: loc.latitude, lng: loc.longitude, radiusKm: 30)
                } else {
                    await listingService.search(vehicleType: selectedVehicle)
                }
            }
            .onReceive(locationManager.$userLocation) { newLoc in
                guard let loc = newLoc, !hasInitialLocation else { return }
                hasInitialLocation = true
                searchLat = loc.latitude
                searchLng = loc.longitude
                searchZoom = 12
                performSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
                dismiss()
            }
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                    TextField("Hvor skal du?", text: $query)
                        .font(.system(size: 15))
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            showSuggestions = false
                            hideKeyboard()
                            performSearch()
                        }
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newValue in
                            // Don't trigger autocomplete when we're programmatically setting query
                            guard !isSelectingPlace else { return }
                            placesService.autocomplete(query: newValue)
                            showSuggestions = !newValue.isEmpty
                        }

                    if !query.isEmpty {
                        Button {
                            isSelectingPlace = true
                            query = ""
                            isSelectingPlace = false
                            placesService.clear()
                            showSuggestions = false
                            searchLat = nil
                            searchLng = nil
                            searchZoom = nil
                            performSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.neutral300)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.neutral200, lineWidth: 1)
                )

                // Date chip
                Button {
                    hideKeyboard()
                    showDatePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        if let checkIn, let checkOut {
                            Text("\(shortDate(checkIn))–\(shortDate(checkOut))")
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            Text("Datoer")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(checkIn != nil ? Color.primary600 : .white)
                    .foregroundStyle(checkIn != nil ? .white : .neutral600)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(checkIn != nil ? Color.clear : Color.neutral200, lineWidth: 1)
                    )
                }

                // Map/List toggle
                Button {
                    hideKeyboard()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMap.toggle()
                        mapSelectedListing = nil
                    }
                } label: {
                    Image(systemName: showMap ? "list.bullet" : "map")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral600)
                        .frame(width: 36, height: 36)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.neutral200, lineWidth: 1)
                        )
                }
            }

            // Vehicle chips + filter button
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        FilterChip(
                            label: type.displayName,
                            icon: type.icon,
                            isSelected: selectedVehicle == type
                        ) {
                            hideKeyboard()
                            selectedVehicle = type
                            performSearch()
                        }
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.neutral200)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)

                    // Amenity filter button
                    Button {
                        hideKeyboard()
                        showAmenityFilter = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedAmenities.isEmpty ? .neutral700 : .primary600)
                                .frame(width: 34, height: 34)
                                .background(selectedAmenities.isEmpty ? .white : Color.primary50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedAmenities.isEmpty ? Color.neutral200 : Color.primary200, lineWidth: 1)
                                )

                            if !selectedAmenities.isEmpty {
                                Text("\(selectedAmenities.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.primary600)
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.white)
    }

    // MARK: - Map Content

    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            SearchMapView(
                listings: listingService.searchResults,
                isSatellite: isSatellite,
                centerLat: searchLat,
                centerLng: searchLng,
                centerZoom: searchZoom,
                onSelect: { id in
                    hideKeyboard()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if let id {
                            mapSelectedListing = listingService.searchResults.first { $0.id == id }
                        } else {
                            mapSelectedListing = nil
                        }
                    }
                },
                onRegionChanged: { lat, lng, radius in
                    // Auto-search when user pans the map
                    autoSearchAt(lat: lat, lng: lng, radius: radius)
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // Top overlay
            VStack {
                HStack {
                    // Count badge
                    Text("\(listingService.searchResults.count) plasser")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.7))
                        .clipShape(Capsule())

                    Spacer()

                    VStack(spacing: 8) {
                        // My location button
                        Button {
                            goToMyLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary600)
                                .frame(width: 36, height: 36)
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }

                        // Map type toggle
                        Button {
                            isSatellite.toggle()
                        } label: {
                            Image(systemName: isSatellite ? "map" : "globe.americas")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral700)
                                .frame(width: 36, height: 36)
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }

            // Loading indicator
            if listingService.isLoading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 80)
            }

            // Selected listing card
            if let listing = mapSelectedListing {
                MapListingCard(listing: listing) {
                    navigationPath.append(listing)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        Group {
            if listingService.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if listingService.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral300)
                    Text("Ingen resultater")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Text("Prøv å søke etter et annet sted")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
                Spacer()
            } else {
                HStack {
                    Text("\(listingService.searchResults.count) plasser funnet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(listingService.searchResults) { listing in
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
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Autocomplete Overlay

    private var autocompleteOverlay: some View {
        VStack(spacing: 0) {
            ForEach(placesService.predictions) { prediction in
                Button {
                    selectPlace(prediction)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary500)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(prediction.mainText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral900)
                            if !prediction.secondaryText.isEmpty {
                                Text(prediction.secondaryText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral400)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if prediction.id != placesService.predictions.last?.id {
                    Divider().padding(.leading, 42)
                }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 48)
    }

    // MARK: - Actions

    private func performSearch() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        Task {
            await listingService.search(
                query: query.isEmpty ? nil : query,
                vehicleType: selectedVehicle,
                lat: searchLat,
                lng: searchLng,
                radiusKm: searchLat != nil ? 30 : 20,
                checkIn: checkIn.map { df.string(from: $0) },
                checkOut: checkOut.map { df.string(from: $0) },
                amenities: selectedAmenities.isEmpty ? nil : selectedAmenities
            )
        }
    }

    private func selectPlace(_ prediction: PlacePrediction) {
        // Set flag BEFORE changing query to prevent onChange re-trigger
        isSelectingPlace = true
        query = prediction.mainText
        showSuggestions = false
        placesService.clear()
        hideKeyboard()

        // Reset flag after a brief delay (next runloop)
        DispatchQueue.main.async {
            isSelectingPlace = false
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        Task {
            if let detail = await placesService.getPlaceDetail(placeId: prediction.id) {
                searchLat = detail.lat
                searchLng = detail.lng
                searchZoom = 11
                await listingService.search(
                    vehicleType: selectedVehicle,
                    lat: detail.lat,
                    lng: detail.lng,
                    radiusKm: 30,
                    checkIn: checkIn.map { df.string(from: $0) },
                    checkOut: checkOut.map { df.string(from: $0) },
                    amenities: selectedAmenities.isEmpty ? nil : selectedAmenities
                )
                if !showMap {
                    withAnimation { showMap = true }
                }
            }
        }
    }

    private func autoSearchAt(lat: Double, lng: Double, radius: Double) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        Task {
            await listingService.search(
                vehicleType: selectedVehicle,
                lat: lat,
                lng: lng,
                radiusKm: radius,
                checkIn: checkIn.map { df.string(from: $0) },
                checkOut: checkOut.map { df.string(from: $0) },
                amenities: selectedAmenities.isEmpty ? nil : selectedAmenities
            )
        }
    }

    private func goToMyLocation() {
        hideKeyboard()
        if let loc = locationManager.userLocation {
            searchLat = loc.latitude
            searchLng = loc.longitude
            searchZoom = 12
            isSelectingPlace = true
            query = "Min posisjon"
            isSelectingPlace = false
            showSuggestions = false
            performSearch()
        } else {
            locationManager.requestLocation()
            // Observe for when location arrives
            Task {
                // Wait up to 5 seconds for location
                for _ in 0..<50 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if let loc = locationManager.userLocation {
                        searchLat = loc.latitude
                        searchLng = loc.longitude
                        searchZoom = 12
                        isSelectingPlace = true
                        query = "Min posisjon"
                        isSelectingPlace = false
                        showSuggestions = false
                        performSearch()
                        return
                    }
                }
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
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
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.neutral100)
                        .frame(width: 72, height: 72)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.system(size: 14, weight: .semibold))
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
                        Text("\(listing.price ?? 0) kr/\(listing.priceUnit?.displayName ?? "natt")")
                            .font(.system(size: 13, weight: .bold))
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
                            .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.neutral300)
            }
            .padding(10)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.primary600 : .white)
            .foregroundStyle(isSelected ? .white : .neutral700)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1)
            )
        }
    }
}

// MARK: - Amenity Filter Sheet

struct AmenityFilterSheet: View {
    @Binding var selectedAmenities: Set<AmenityType>
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Nullstill") {
                    selectedAmenities.removeAll()
                }
                .font(.system(size: 15))
                .foregroundStyle(.neutral500)

                Spacer()

                Text("Fasiliteter")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Bruk") {
                    onDone()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary600)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Amenity list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AmenityType.allCases, id: \.self) { amenity in
                        let isSelected = selectedAmenities.contains(amenity)
                        Button {
                            if isSelected {
                                selectedAmenities.remove(amenity)
                            } else {
                                selectedAmenities.insert(amenity)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: amenity.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(isSelected ? .primary600 : .neutral400)
                                    .frame(width: 24)

                                Text(amenity.label)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.neutral900)

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? .primary600 : .neutral200)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if amenity != AmenityType.allCases.last {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
}


