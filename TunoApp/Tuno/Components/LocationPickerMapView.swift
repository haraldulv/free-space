import SwiftUI
import MapKit

/// Interaktivt kart-view med hovedposisjon + nummererte plass-pinner.
/// I `isSpotMode = true`: tap på kartet legger til en ny pin (opp til `maxSpots`).
/// I `isSpotMode = false`: tap flytter hovedposisjonen.
/// Hovedmarker og spot-markers er draggable.
struct LocationPickerMapView: UIViewRepresentable {
    @Binding var lat: Double
    @Binding var lng: Double
    @Binding var spotMarkers: [SpotMarker]
    var isSpotMode: Bool
    var maxSpots: Int = 0
    var updateTrigger: UUID
    var onMaxReached: (() -> Void)? = nil
    var mainMarkerDraggable: Bool = true
    /// Kart-type — satellitt (.hybrid) som default, men kan toggles til vanlig (.standard).
    var mapType: MKMapType = .hybrid

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = mapType
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsPointsOfInterest = false
        mapView.delegate = context.coordinator

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
        mapView.setRegion(region, animated: false)

        // Tap-recognizer for å legge til/flytte pinner
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        mapView.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        context.coordinator.mapView = mapView
        context.coordinator.latBinding = $lat
        context.coordinator.lngBinding = $lng
        context.coordinator.spotMarkersBinding = $spotMarkers
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached
        context.coordinator.mainMarkerDraggable = mainMarkerDraggable

        addAnnotations(to: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.isSpotMode = isSpotMode
        context.coordinator.maxSpots = maxSpots
        context.coordinator.onMaxReached = onMaxReached
        context.coordinator.mainMarkerDraggable = mainMarkerDraggable

        if mapView.mapType != mapType { mapView.mapType = mapType }

        if context.coordinator.lastTrigger != updateTrigger {
            context.coordinator.lastTrigger = updateTrigger
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            )
            mapView.setRegion(region, animated: true)
        }

        let signature = MarkerSignature(lat: lat, lng: lng, spots: spotMarkers)
        if context.coordinator.lastSignature != signature {
            context.coordinator.lastSignature = signature
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            context.coordinator.mainAnnotation = nil
            context.coordinator.spotAnnotations.removeAll()
            addAnnotations(to: mapView, coordinator: context.coordinator)
        }
    }

    private func addAnnotations(to mapView: MKMapView, coordinator: Coordinator) {
        // Hovedmarker (default rød pin via MKMarkerAnnotationView)
        let main = MainPositionAnnotation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        mapView.addAnnotation(main)
        coordinator.mainAnnotation = main

        for (i, spot) in spotMarkers.enumerated() {
            let annotation = SpotPickerAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lng),
                index: i
            )
            mapView.addAnnotation(annotation)
            coordinator.spotAnnotations[ObjectIdentifier(annotation)] = i
        }
    }

    struct MarkerSignature: Equatable {
        let lat: Double
        let lng: Double
        let spots: [SpotKey]

        struct SpotKey: Equatable {
            let id: String?
            let lat: Double
            let lng: Double
        }

        init(lat: Double, lng: Double, spots: [SpotMarker]) {
            self.lat = lat
            self.lng = lng
            self.spots = spots.map { SpotKey(id: $0.id, lat: $0.lat, lng: $0.lng) }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        weak var mapView: MKMapView?
        weak var tapGesture: UITapGestureRecognizer?
        var mainAnnotation: MainPositionAnnotation?
        var spotAnnotations: [ObjectIdentifier: Int] = [:]
        var lastTrigger: UUID?
        var lastSignature: MarkerSignature?

        nonisolated(unsafe) var isSpotMode = false
        nonisolated(unsafe) var maxSpots = 0
        nonisolated(unsafe) var mainMarkerDraggable: Bool = true
        nonisolated(unsafe) var latBinding: Binding<Double>?
        nonisolated(unsafe) var lngBinding: Binding<Double>?
        nonisolated(unsafe) var spotMarkersBinding: Binding<[SpotMarker]>?
        nonisolated(unsafe) var onMaxReached: (() -> Void)?

        // MARK: Annotation views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let main = annotation as? MainPositionAnnotation {
                let id = "main-pin"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: main, reuseIdentifier: id)
                view.annotation = main
                view.markerTintColor = .red
                view.canShowCallout = false
                view.isDraggable = mainMarkerDraggable
                return view
            }

            if let spot = annotation as? SpotPickerAnnotation {
                let id = "spot-pin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: spot, reuseIdentifier: id)
                view.annotation = spot
                view.image = MapBubbleRenderer.numberedPin(number: spot.index + 1)
                view.canShowCallout = false
                view.isDraggable = true
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            return nil
        }

        // MARK: Drag end

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            guard newState == .ending else { return }
            guard let annotation = view.annotation else { return }
            view.dragState = .none

            if annotation is MainPositionAnnotation {
                latBinding?.wrappedValue = annotation.coordinate.latitude
                lngBinding?.wrappedValue = annotation.coordinate.longitude
            } else if let spot = annotation as? SpotPickerAnnotation {
                guard let binding = spotMarkersBinding, spot.index < binding.wrappedValue.count else { return }
                binding.wrappedValue[spot.index].lat = annotation.coordinate.latitude
                binding.wrappedValue[spot.index].lng = annotation.coordinate.longitude
            }
        }

        // MARK: Tap-to-add / tap-to-move

        @MainActor
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView else { return }
            let point = gesture.location(in: mapView)
            // Hvis tap traff en eksisterende annotation, la den selv håndtere det
            if let hitView = mapView.hitTest(point, with: nil),
               hitView is MKAnnotationView || (hitView.superview is MKAnnotationView) {
                return
            }
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

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

        // UIGestureRecognizerDelegate — ikke konsumer tap når marker dras
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

// MARK: - Annotation typer

final class MainPositionAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

final class SpotPickerAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
    }
}
