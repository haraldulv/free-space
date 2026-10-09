import Foundation

// MARK: - Tall og avstander (delte formateringshjelpere)

/// Kompakt avstandsetikett: "350m", "1,2km", "12km".
func formatDistanceLabel(km: Double) -> String {
    if km < 1 {
        let m = Int((km * 1000).rounded())
        return "\(m)m"
    }
    if km < 10 {
        return String(format: "%.1fkm", km).replacingOccurrences(of: ".", with: ",")
    }
    return "\(Int(km.rounded()))km"
}

private let nokGroupingFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "nb_NO")
    f.maximumFractionDigits = 0
    return f
}()

extension Int {
    /// Norsk tusenskille: 1400 → "1 400".
    var nokFormatted: String {
        nokGroupingFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Listing {
    /// "350m"/"1,2km"/"12km" fra et referansepunkt, eller nil når koordinater mangler.
    func distanceLabel(fromLat: Double?, fromLng: Double?) -> String? {
        guard let refLat = fromLat, let refLng = fromLng,
              let lat = lat, let lng = lng else { return nil }
        return formatDistanceLabel(km: haversineDistanceKm(lat1: refLat, lng1: refLng, lat2: lat, lng2: lng))
    }

    /// Kompakt prislinje for parkering: "60 kr/dag · 1 400 kr/mnd".
    /// Faller tilbake på headlinePriceText for annonser uten dag-/månedspris.
    var parkingPriceLine: String {
        var parts: [String] = []
        if let day = parkingDayPrice {
            parts.append("\(day.nokFormatted) kr/dag")
        }
        if let month = parkingMonthPrice {
            parts.append("\(month.nokFormatted) kr/mnd")
        }
        if parts.isEmpty { return headlinePriceText }
        return parts.joined(separator: " · ")
    }
}
