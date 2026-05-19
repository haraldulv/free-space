import Foundation
import GooglePlaces

struct PlacePrediction: Identifiable {
    let id: String
    let description: String
    let mainText: String
    let secondaryText: String
}

struct PlaceDetail {
    let lat: Double
    let lng: Double
    let name: String
    /// Gateadresse + nummer parset fra address components (route + street_number).
    /// Kan være tom hvis Google ikke returnerer dem (sjeldne adresser).
    let streetAddress: String?
    /// Bare gatenavnet (route), uten husnummer. Brukes til to-felts adresse-UI.
    let street: String?
    /// Bare husnummeret (street_number). Kan være nil for sjeldne adresser.
    let houseNumber: String?
    /// Postnummer (locality.postal_code).
    let postalCode: String?
    /// Poststed / by (locality eller postal_town).
    let city: String?
    /// Region / fylke (administrative_area_level_1).
    let region: String?
    /// Google's anbefalte visningsområde for stedet. PoIs som "Solli plass" har
    /// kvartal-nivå viewport; byer/regioner har større. Brukes for å sette
    /// nøyaktig zoom-nivå på kartet i stedet for fast zoom=11 (TU-83).
    let viewport: PlaceViewport?
}

/// Geografisk bounding box (NE/SW-hjørner) fra Google Places.
struct PlaceViewport {
    let neLat: Double
    let neLng: Double
    let swLat: Double
    let swLng: Double
}

@MainActor
final class PlacesService: ObservableObject {
    @Published var predictions: [PlacePrediction] = []

    private let client = GMSPlacesClient.shared()
    private var searchTask: Task<Void, Never>?
    private var sessionToken = GMSAutocompleteSessionToken()

    func autocomplete(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            predictions = []
            return
        }

        searchTask = Task {
            // Debounce 250ms
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let filter = GMSAutocompleteFilter()
            filter.countries = ["no"]

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                client.findAutocompletePredictions(
                    fromQuery: query,
                    filter: filter,
                    sessionToken: sessionToken
                ) { [weak self] results, error in
                    Task { @MainActor in
                        guard let self else {
                            continuation.resume()
                            return
                        }
                        if let results {
                            self.predictions = results.map { result in
                                PlacePrediction(
                                    id: result.placeID,
                                    description: result.attributedFullText.string,
                                    mainText: result.attributedPrimaryText.string,
                                    secondaryText: result.attributedSecondaryText?.string ?? ""
                                )
                            }
                        } else if let error {
                            print("Places autocomplete error: \(error.localizedDescription)")
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    func getPlaceDetail(placeId: String) async -> PlaceDetail? {
        // .addressComponents gir oss tilgang til street_number, route, postal_code,
        // locality og administrative_area_level_1 — som vi trenger for å auto-
        // fylle postnummer + poststed i wizard og host-onboarding.
        // .viewport brukes til å zoome kartet til riktig nivå (TU-83).
        let fields: GMSPlaceField = [.coordinate, .name, .addressComponents, .viewport]

        return await withCheckedContinuation { continuation in
            client.fetchPlace(
                fromPlaceID: placeId,
                placeFields: fields,
                sessionToken: sessionToken
            ) { [weak self] place, error in
                Task { @MainActor in
                    self?.sessionToken = GMSAutocompleteSessionToken()
                }

                if let place {
                    let parsed = Self.parseAddressComponents(place.addressComponents ?? [])
                    let viewport: PlaceViewport? = {
                        guard let v = place.viewportInfo, v.isValid else { return nil }
                        return PlaceViewport(
                            neLat: v.northEast.latitude,
                            neLng: v.northEast.longitude,
                            swLat: v.southWest.latitude,
                            swLng: v.southWest.longitude
                        )
                    }()
                    continuation.resume(returning: PlaceDetail(
                        lat: place.coordinate.latitude,
                        lng: place.coordinate.longitude,
                        name: place.name ?? "",
                        streetAddress: parsed.streetAddress,
                        street: parsed.street,
                        houseNumber: parsed.houseNumber,
                        postalCode: parsed.postalCode,
                        city: parsed.city,
                        region: parsed.region,
                        viewport: viewport
                    ))
                } else {
                    if let error {
                        print("Place detail error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Parser Google address components til våre felter.
    /// Norge-spesifikt: postal_town brukes ofte i stedet for locality.
    private static func parseAddressComponents(
        _ components: [GMSAddressComponent]
    ) -> (streetAddress: String?, street: String?, houseNumber: String?, postalCode: String?, city: String?, region: String?) {
        var route: String?
        var streetNumber: String?
        var postalCode: String?
        var locality: String?
        var postalTown: String?
        var region: String?

        for component in components {
            for type in component.types {
                switch type {
                case "route":
                    route = component.name
                case "street_number":
                    streetNumber = component.name
                case "postal_code":
                    postalCode = component.name
                case "locality":
                    locality = component.name
                case "postal_town":
                    postalTown = component.name
                case "administrative_area_level_1":
                    region = component.name
                default:
                    break
                }
            }
        }

        let streetAddress: String? = {
            switch (route, streetNumber) {
            case let (route?, number?): return "\(route) \(number)"
            case let (route?, nil): return route
            default: return nil
            }
        }()

        return (
            streetAddress: streetAddress,
            street: route,
            houseNumber: streetNumber,
            postalCode: postalCode,
            city: locality ?? postalTown,
            region: region
        )
    }

    func clear() {
        searchTask?.cancel()
        predictions = []
        sessionToken = GMSAutocompleteSessionToken()
    }
}
