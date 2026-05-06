import SwiftUI

struct ListingCard: View {
    let listing: Listing
    var isFavorited: Bool = false
    var onFavoriteToggle: ((Bool) -> Void)? = nil
    var compact: Bool = false
    /// Referansekoordinat brukt til å regne ut avstand "X km fra deg".
    /// Sett til søkesenter når brukeren har angitt sted, ellers nil.
    var referenceLat: Double? = nil
    var referenceLng: Double? = nil

    @State private var imageIndex = 0

    private var images: [String] { listing.images ?? [] }

    private var distanceLabel: String? {
        guard let refLat = referenceLat, let refLng = referenceLng,
              let lat = listing.lat, let lng = listing.lng else { return nil }
        let km = haversineDistanceKm(lat1: refLat, lng1: refLng, lat2: lat, lng2: lng)
        if km < 1 {
            let m = Int((km * 1000).rounded())
            return "\(m)m"
        }
        if km < 10 {
            return String(format: "%.1fkm", km).replacingOccurrences(of: ".", with: ",")
        }
        return "\(Int(km.rounded()))km"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with arrow navigation
            ZStack {
                // Current image
                if images.isEmpty {
                    Rectangle()
                        .fill(Color.neutral100)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.neutral400)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Color.neutral100
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            CachedAsyncImage(url: URL(string: images[imageIndex])) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                        )
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Bla-piler — rene chevroner uten sirkel-bakgrunn. Subtil skygge for
                // lesbarhet mot lyse bilder. Hjertet beholder glass-knapp; pilene er
                // enklere fordi bildet selv bærer swipe-affordansen (+ prikkene under).
                if images.count > 1 {
                    HStack {
                        if imageIndex > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    imageIndex -= 1
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        } else {
                            Spacer().frame(width: 32)
                        }

                        Spacer()

                        if imageIndex < images.count - 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    imageIndex += 1
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        } else {
                            Spacer().frame(width: 32)
                        }
                    }
                    .padding(.horizontal, 6)
                }

                // Page dots
                if images.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<min(images.count, 5), id: \.self) { i in
                                Circle()
                                    .fill(i == imageIndex ? .white : .white.opacity(0.5))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }

                // Favorite button — samme design som pil-knappene (ultraThinMaterial,
                // padding 8 på ikonet, 10 fra kant) så de står vertikalt alignet.
                if let onFavoriteToggle {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                onFavoriteToggle(!isFavorited)
                            } label: {
                                Image(systemName: isFavorited ? "heart.fill" : "heart")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(isFavorited ? .red : .white.opacity(0.9))
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                }

                // Bunn-badges: instant booking + 🕒 åpningstid
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if listing.instantBooking == true {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                Text("Direktebestilling")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.neutral700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        if listing.category == .parking,
                           let label = OpeningHoursService.compactLabel(listing.openingHours) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                Text(label)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.neutral700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)

                    Spacer()

                    if let rating = listing.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.neutral900)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.neutral900)
                        }
                    }
                }

                Text("\(listing.city ?? ""), \(listing.region ?? "")")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(listing.displayPriceText) kr")
                        .font(.system(size: 14, weight: .bold))
                    Text("/ \(listing.priceUnit?.displayName ?? "døgn")")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)

                    Spacer()

                    if let label = distanceLabel {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(label)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.neutral500)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 2)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
}
