import SwiftUI
import GoogleMaps

/// Interaktivt Google Maps-view med hovedposisjon + nummererte plass-pinner.
/// I `isSpotMode = true`: tap på kartet legger til en ny pin (opp til `maxSpots`).
/// I `isSpotMode = false`: tap flytter hovedposisjonen.
struct LocationPickerMapView: UIViewRepresentable {
    @Binding var lat: Double
    @Binding var lng: Double
    @Binding var spotMarkers: [SpotMarker]
    var isSpotMode: Bool
    var maxSpots: Int = 0
    var updateTrigger: UUID
    var onMaxReached: (() -> Void)? = nil
    var mainMarkerDraggable: Bool = true
    /// Kart-type — satellitt (.hybrid) som default, men kan toggles til vanlig (.normal).
    var mapType: GMSMapViewType = .hybrid

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: 17)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.mapType = mapType
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        context.coordinator.latBinding = $lat
        context.coordinator.lngBinding = $lng
        context.coordinator.spotMarkersBinding = $spotMarkers
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached

        addMarkers(to: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached
        if mapView.mapType != mapType { mapView.mapType = mapType }

        if context.coordinator.lastTrigger != updateTrigger {
            context.coordinator.lastTrigger = updateTrigger
            let camera = GMSCameraPosition(latitude: lat, longitude: lng, zoom: 17)
            mapView.animate(to: camera)
        }

        mapView.clear()
        context.coordinator.mainMarker = nil
        context.coordinator.spotMarkerMap.removeAll()
        addMarkers(to: mapView, coordinator: context.coordinator)
    }

    private func addMarkers(to mapView: GMSMapView, coordinator: Coordinator) {
        let main = GMSMarker()
        main.position = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        main.isDraggable = mainMarkerDraggable
        main.title = "Hovedposisjon"
        main.map = mapView
        coordinator.mainMarker = main

        for (i, spot) in spotMarkers.enumerated() {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng)
            marker.isDraggable = true
            marker.iconView = createNumberedPin(number: i + 1)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView
            coordinator.spotMarkerMap[marker] = i
        }
    }

    private func createNumberedPin(number: Int) -> UIView {
        let size: CGFloat = 30
        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.backgroundColor = UIColor(red: 0.275, green: 0.757, blue: 0.522, alpha: 1) // #46C185
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

    class Coordinator: NSObject, GMSMapViewDelegate {
        weak var mapView: GMSMapView?
        var mainMarker: GMSMarker?
        var spotMarkerMap: [GMSMarker: Int] = [:]
        var lastTrigger: UUID?

        nonisolated(unsafe) var isSpotMode = false
        nonisolated(unsafe) var maxSpots = 0
        nonisolated(unsafe) var latBinding: Binding<Double>?
        nonisolated(unsafe) var lngBinding: Binding<Double>?
        nonisolated(unsafe) var spotMarkersBinding: Binding<[SpotMarker]>?
        nonisolated(unsafe) var onMaxReached: (() -> Void)?

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if isSpotMode {
                let count = spotMarkersBinding?.wrappedValue.count ?? 0
                if maxSpots > 0 && count >= maxSpots {
                    onMaxReached?()
                    return
                }
                let newSpot = SpotMarker(
                    id: UUID().uuidString.lowercased(),
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    label: "Plass \(count + 1)",
                    description: nil,
                    price: nil,
                    vehicleMaxLength: nil,
                    vehicleType: nil,
                    extras: nil,
                    blockedDates: nil,
                    checkinMessage: nil,
                    images: nil
                )
                spotMarkersBinding?.wrappedValue.append(newSpot)
                if maxSpots > 0 && count + 1 >= maxSpots {
                    onMaxReached?()
                }
            } else {
                latBinding?.wrappedValue = coordinate.latitude
                lngBinding?.wrappedValue = coordinate.longitude
            }
        }

        func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
            if marker === mainMarker {
                latBinding?.wrappedValue = marker.position.latitude
                lngBinding?.wrappedValue = marker.position.longitude
            } else if let index = spotMarkerMap[marker] {
                guard let binding = spotMarkersBinding, index < binding.wrappedValue.count else { return }
                // Bevar ALLE eksisterende felt (description, vehicleMaxLength,
                // vehicleType, extras osv) — bare oppdater lat/lng.
                binding.wrappedValue[index].lat = marker.position.latitude
                binding.wrappedValue[index].lng = marker.position.longitude
            }
        }
    }
}
