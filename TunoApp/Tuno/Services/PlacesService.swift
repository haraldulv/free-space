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
        let fields: GMSPlaceField = [.coordinate, .name]

        return await withCheckedContinuation { continuation in
            client.fetchPlace(
                fromPlaceID: placeId,
                placeFields: fields,
                sessionToken: sessionToken
            ) { [weak self] place, error in
                // Reset session token after fetch (completes the session)
                Task { @MainActor in
                    self?.sessionToken = GMSAutocompleteSessionToken()
                }

                if let place {
                    continuation.resume(returning: PlaceDetail(
                        lat: place.coordinate.latitude,
                        lng: place.coordinate.longitude,
                        name: place.name ?? ""
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

    func clear() {
        searchTask?.cancel()
        predictions = []
        sessionToken = GMSAutocompleteSessionToken()
    }
}
