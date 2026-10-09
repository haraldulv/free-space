import SwiftUI

/// Kompakt, fakta-først rad for parkeringsannonser (Asker-pivoten).
/// Prisen leder, bildet er dokumentasjon: 88×88-thumb til venstre,
/// prislinje/tittel/faktalinje til høyre. Brukes i kartsøkets liste-skuff
/// og i kompaktkortet når en kartboble er valgt.
struct ParkingListingRow: View {
    let listing: Listing
    var isFavorited: Bool = false
    var onFavoriteToggle: ((Bool) -> Void)? = nil
    /// Satt i kart-kompaktkortet: viser en X i hjertets slot i stedet
    /// (favoritt er tilgjengelig i skuffen og på annonsesiden).
    var onClose: (() -> Void)? = nil
    /// Referansepunkt for avstandsetiketten (søkesenteret).
    var referenceLat: Double? = nil
    var referenceLng: Double? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumb
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 8) {
                    Text(listing.parkingPriceLine)
                        .font(.tuno(.heading))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    trailingControl
                }
                Text(listing.title)
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral600)
                    .lineLimit(1)
                factLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                .stroke(Color.paperLine, lineWidth: 1)
        )
    }

    // MARK: - Deler

    private var thumb: some View {
        CachedAsyncImage(url: (listing.images ?? []).first.flatMap(URL.init(string:))) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color.neutral100)
                .overlay(
                    Image(systemName: "car.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.neutral400)
                )
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var trailingControl: some View {
        if let onClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 26, height: 26)
                    .background(Color.neutral100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        } else if let onFavoriteToggle {
            Button {
                onFavoriteToggle(!isFavorited)
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFavorited ? .red : .neutral400)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var factLine: some View {
        HStack(spacing: 4) {
            if listing.instantBooking == true {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.mint)
            }
            Text(factText)
                .font(.tuno(.caption))
                .foregroundStyle(.neutral500)
                .lineLimit(2)
        }
    }

    private var factText: String {
        var parts: [String] = []
        if let lat = listing.lat, let lng = listing.lng,
           let station = AskerDefaults.nearestStation(lat: lat, lng: lng) {
            parts.append("\(station.walkMinutes) min til \(station.name)")
        }
        if let type = listing.parkingType {
            parts.append(type.displayName)
        }
        if let distance = listing.distanceLabel(fromLat: referenceLat, fromLng: referenceLng) {
            parts.append(distance)
        }
        return parts.joined(separator: " · ")
    }
}
