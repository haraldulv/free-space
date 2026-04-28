import SwiftUI
import GoogleMaps
import GooglePlaces

// Initialize Google Maps + Places SDK — call once at app startup
func initializeGoogleMaps() {
    let key = AppConfig.googleMapsAPIKey
    guard !key.isEmpty else {
        print("Google Maps API key not set in AppConfig")
        return
    }
    GMSServices.provideAPIKey(key)
    GMSPlacesClient.provideAPIKey(key)
}

// MARK: - Listing Detail Map

struct ListingMapView: UIViewRepresentable {
    let lat: Double
    let lng: Double
    var spotMarkers: [SpotMarker] = []
    var hideExactLocation: Bool = false
    var isSatellite: Bool = false

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: lat,
            longitude: lng,
            zoom: hideExactLocation ? 14 : 17
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = isSatellite ? .hybrid : .normal
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false

        if hideExactLocation {
            let circle = GMSCircle(position: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: 500)
            circle.fillColor = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 0.15)
            circle.strokeColor = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 0.5)
            circle.strokeWidth = 2
            circle.map = mapView
        } else if !spotMarkers.isEmpty {
            for (i, spot) in spotMarkers.enumerated() {
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng)
                marker.iconView = createNumberedPin(number: i + 1)
                marker.map = mapView
            }
        } else {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            marker.map = mapView
        }

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.mapType = isSatellite ? .hybrid : .normal
    }

    private func createNumberedPin(number: Int) -> UIView {
        let size: CGFloat = 30
        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.backgroundColor = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1)
        view.layer.cornerRadius = size / 2
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 3

        let label = UILabel(frame: view.bounds)
        label.text = "\(number)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        view.addSubview(label)

        return view
    }
}

// MARK: - Search Results Map

struct SearchMapView: UIViewRepresentable {
    let listings: [Listing]
    var isSatellite: Bool = true
    var centerLat: Double?
    var centerLng: Double?
    var centerZoom: Float?
    var selectedListingId: String? = nil
    /// Snapshot av besøkte listing-IDs. Sendes inn fra parent som
    /// `VisitedListingsStore.shared.ids` så updateUIView kan re-bygge
    /// bobler når en annonse endrer visited-status.
    var visitedIds: Set<String> = []
    var onSelect: ((String?) -> Void)? = nil
    var onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)? = nil

    private static let stateKey = "tuno.searchMap.state"
    private static let stateTTL: TimeInterval = 30 * 60 // 30 min

    private static func searchKey(lat: Double?, lng: Double?, zoom: Float?) -> String {
        guard let lat, let lng else { return "default" }
        let z = zoom ?? 11
        return String(format: "%.4f,%.4f,%.1f", lat, lng, z)
    }

    private static func readSavedCamera(searchKey: String) -> (lat: Double, lng: Double, zoom: Float)? {
        guard let data = UserDefaults.standard.dictionary(forKey: stateKey) else { return nil }
        guard let savedKey = data["key"] as? String, savedKey == searchKey else { return nil }
        guard let ts = data["ts"] as? Double, Date().timeIntervalSince1970 - ts < stateTTL else { return nil }
        guard let lat = data["lat"] as? Double, let lng = data["lng"] as? Double, let zoom = data["zoom"] as? Double else { return nil }
        return (lat, lng, Float(zoom))
    }

    private static func saveCamera(searchKey: String, lat: Double, lng: Double, zoom: Float) {
        UserDefaults.standard.set([
            "key": searchKey,
            "lat": lat,
            "lng": lng,
            "zoom": Double(zoom),
            "ts": Date().timeIntervalSince1970,
        ], forKey: stateKey)
    }

    func makeCoordinator() -> Coordinator {
        let key = Self.searchKey(lat: centerLat, lng: centerLng, zoom: centerZoom)
        let saver: (Double, Double, Float) -> Void = { lat, lng, zoom in
            Self.saveCamera(searchKey: key, lat: lat, lng: lng, zoom: zoom)
        }
        return Coordinator(onSelect: onSelect, onRegionChanged: onRegionChanged, onCameraIdle: saver)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let key = Self.searchKey(lat: centerLat, lng: centerLng, zoom: centerZoom)
        let saved = Self.readSavedCamera(searchKey: key)

        let lat = saved?.lat ?? centerLat ?? 64.5
        let lng = saved?.lng ?? centerLng ?? 14.0
        let zoom: Float = saved?.zoom ?? centerZoom ?? (centerLat != nil ? 11 : 4)
        let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: zoom)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = isSatellite ? .hybrid : .normal
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        context.coordinator.lastCenterLat = centerLat
        context.coordinator.lastCenterLng = centerLng
        context.coordinator.lastSelectedListingId = selectedListingId
        context.coordinator.lastVisitedIds = visitedIds

        addMarkers(to: mapView, coordinator: context.coordinator)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.mapType = isSatellite ? .hybrid : .normal

        // Check if center changed (new place search or "my location")
        let centerChanged = centerLat != context.coordinator.lastCenterLat || centerLng != context.coordinator.lastCenterLng
        // En eksplisitt zoom-endring (nytt søk-zoom) skal alltid respekteres.
        // Kun-pan (uendret centerZoom) skal ikke overstyre brukerens current zoom.
        let zoomChanged = centerZoom != context.coordinator.lastCenterZoom
        context.coordinator.lastCenterLat = centerLat
        context.coordinator.lastCenterLng = centerLng
        context.coordinator.lastCenterZoom = centerZoom

        // Diff markers. Full rebuild KUN ved endring i listings-settet.
        // Selection- og visited-endringer oppdaterer kun de relevante
        // markørenes iconView, så tap-respons føles umiddelbar.
        let listingsKey = listings.compactMap { $0.lat != nil && $0.lng != nil ? $0.id : nil }.sorted().joined(separator: ",")
        if listingsKey != context.coordinator.lastListingIdsKey {
            mapView.clear()
            context.coordinator.markerToId.removeAll()
            addMarkers(to: mapView, coordinator: context.coordinator, selectedId: selectedListingId)
            context.coordinator.lastListingIdsKey = listingsKey
            context.coordinator.lastSelectedListingId = selectedListingId
            context.coordinator.lastVisitedIds = visitedIds
        } else {
            let visitedDiff = visitedIds.symmetricDifference(context.coordinator.lastVisitedIds)
            let selectionChanged = selectedListingId != context.coordinator.lastSelectedListingId
            if !visitedDiff.isEmpty || selectionChanged {
                var idsToUpdate: Set<String> = visitedDiff
                if selectionChanged {
                    if let prev = context.coordinator.lastSelectedListingId { idsToUpdate.insert(prev) }
                    if let curr = selectedListingId { idsToUpdate.insert(curr) }
                }
                for (marker, id) in context.coordinator.markerToId where idsToUpdate.contains(id) {
                    guard let listing = listings.first(where: { $0.id == id }) else { continue }
                    marker.iconView = Self.createPriceBubble(
                        listing: listing,
                        isVisited: visitedIds.contains(id),
                        isSelected: id == selectedListingId
                    )
                }
                context.coordinator.lastSelectedListingId = selectedListingId
                context.coordinator.lastVisitedIds = visitedIds
            }
        }

        if centerChanged, let lat = centerLat, let lng = centerLng {
            // Ved kun-pan (samme centerZoom som sist, eller nil): behold mapView's
            // nåværende zoom så vi ikke overstyrer brukerens manuelle zoom-justering.
            let zoom: Float = zoomChanged ? (centerZoom ?? 11) : mapView.camera.zoom
            let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: zoom)
            mapView.animate(to: camera)
        }
    }

    private func addMarkers(to mapView: GMSMapView, coordinator: Coordinator, selectedId: String? = nil) {
        let validListings = listings.filter { $0.lat != nil && $0.lng != nil }
        let activeSelectedId = selectedId ?? selectedListingId

        for listing in validListings {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: listing.lat!, longitude: listing.lng!)
            marker.iconView = Self.createPriceBubble(
                listing: listing,
                isVisited: visitedIds.contains(listing.id),
                isSelected: activeSelectedId == listing.id
            )
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView
            coordinator.markerToId[marker] = listing.id
        }
    }

    /// Bygger en pris-boble i Airbnb-stil med 3 tilstander:
    /// - **Default** (hvit + svart tekst): nøytral, ikke besøkt
    /// - **Visited** (lys grå + svart tekst): brukeren har trykket på denne før
    /// - **Selected** (svart + hvit tekst): aktivt valgt — kort vises
    /// Alle tilstander har 0.5px subtil border og lett "soft glow"-skygge,
    /// så bobler står klart mot kartet uten å se ut som firkanter.
    /// Lik størrelse i alle tilstander så bobler ikke "hopper" ved tap.
    static func createPriceBubble(listing: Listing, isVisited: Bool, isSelected: Bool) -> UIView {
        let container = UIView()

        // Kun hairline-border, ingen drop shadow. CALayer-skygge gir alltid
        // en subtil firkantet halo selv med shadowPath, og Airbnb klarer
        // seg med bare border for synlighet på lyse kart.
        container.layer.borderWidth = 0.5

        if isSelected {
            container.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
            container.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        } else if isVisited {
            container.backgroundColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)
            container.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        } else {
            container.backgroundColor = .white
            container.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        }
        container.layer.cornerRadius = 16

        let label = UILabel()
        let text = NSMutableAttributedString()
        let textColor: UIColor = isSelected
            ? .white
            : UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
        let secondaryColor = textColor.withAlphaComponent(0.65)

        text.append(NSAttributedString(
            string: "\(listing.displayPriceText) kr",
            attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: textColor]
        ))

        let spots = listing.spots ?? 1
        if spots > 1 {
            text.append(NSAttributedString(
                string: " \(spots)p",
                attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: secondaryColor]
            ))
        }

        label.attributedText = text
        label.sizeToFit()

        let padding: CGFloat = 12
        let height: CGFloat = 32
        container.frame = CGRect(x: 0, y: 0, width: label.frame.width + padding * 2, height: height)
        label.center = CGPoint(x: container.frame.width / 2, y: container.frame.height / 2)
        container.addSubview(label)

        return container
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let onSelect: ((String?) -> Void)?
        nonisolated(unsafe) let onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?
        nonisolated(unsafe) let onCameraIdle: ((_ lat: Double, _ lng: Double, _ zoom: Float) -> Void)?
        var markerToId: [GMSMarker: String] = [:]
        var selectedMarker: GMSMarker?
        weak var mapView: GMSMapView?
        var lastCenterLat: Double?
        var lastCenterLng: Double?
        var lastCenterZoom: Float?
        var lastListingIdsKey: String = ""
        var lastSelectedListingId: String?
        var lastVisitedIds: Set<String> = []
        var userMovedMap = false
        var debounceWorkItem: DispatchWorkItem?

        init(
            onSelect: ((String?) -> Void)?,
            onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?,
            onCameraIdle: ((_ lat: Double, _ lng: Double, _ zoom: Float) -> Void)? = nil
        ) {
            self.onSelect = onSelect
            self.onRegionChanged = onRegionChanged
            self.onCameraIdle = onCameraIdle
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let id = markerToId[marker] else { return false }
            selectedMarker = marker
            onSelect?(id)
            return true
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            selectedMarker = nil
            onSelect?(nil)
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                userMovedMap = true
                debounceWorkItem?.cancel()
            }
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            // Persister kamera-state (også om bruker ikke har pannet — får fitBounds-resultat etter første render)
            onCameraIdle?(position.target.latitude, position.target.longitude, position.zoom)

            guard userMovedMap else { return }
            userMovedMap = false

            let visibleRegion = mapView.projection.visibleRegion()
            let latDiff = abs(visibleRegion.nearLeft.latitude - visibleRegion.farRight.latitude)
            let radiusKm = max(latDiff * 111.0 / 2.0, 5)
            let lat = position.target.latitude
            let lng = position.target.longitude

            // Debounce 800ms using GCD
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onRegionChanged?(lat, lng, radiusKm)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
        }
    }
}
