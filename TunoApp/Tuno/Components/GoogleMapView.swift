import SwiftUI
import GoogleMaps

// Initialize Google Maps SDK — call once at app startup
func initializeGoogleMaps() {
    let key = AppConfig.googleMapsAPIKey
    guard !key.isEmpty else {
        print("⚠️ Google Maps API key not set in AppConfig")
        return
    }
    GMSServices.provideAPIKey(key)
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
            // Show approximate circle
            let circle = GMSCircle(position: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: 500)
            circle.fillColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 0.1)
            circle.strokeColor = UIColor(red: 0.102, green: 0.310, blue: 0.839, alpha: 0.3)
            circle.strokeWidth = 2
            circle.map = mapView
        } else if !spotMarkers.isEmpty {
            // Show numbered spot markers
            for (i, spot) in spotMarkers.enumerated() {
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng)
                marker.iconView = createNumberedPin(number: i + 1)
                marker.map = mapView
            }
        } else {
            // Single pin
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
    var onSelect: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 64.5, longitude: 14, zoom: 4)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = .hybrid
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator

        addMarkers(to: mapView)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()
        addMarkers(to: mapView)
    }

    private func addMarkers(to mapView: GMSMapView) {
        let validListings = listings.filter { $0.lat != nil && $0.lng != nil }
        guard !validListings.isEmpty else { return }

        let bounds = validListings.reduce(GMSCoordinateBounds()) { bounds, listing in
            bounds.includingCoordinate(CLLocationCoordinate2D(latitude: listing.lat!, longitude: listing.lng!))
        }

        for listing in validListings {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: listing.lat!, longitude: listing.lng!)
            marker.iconView = createPriceBubble(listing: listing)
            marker.userData = listing.id
            marker.map = mapView
        }

        let update = GMSCameraUpdate.fit(bounds, withPadding: 50)
        mapView.animate(with: update)
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

        if listing.instantBooking == true {
            let bolt = NSAttributedString(string: "⚡", attributes: [.font: UIFont.systemFont(ofSize: 11)])
            text.append(bolt)
        }

        let price = NSAttributedString(
            string: "\(listing.price ?? 0) kr",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
            ]
        )
        text.append(price)

        label.attributedText = text
        label.sizeToFit()

        let padding: CGFloat = 12
        container.frame = CGRect(x: 0, y: 0, width: label.frame.width + padding * 2, height: 32)
        label.center = CGPoint(x: container.frame.width / 2, y: container.frame.height / 2)
        container.addSubview(label)

        return container
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        let onSelect: ((String) -> Void)?

        init(onSelect: ((String) -> Void)?) {
            self.onSelect = onSelect
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let id = marker.userData as? String {
                onSelect?(id)
            }
            return true
        }
    }
}
