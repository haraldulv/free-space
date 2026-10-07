import CoreLocation
import Foundation

/// Asker-lanseringens geo-defaults: kartets startpunkt, stedsforslag og
/// togstasjoner for «kollektiv i nærheten». Ingen geofence — appen virker
/// overalt, men vi starter her.
enum AskerDefaults {
    static let centerLat = 59.8346
    static let centerLng = 10.4347

    /// Zoom-nivå som viser Asker sentrum med nabolag (MapKit span ~0.06°).
    static let regionSpanDegrees = 0.06

    struct TransitStation {
        let name: String
        let lat: Double
        let lng: Double
    }

    /// Togstasjoner i og rundt Asker (L1/L2/R10-stoppene).
    static let stations: [TransitStation] = [
        .init(name: "Asker stasjon", lat: 59.8333, lng: 10.4356),
        .init(name: "Bondivann stasjon", lat: 59.8216, lng: 10.4532),
        .init(name: "Vakås stasjon", lat: 59.8495, lng: 10.4635),
        .init(name: "Hvalstad stasjon", lat: 59.8541, lng: 10.4728),
        .init(name: "Billingstad stasjon", lat: 59.8655, lng: 10.4919),
        .init(name: "Høn stasjon", lat: 59.8415, lng: 10.4524),
        .init(name: "Gullhella stasjon", lat: 59.8137, lng: 10.4523),
        .init(name: "Heggedal stasjon", lat: 59.7905, lng: 10.4387),
        .init(name: "Slependen stasjon", lat: 59.8733, lng: 10.5004),
    ]

    struct NearestStation {
        let name: String
        let distanceKm: Double
        /// Gangtid i minutter: 4,5 km/t med 1,3 i stifaktor, rundet opp.
        var walkMinutes: Int {
            Int((distanceKm / 4.5 * 60 * 1.3).rounded(.up))
        }
    }

    /// Nærmeste stasjon fra et punkt, eller nil hvis alt er langt unna
    /// (annonser utenfor Asker-området skal ikke få et misvisende kort).
    static func nearestStation(lat: Double, lng: Double, maxKm: Double = 2.0) -> NearestStation? {
        var best: NearestStation?
        for station in stations {
            let km = haversineKm(lat1: lat, lng1: lng, lat2: station.lat, lng2: station.lng)
            if km <= maxKm && (best == nil || km < best!.distanceKm) {
                best = NearestStation(name: station.name, distanceKm: km)
            }
        }
        return best
    }

    private static func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
