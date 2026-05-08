import SwiftUI
import MapKit
import GooglePlaces

// MARK: - Initialization

/// Init kun GooglePlaces (autocomplete brukes fortsatt). MapKit krever ingen
/// API-nøkkel siden den er native-Apple. Tidligere versjoner brukte
/// `initializeGoogleMaps()` som registrerte både GMSServices + GMSPlacesClient
/// — den er nå byttet til denne, som kun registrerer Places.
func initializeMapServices() {
    let key = AppConfig.googleMapsAPIKey
    guard !key.isEmpty else {
        print("Google API key not set in AppConfig")
        return
    }
    GMSPlacesClient.provideAPIKey(key)
}

// MARK: - Tuno-farger som UIColor (gjenbrukt fra forrige Google-versjon)

private enum TunoColors {
    static let green = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1)
    static let darkGreen = UIColor(red: 0.18, green: 0.55, blue: 0.36, alpha: 1)
    static let textBlack = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
    static let visited = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1)
}

// MARK: - Map type helper

/// MapKit map-type wrapper. Brukes konsistent på tvers av kart-views.
extension MKMapType {
    static var tunoSatellite: MKMapType { .hybrid }
    static var tunoStandard: MKMapType { .standard }
}

// MARK: - Listing detail map (single-listing visning på annonse-detalj)

struct ListingMapView: UIViewRepresentable {
    let lat: Double
    let lng: Double
    var spotMarkers: [SpotMarker] = []
    var hideExactLocation: Bool = false
    var isSatellite: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = isSatellite ? .hybrid : .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator

        // Sentrer kamera
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let span = hideExactLocation
            ? MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            : MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)

        addAnnotations(to: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if mapView.mapType != (isSatellite ? .hybrid : .standard) {
            mapView.mapType = isSatellite ? .hybrid : .standard
        }
    }

    private func addAnnotations(to mapView: MKMapView, coordinator: Coordinator) {
        if hideExactLocation {
            // Privacy-sirkel rundt et omtrentlig senter
            let circle = MKCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: 500)
            mapView.addOverlay(circle)
        } else if !spotMarkers.isEmpty {
            for (i, spot) in spotMarkers.enumerated() {
                let annotation = NumberedSpotAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng),
                    number: i + 1
                )
                mapView.addAnnotation(annotation)
            }
        } else {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            mapView.addAnnotation(annotation)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let numbered = annotation as? NumberedSpotAnnotation {
                let id = "numbered-spot"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: numbered, reuseIdentifier: id)
                view.image = MapBubbleRenderer.numberedPin(number: numbered.number)
                view.centerOffset = CGPoint(x: 0, y: 0)
                view.canShowCallout = false
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = TunoColors.green.withAlphaComponent(0.15)
                renderer.strokeColor = TunoColors.green.withAlphaComponent(0.5)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Numbered spot annotation (for spot-markers og privacy-pins)

final class NumberedSpotAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let number: Int
    init(coordinate: CLLocationCoordinate2D, number: Int) {
        self.coordinate = coordinate
        self.number = number
    }
}

// MARK: - Search results map (multi-listing med pris-bobler + clustering)

struct SearchMapView: UIViewRepresentable {
    let listings: [Listing]
    var isSatellite: Bool = true
    var centerLat: Double?
    var centerLng: Double?
    /// Zoom uttrykkes som span-delta (mindre = nærmere). Konvertert fra Google's
    /// zoom-nivå via heuristikk i koordinatoren.
    var centerZoom: Float?
    var selectedListingId: String? = nil
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

    private static func readSavedCamera(searchKey: String) -> (lat: Double, lng: Double, span: Double)? {
        guard let data = UserDefaults.standard.dictionary(forKey: stateKey) else { return nil }
        guard let savedKey = data["key"] as? String, savedKey == searchKey else { return nil }
        guard let ts = data["ts"] as? Double, Date().timeIntervalSince1970 - ts < stateTTL else { return nil }
        guard let lat = data["lat"] as? Double, let lng = data["lng"] as? Double, let span = data["span"] as? Double else { return nil }
        return (lat, lng, span)
    }

    private static func saveCamera(searchKey: String, lat: Double, lng: Double, span: Double) {
        UserDefaults.standard.set([
            "key": searchKey,
            "lat": lat,
            "lng": lng,
            "span": span,
            "ts": Date().timeIntervalSince1970,
        ], forKey: stateKey)
    }

    /// Heuristikk: Google's zoom-nivå (1-20) → MKCoordinateSpan. Lavere zoom = bredere span.
    /// Brukes for å bevare API-en ved migrering.
    private static func spanForZoom(_ zoom: Float) -> Double {
        // Zoom 4 → ~30°, zoom 11 → ~0.4°, zoom 16 → ~0.013°
        return 360.0 / pow(2.0, Double(zoom))
    }

    private static func zoomForSpan(_ span: Double) -> Float {
        return Float(log2(360.0 / max(span, 0.0001)))
    }

    func makeCoordinator() -> Coordinator {
        let key = Self.searchKey(lat: centerLat, lng: centerLng, zoom: centerZoom)
        let saver: (Double, Double, Double) -> Void = { lat, lng, span in
            Self.saveCamera(searchKey: key, lat: lat, lng: lng, span: span)
        }
        return Coordinator(onSelect: onSelect, onRegionChanged: onRegionChanged, onCameraIdle: saver)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = isSatellite ? .hybrid : .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsPointsOfInterest = false
        mapView.delegate = context.coordinator

        let key = Self.searchKey(lat: centerLat, lng: centerLng, zoom: centerZoom)
        let saved = Self.readSavedCamera(searchKey: key)

        let lat = saved?.lat ?? centerLat ?? 64.5
        let lng = saved?.lng ?? centerLng ?? 14.0
        let span = saved?.span ?? Self.spanForZoom(centerZoom ?? (centerLat != nil ? 11 : 4))
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            ),
            animated: false
        )

        context.coordinator.mapView = mapView
        context.coordinator.lastCenterLat = centerLat
        context.coordinator.lastCenterLng = centerLng
        context.coordinator.lastCenterZoom = centerZoom
        context.coordinator.lastSelectedListingId = selectedListingId
        context.coordinator.lastVisitedIds = visitedIds

        addMarkers(to: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if mapView.mapType != (isSatellite ? .hybrid : .standard) {
            mapView.mapType = isSatellite ? .hybrid : .standard
        }

        let centerChanged = centerLat != context.coordinator.lastCenterLat
            || centerLng != context.coordinator.lastCenterLng
        let zoomChanged = centerZoom != context.coordinator.lastCenterZoom
        context.coordinator.lastCenterLat = centerLat
        context.coordinator.lastCenterLng = centerLng
        context.coordinator.lastCenterZoom = centerZoom

        let listingsKey = listings.compactMap { $0.lat != nil && $0.lng != nil ? $0.id : nil }.sorted().joined(separator: ",")
        if listingsKey != context.coordinator.lastListingIdsKey {
            // Full rebuild — listing-settet endret seg
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            context.coordinator.markerToId.removeAll()
            context.coordinator.markerToCluster.removeAll()
            context.coordinator.allAnnotations.removeAll()
            addMarkers(to: mapView, coordinator: context.coordinator, selectedId: selectedListingId)
            context.coordinator.lastListingIdsKey = listingsKey
            context.coordinator.lastSelectedListingId = selectedListingId
            context.coordinator.lastVisitedIds = visitedIds
        } else {
            // Kun selection eller visited har endret seg — oppdater pris-boble-bilder
            let visitedDiff = visitedIds.symmetricDifference(context.coordinator.lastVisitedIds)
            let selectionChanged = selectedListingId != context.coordinator.lastSelectedListingId
            if !visitedDiff.isEmpty || selectionChanged {
                var idsToUpdate: Set<String> = visitedDiff
                if selectionChanged {
                    if let prev = context.coordinator.lastSelectedListingId { idsToUpdate.insert(prev) }
                    if let curr = selectedListingId { idsToUpdate.insert(curr) }
                }
                for annotation in context.coordinator.allAnnotations {
                    let key = AnnotationKey(annotation)
                    guard let id = context.coordinator.markerToId[key], idsToUpdate.contains(id) else { continue }
                    guard let listing = listings.first(where: { $0.id == id }) else { continue }
                    if let annotationView = mapView.view(for: annotation) {
                        annotationView.image = MapBubbleRenderer.priceBubble(
                            listing: listing,
                            isVisited: visitedIds.contains(id),
                            isSelected: id == selectedListingId
                        )
                    }
                }
                context.coordinator.lastSelectedListingId = selectedListingId
                context.coordinator.lastVisitedIds = visitedIds
            }
        }

        if centerChanged, let lat = centerLat, let lng = centerLng {
            // Ved kun-pan: behold mapView's nåværende span. Ellers bruk centerZoom.
            let span: Double = zoomChanged
                ? Self.spanForZoom(centerZoom ?? 11)
                : mapView.region.span.latitudeDelta
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    private func addMarkers(to mapView: MKMapView, coordinator: Coordinator, selectedId: String? = nil) {
        let validListings = listings.filter { $0.lat != nil && $0.lng != nil }
        let activeSelectedId = selectedId ?? selectedListingId

        coordinator.allListingsForClustering = validListings

        Self.applyMarkers(
            to: mapView,
            listings: validListings,
            visited: visitedIds,
            selectedId: activeSelectedId,
            coordinator: coordinator
        )
    }

    static func applyMarkers(
        to mapView: MKMapView,
        listings: [Listing],
        visited: Set<String>,
        selectedId: String?,
        coordinator: Coordinator
    ) {
        let zoom = zoomForSpan(mapView.region.span.latitudeDelta)
        let clusters = clusterListings(listings, zoom: zoom)
        coordinator.lastClusterZoom = zoom

        for cluster in clusters {
            if cluster.listings.count == 1, let listing = cluster.listings.first {
                let annotation = ListingPriceAnnotation(
                    coordinate: cluster.center,
                    listing: listing,
                    isVisited: visited.contains(listing.id),
                    isSelected: selectedId == listing.id
                )
                mapView.addAnnotation(annotation)
                let key = AnnotationKey(annotation)
                coordinator.markerToId[key] = listing.id
                coordinator.markerToCluster[key] = cluster
                coordinator.allAnnotations.append(annotation)
            } else {
                let annotation = ClusterAnnotation(coordinate: cluster.center, count: cluster.listings.count)
                mapView.addAnnotation(annotation)
                let key = AnnotationKey(annotation)
                coordinator.markerToCluster[key] = cluster
                coordinator.allAnnotations.append(annotation)
            }
        }
    }

    static func clusterListings(_ listings: [Listing], zoom: Float) -> [MarkerCluster] {
        guard !listings.isEmpty else { return [] }
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

    struct MarkerCluster {
        let center: CLLocationCoordinate2D
        let listings: [Listing]
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let onSelect: ((String?) -> Void)?
        nonisolated(unsafe) let onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?
        nonisolated(unsafe) let onCameraIdle: ((_ lat: Double, _ lng: Double, _ span: Double) -> Void)?
        // MKAnnotation er ikke Hashable, men ObjectIdentifier på Coordinator-eide
        // class-instanser (ListingPriceAnnotation/ClusterAnnotation) er det.
        // Vi holder også en sterk referanse via map-key-arrayet under for å
        // unngå at annotation-objektet blir deallokert.
        var markerToId: [AnnotationKey: String] = [:]
        var markerToCluster: [AnnotationKey: MarkerCluster] = [:]
        var allAnnotations: [MKAnnotation] = []  // sterk referanse
        weak var mapView: MKMapView?
        var lastCenterLat: Double?
        var lastCenterLng: Double?
        var lastCenterZoom: Float?
        var lastListingIdsKey: String = ""
        var lastSelectedListingId: String?
        var lastVisitedIds: Set<String> = []
        var lastClusterZoom: Float = 0
        var allListingsForClustering: [Listing] = []
        var userMovedMap = false
        var debounceWorkItem: DispatchWorkItem?

        init(
            onSelect: ((String?) -> Void)?,
            onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?,
            onCameraIdle: ((_ lat: Double, _ lng: Double, _ span: Double) -> Void)? = nil
        ) {
            self.onSelect = onSelect
            self.onRegionChanged = onRegionChanged
            self.onCameraIdle = onCameraIdle
        }

        // MARK: Annotation views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let priceAnno = annotation as? ListingPriceAnnotation {
                let id = "price-bubble"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: priceAnno, reuseIdentifier: id)
                view.annotation = priceAnno
                view.image = MapBubbleRenderer.priceBubble(
                    listing: priceAnno.listing,
                    isVisited: priceAnno.isVisited,
                    isSelected: priceAnno.isSelected
                )
                view.canShowCallout = false
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            if let cluster = annotation as? ClusterAnnotation {
                let id = "cluster-bubble"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: cluster, reuseIdentifier: id)
                view.annotation = cluster
                view.image = MapBubbleRenderer.clusterBubble(count: cluster.count)
                view.canShowCallout = false
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            return nil
        }

        // MARK: Selection (tap)

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? AnyObject else { return }
            let key = AnnotationKey(annotation)

            // Cluster-tap: zoom inn
            if let cluster = markerToCluster[key], cluster.listings.count > 1 {
                let currentSpan = mapView.region.span.latitudeDelta
                let newSpan = max(currentSpan / 4.0, 0.001)
                let region = MKCoordinateRegion(
                    center: (annotation as! MKAnnotation).coordinate,
                    span: MKCoordinateSpan(latitudeDelta: newSpan, longitudeDelta: newSpan)
                )
                mapView.setRegion(region, animated: true)
                if let mkAnno = annotation as? MKAnnotation {
                    mapView.deselectAnnotation(mkAnno, animated: false)
                }
                return
            }

            if let id = markerToId[key] {
                onSelect?(id)
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            // Ikke automatisk null ut — brukeren kan velge en annen
        }

        // MARK: Region tracking ("Søk i dette området")

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // MKMapView trigger denne både på programmatisk og bruker-pan.
            // Vi vil bare reagere på bruker-pan, men MKMapView har ingen direkte
            // måte å skille — vi sjekker via UIPanGestureRecognizer i view-hierarkiet.
            if isUserGesture(mapView: mapView) {
                userMovedMap = true
                debounceWorkItem?.cancel()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Persister kamera-state
            let center = mapView.region.center
            let span = mapView.region.span.latitudeDelta
            onCameraIdle?(center.latitude, center.longitude, span)

            // Re-cluster hvis zoom har endret seg vesentlig
            let zoom = SearchMapView.zoomForSpan(span)
            if abs(zoom - lastClusterZoom) >= 0.5 {
                lastClusterZoom = zoom
                rebuildClusters()
            }

            guard userMovedMap else { return }
            userMovedMap = false

            let radiusKm = max(span * 111.0 / 2.0, 5)
            let lat = center.latitude
            let lng = center.longitude

            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onRegionChanged?(lat, lng, radiusKm)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
        }

        private func isUserGesture(mapView: MKMapView) -> Bool {
            // MKMapView's first subview er en UIView som inneholder gesture
            // recognizers. Hvis noen er .began/.changed/.ended antar vi bruker.
            for view in mapView.subviews {
                for gesture in view.gestureRecognizers ?? [] {
                    if gesture.state == .began || gesture.state == .changed || gesture.state == .ended {
                        return true
                    }
                }
            }
            return false
        }

        private func rebuildClusters() {
            guard let mapView else { return }
            let visited = lastVisitedIds
            let selectedId = lastSelectedListingId

            // Fjern alle annotation-er bortsett fra MKUserLocation
            let toRemove = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(toRemove)
            markerToId.removeAll()
            markerToCluster.removeAll()
            allAnnotations.removeAll()

            SearchMapView.applyMarkers(
                to: mapView,
                listings: allListingsForClustering,
                visited: visited,
                selectedId: selectedId,
                coordinator: self
            )
        }
    }
}

// MARK: - Annotations

/// Stable key for annotation-dictionaries siden MKAnnotation ikke er Hashable.
struct AnnotationKey: Hashable {
    private let id: ObjectIdentifier
    init(_ annotation: AnyObject) { self.id = ObjectIdentifier(annotation) }
}

final class ListingPriceAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let listing: Listing
    let isVisited: Bool
    let isSelected: Bool

    init(coordinate: CLLocationCoordinate2D, listing: Listing, isVisited: Bool, isSelected: Bool) {
        self.coordinate = coordinate
        self.listing = listing
        self.isVisited = isVisited
        self.isSelected = isSelected
    }
}

final class ClusterAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let count: Int

    init(coordinate: CLLocationCoordinate2D, count: Int) {
        self.coordinate = coordinate
        self.count = count
    }
}

// MARK: - Bubble rendering (gjenbruk-logikk fra forrige Google-versjon)

enum MapBubbleRenderer {
    /// Cache av pris-bobler. Lik bobble (samme pris/suffix/spots/state) gjenbrukes.
    nonisolated(unsafe) private static var priceBubbleCache: [String: UIImage] = [:]
    nonisolated(unsafe) private static var clusterBubbleCache: [Int: UIImage] = [:]
    nonisolated(unsafe) private static var numberedPinCache: [Int: UIImage] = [:]

    /// Pris-boble i Airbnb-stil med 3 tilstander: default/visited/selected.
    /// Returnerer UIImage som kan settes som annotation.image.
    static func priceBubble(listing: Listing, isVisited: Bool, isSelected: Bool) -> UIImage {
        let h = listing.headlinePrice
        let priceText = h.map { "\($0.price) kr" } ?? "—"
        let suffix = h?.suffix ?? ""
        let spots = listing.spots ?? 1
        let cacheKey = "\(priceText)|\(suffix)|\(spots)|\(isSelected)|\(isVisited)"
        if let cached = priceBubbleCache[cacheKey] { return cached }

        let textColor: UIColor = isSelected ? .white : TunoColors.textBlack
        let secondaryColor = textColor.withAlphaComponent(0.65)

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
            TunoColors.darkGreen.setFill()
            shadowPath.fill()

            // Hovedpille
            let mainRect = CGRect(x: 0, y: 0, width: width, height: height)
            let mainPath = UIBezierPath(roundedRect: mainRect, cornerRadius: height / 2)
            if isSelected {
                TunoColors.textBlack.setFill()
            } else if isVisited {
                TunoColors.visited.setFill()
            } else {
                UIColor.white.setFill()
            }
            mainPath.fill()
            // Ring
            ctx.cgContext.setStrokeColor((isVisited && !isSelected ? TunoColors.green.withAlphaComponent(0.7) : TunoColors.green).cgColor)
            ctx.cgContext.setLineWidth(2)
            let ringPath = UIBezierPath(roundedRect: mainRect.insetBy(dx: 1, dy: 1), cornerRadius: (height - 2) / 2)
            ringPath.stroke()

            let textOrigin = CGPoint(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2
            )
            text.draw(at: textOrigin)
        }
        priceBubbleCache[cacheKey] = image
        if priceBubbleCache.count > 1000 { priceBubbleCache.removeAll(keepingCapacity: true) }
        return image
    }

    /// Cluster-marker — rund grønn pille med antall annonser.
    static func clusterBubble(count: Int) -> UIImage {
        if let cached = clusterBubbleCache[count] { return cached }

        let scale: CGFloat = count >= 100 ? 1.25 : count >= 25 ? 1.1 : 1.0
        let diameter: CGFloat = 42 * scale
        let stackOffset: CGFloat = 2.5
        let size = CGSize(width: diameter, height: diameter + stackOffset)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(TunoColors.darkGreen.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: stackOffset, width: diameter, height: diameter))
            let mainRect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ctx.cgContext.setFillColor(TunoColors.green.cgColor)
            ctx.cgContext.fillEllipse(in: mainRect)
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(2.5)
            ctx.cgContext.strokeEllipse(in: mainRect.insetBy(dx: 1.25, dy: 1.25))
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

    /// Nummerert pin (brukes for spot-markers på listing-detalj).
    static func numberedPin(number: Int) -> UIImage {
        if let cached = numberedPinCache[number] { return cached }

        let size: CGFloat = 30
        let imgSize = CGSize(width: size + 4, height: size + 4)
        let renderer = UIGraphicsImageRenderer(size: imgSize)
        let image = renderer.image { ctx in
            // Hvit ring rundt sirkel
            let circleRect = CGRect(x: 2, y: 2, width: size, height: size)
            ctx.cgContext.setFillColor(TunoColors.green.cgColor)
            ctx.cgContext.fillEllipse(in: circleRect)
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.strokeEllipse(in: circleRect)

            let label = "\(number)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textRect = CGRect(
                x: (imgSize.width - textSize.width) / 2,
                y: (imgSize.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
        numberedPinCache[number] = image
        return image
    }
}
