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

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: lat,
            longitude: lng,
            zoom: hideExactLocation ? 14 : 17
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = .hybrid
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false

        if hideExactLocation {
            let circle = GMSCircle(position: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: 500)
            circle.fillColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 0.1)
            circle.strokeColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 0.3)
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

    func updateUIView(_ mapView: GMSMapView, context: Context) {}

    private func createNumberedPin(number: Int) -> UIView {
        let size: CGFloat = 30
        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.backgroundColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 1)
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
    var onSelect: ((String?) -> Void)? = nil
    var onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onRegionChanged: onRegionChanged)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let lat = centerLat ?? 64.5
        let lng = centerLng ?? 14.0
        let zoom: Float = centerZoom ?? (centerLat != nil ? 11 : 4)
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

        addMarkers(to: mapView, coordinator: context.coordinator)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.mapType = isSatellite ? .hybrid : .normal

        // Check if center changed (new place search or "my location")
        let centerChanged = centerLat != context.coordinator.lastCenterLat || centerLng != context.coordinator.lastCenterLng
        context.coordinator.lastCenterLat = centerLat
        context.coordinator.lastCenterLng = centerLng

        // Update markers (don't move camera unless center explicitly changed)
        mapView.clear()
        context.coordinator.markerToId.removeAll()
        addMarkers(to: mapView, coordinator: context.coordinator)

        if centerChanged, let lat = centerLat, let lng = centerLng {
            let zoom: Float = centerZoom ?? 11
            let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: zoom)
            mapView.animate(to: camera)
        }
    }

    private func addMarkers(to mapView: GMSMapView, coordinator: Coordinator) {
        let validListings = listings.filter { $0.lat != nil && $0.lng != nil }

        for listing in validListings {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: listing.lat!, longitude: listing.lng!)
            marker.iconView = createPriceBubble(listing: listing)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView
            coordinator.markerToId[marker] = listing.id
        }
    }

    private func createPriceBubble(listing: Listing) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.18
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4

        let label = UILabel()
        let text = NSMutableAttributedString()
        let textColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)

        if listing.instantBooking == true {
            text.append(NSAttributedString(string: "\u{26A1}", attributes: [.font: UIFont.systemFont(ofSize: 11)]))
        }

        text.append(NSAttributedString(
            string: "\(listing.displayPriceText) kr",
            attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: textColor]
        ))

        let spots = listing.spots ?? 1
        if spots > 1 {
            text.append(NSAttributedString(
                string: " \(spots)p",
                attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: textColor.withAlphaComponent(0.5)]
            ))
        }

        label.attributedText = text
        label.sizeToFit()

        let padding: CGFloat = 12
        container.frame = CGRect(x: 0, y: 0, width: label.frame.width + padding * 2, height: 32)
        label.center = CGPoint(x: container.frame.width / 2, y: container.frame.height / 2)
        container.addSubview(label)

        return container
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let onSelect: ((String?) -> Void)?
        nonisolated(unsafe) let onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?
        var markerToId: [GMSMarker: String] = [:]
        var selectedMarker: GMSMarker?
        weak var mapView: GMSMapView?
        var lastCenterLat: Double?
        var lastCenterLng: Double?
        var userMovedMap = false
        var debounceWorkItem: DispatchWorkItem?

        init(onSelect: ((String?) -> Void)?, onRegionChanged: ((_ lat: Double, _ lng: Double, _ radiusKm: Double) -> Void)?) {
            self.onSelect = onSelect
            self.onRegionChanged = onRegionChanged
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
