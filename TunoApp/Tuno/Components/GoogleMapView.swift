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
                    marker.icon = Self.createPriceBubble(
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

        coordinator.allListingsForClustering = validListings
        coordinator.lastClusterZoom = mapView.camera.zoom

        // Sett opp et re-cluster-callback som idleAt kan trigge
        let visited = visitedIds
        let onSelectCallback = onSelect
        let onSelectListingId: String? = activeSelectedId
        coordinator.clusterRebuildBlock = { [weak coordinator, weak mapView] in
            guard let coordinator, let mapView else { return }
            // Fjern eksisterende markers, sett inn nye basert på nytt zoom-nivå
            for (marker, _) in coordinator.markerToCluster {
                marker.map = nil
            }
            coordinator.markerToCluster.removeAll()
            coordinator.markerToId.removeAll()
            Self.applyMarkers(
                to: mapView,
                listings: coordinator.allListingsForClustering,
                visited: visited,
                selectedId: onSelectListingId,
                coordinator: coordinator
            )
            _ = onSelectCallback // capture
        }

        Self.applyMarkers(
            to: mapView,
            listings: validListings,
            visited: visited,
            selectedId: activeSelectedId,
            coordinator: coordinator
        )
    }

    /// Beregn clusters fra current zoom og legg dem på kartet. Trygg å kalle igjen
    /// — kalleren rydder eksisterende markers først.
    static func applyMarkers(
        to mapView: GMSMapView,
        listings: [Listing],
        visited: Set<String>,
        selectedId: String?,
        coordinator: Coordinator
    ) {
        let zoom = mapView.camera.zoom
        let clusters = clusterListings(listings, zoom: zoom)
        for cluster in clusters {
            let marker = GMSMarker()
            marker.position = cluster.center
            if cluster.listings.count == 1, let listing = cluster.listings.first {
                marker.icon = createPriceBubble(
                    listing: listing,
                    isVisited: visited.contains(listing.id),
                    isSelected: selectedId == listing.id
                )
                coordinator.markerToId[marker] = listing.id
            } else {
                marker.icon = createClusterBubble(count: cluster.listings.count)
            }
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView
            coordinator.markerToCluster[marker] = cluster
        }
    }

    /// Grupper listings i grid-celler basert på zoom-nivå. Cellen er liten nok
    /// til at flesteparten av bobler vises individuelt — clusters dukker kun
    /// opp når flere annonser faktisk overlapper visuelt.
    static func clusterListings(_ listings: [Listing], zoom: Float) -> [MarkerCluster] {
        guard !listings.isEmpty else { return [] }
        // Mercator: én verden er 256 piksler ved zoom 0. Ved zoom Z er det 256 * 2^Z piksler
        // for 360°. Cellsize tilsvarer ca. boble-bredden (~50 px) så annonser som
        // *faktisk* overlapper grupperes, ikke bare nære.
        let pixelsPerDegree = (256.0 * pow(2.0, Double(zoom))) / 360.0
        let cellPixels = 35.0
        let cellSizeDeg = cellPixels / max(pixelsPerDegree, 0.000001)

        var bins: [String: [Listing]] = [:]
        for listing in listings {
            guard let lat = listing.lat, let lng = listing.lng else { continue }
            let latBin = Int(floor(lat / cellSizeDeg))
            let lngBin = Int(floor(lng / cellSizeDeg))
            let key = "\(latBin),\(lngBin)"
            bins[key, default: []].append(listing)
        }

        return bins.values.map { listingsInBin in
            let lat = listingsInBin.compactMap { $0.lat }.reduce(0, +) / Double(listingsInBin.count)
            let lng = listingsInBin.compactMap { $0.lng }.reduce(0, +) / Double(listingsInBin.count)
            return MarkerCluster(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                listings: listingsInBin
            )
        }
    }

    /// Cluster-marker — rund grønn pille med antall annonser. Brukes når
    /// flere listings overlapper visuelt på samme zoom-nivå.
    /// Returnerer UIImage (ikke UIView) — Google Maps SDK rendrer images mye
    /// raskere enn iconView (som krever full UIView-stack per markør).
    static func createClusterBubble(count: Int) -> UIImage {
        if let cached = clusterBubbleCache[count] { return cached }

        let tunoGreen = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1)
        let darkGreen = UIColor(red: 0.18, green: 0.55, blue: 0.36, alpha: 1)

        let scale: CGFloat = count >= 100 ? 1.25 : count >= 25 ? 1.1 : 1.0
        let diameter: CGFloat = 42 * scale
        let stackOffset: CGFloat = 2.5
        let size = CGSize(width: diameter, height: diameter + stackOffset)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Skygge bakerst (mørk grønn pille)
            ctx.cgContext.setFillColor(darkGreen.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: stackOffset, width: diameter, height: diameter))
            // Hovedpille (Tuno-grønn fyll, hvit ring)
            let mainRect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ctx.cgContext.setFillColor(tunoGreen.cgColor)
            ctx.cgContext.fillEllipse(in: mainRect)
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(2.5)
            ctx.cgContext.strokeEllipse(in: mainRect.insetBy(dx: 1.25, dy: 1.25))
            // Tekst sentrert
            let label = "\(count)"
            let font = UIFont.systemFont(ofSize: count >= 100 ? 13 : 14, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textRect = CGRect(
                x: (diameter - textSize.width) / 2,
                y: (diameter - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
        clusterBubbleCache[count] = image
        return image
    }

    /// Cache av cluster-bobler per count. UIImage er thread-safe og
    /// rendring av samme telling er identisk → kun lager én gang per count.
    private static var clusterBubbleCache: [Int: UIImage] = [:]

    struct MarkerCluster {
        let center: CLLocationCoordinate2D
        let listings: [Listing]
    }

    /// Bygger en pris-boble i Airbnb-stil med 3 tilstander:
    /// - **Default** (hvit + svart tekst): nøytral, ikke besøkt
    /// - **Visited** (lys grå + svart tekst): brukeren har trykket på denne før
    /// - **Selected** (svart + hvit tekst): aktivt valgt — kort vises
    /// Returnerer UIImage (ikke UIView) — Google Maps Marker.icon er ~10x raskere
    /// enn Marker.iconView, fordi GMS slipper å håndtere full UIView-hierarchy
    /// per markør. Cache resultatet per (price+suffix+state) så vi unngår å
    /// rendre samme bobble flere ganger.
    static func createPriceBubble(listing: Listing, isVisited: Bool, isSelected: Bool) -> UIImage {
        let h = listing.headlinePrice
        let priceText = h.map { "\($0.price) kr" } ?? "—"
        let suffix = h?.suffix ?? ""
        let spots = listing.spots ?? 1
        let cacheKey = "\(priceText)|\(suffix)|\(spots)|\(isSelected)|\(isVisited)"
        if let cached = priceBubbleCache[cacheKey] { return cached }

        let tunoGreen = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1)
        let darkGreen = UIColor(red: 0.18, green: 0.55, blue: 0.36, alpha: 1)
        let textColor: UIColor = isSelected
            ? .white
            : UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
        let secondaryColor = textColor.withAlphaComponent(0.65)

        // Bygg attributed string først for å måle bredden
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(
            string: priceText,
            attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: textColor]
        ))
        if !suffix.isEmpty {
            text.append(NSAttributedString(
                string: suffix,
                attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: secondaryColor]
            ))
        }
        if spots > 1 {
            text.append(NSAttributedString(
                string: " · \(spots)p",
                attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: secondaryColor]
            ))
        }
        let textSize = text.size()

        let padding: CGFloat = 14
        let height: CGFloat = 36
        let width = ceil(textSize.width) + padding * 2
        let stackOffset: CGFloat = 2.5
        let size = CGSize(width: width, height: height + stackOffset)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Skygge bakerst (mørk grønn pille)
            let shadowRect = CGRect(x: 0, y: stackOffset, width: width, height: height)
            let shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: height / 2)
            darkGreen.setFill()
            shadowPath.fill()

            // Hovedpille
            let mainRect = CGRect(x: 0, y: 0, width: width, height: height)
            let mainPath = UIBezierPath(roundedRect: mainRect, cornerRadius: height / 2)
            if isSelected {
                UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1).setFill()
            } else if isVisited {
                UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1).setFill()
            } else {
                UIColor.white.setFill()
            }
            mainPath.fill()
            // Ring
            ctx.cgContext.setStrokeColor((isVisited && !isSelected ? tunoGreen.withAlphaComponent(0.7) : tunoGreen).cgColor)
            ctx.cgContext.setLineWidth(2)
            let ringPath = UIBezierPath(roundedRect: mainRect.insetBy(dx: 1, dy: 1), cornerRadius: (height - 2) / 2)
            ringPath.stroke()

            // Tekst sentrert i hovedpillen
            let textOrigin = CGPoint(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2
            )
            text.draw(at: textOrigin)
        }
        priceBubbleCache[cacheKey] = image
        // Begrens cache så minnet ikke vokser ubegrenset
        if priceBubbleCache.count > 1000 { priceBubbleCache.removeAll(keepingCapacity: true) }
        return image
    }

    /// Cache av pris-bobler. Lik bobble (samme pris/suffix/spots/state) gjenbrukes.
    private static var priceBubbleCache: [String: UIImage] = [:]

    class Coordinator: NSObject, GMSMapViewDelegate {
        let onSelect: ((String?) -> Void)?
        nonisolated(unsafe) let onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?
        nonisolated(unsafe) let onCameraIdle: ((_ lat: Double, _ lng: Double, _ zoom: Float) -> Void)?
        var markerToId: [GMSMarker: String] = [:]
        var markerToCluster: [GMSMarker: MarkerCluster] = [:]
        var selectedMarker: GMSMarker?
        weak var mapView: GMSMapView?
        var lastCenterLat: Double?
        var lastCenterLng: Double?
        var lastCenterZoom: Float?
        var lastListingIdsKey: String = ""
        var lastSelectedListingId: String?
        var lastVisitedIds: Set<String> = []
        var lastClusterZoom: Float = 0
        var allListingsForClustering: [Listing] = []
        var clusterRebuildBlock: (() -> Void)?
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
            // Cluster med flere annonser → zoom inn til senter for å se enkelte bobler
            if let cluster = markerToCluster[marker], cluster.listings.count > 1 {
                let targetZoom = min(mapView.camera.zoom + 2, 18)
                let camera = GMSCameraPosition(target: marker.position, zoom: targetZoom)
                mapView.animate(to: camera)
                return true
            }
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

            // Re-cluster hvis zoom har endret seg vesentlig (>= 0.5 zoom-stopp)
            // — bobler omfordeles så solo og clusters holder seg konsistente.
            if abs(position.zoom - lastClusterZoom) >= 0.5 {
                lastClusterZoom = position.zoom
                clusterRebuildBlock?()
            }

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
