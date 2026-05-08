import SwiftUI

/// Stort Airbnb-inspirert kort som vises i bunnen av kartsøket når en
/// boble er valgt. Sveip horisontalt for å bla til neste annonse —
/// kartet pannes til den nye listingen samtidig.
/// Innhold: bilde-carousel øverst (~200pt) med hjerte + lukke-knapp,
/// tittel/lokasjon/badge/rating og total-pris under.
struct MapBottomCardCarousel: View {
    let listings: [Listing]
    @Binding var selectedIndex: Int
    let onTap: (Listing) -> Void
    let onClose: () -> Void
    let isFavorited: (String) -> Bool
    let onFavoriteToggle: (String) -> Void
    var referenceLat: Double? = nil
    var referenceLng: Double? = nil

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(listings.enumerated()), id: \.offset) { index, listing in
                MapListingBigCard(
                    listing: listing,
                    isFavorited: isFavorited(listing.id),
                    onTap: { onTap(listing) },
                    onClose: onClose,
                    onFavoriteToggle: { onFavoriteToggle(listing.id) },
                    referenceLat: referenceLat,
                    referenceLng: referenceLng
                )
                .padding(.horizontal, 12)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 320)
        .padding(.bottom, 8)
    }
}

/// Stort listing-kort til bruk i bottom-carousel på kartet.
/// Layout: bilde-carousel (~180pt) + tittel/by/rating/totalt-pris.
struct MapListingBigCard: View {
    let listing: Listing
    let isFavorited: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    let onFavoriteToggle: () -> Void
    var referenceLat: Double? = nil
    var referenceLng: Double? = nil

    @State private var imageIndex: Int = 0

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
        VStack(spacing: 0) {
            imageSection
            infoSection
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 0)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { onTap() }
    }

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $imageIndex) {
                if let images = listing.images, !images.isEmpty {
                    ForEach(Array(images.enumerated()), id: \.offset) { idx, urlString in
                        AsyncImage(url: URL(string: urlString)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(Color.neutral100)
                            }
                        }
                        .tag(idx)
                    }
                } else {
                    Rectangle().fill(Color.neutral100).tag(0)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)
            .clipped()
            .overlay(alignment: .bottom) {
                // Custom page-prikker (matcher ListingCard på forsiden) i
                // stedet for SwiftUI's pill-stil-indikator. Plain hvite dots,
                // sentrert. Vises på samme høyde som åpningstid-tag.
                if let images = listing.images, images.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<min(images.count, 5), id: \.self) { i in
                            Circle()
                                .fill(i == imageIndex ? .white : .white.opacity(0.5))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }

            // Top-right: hjerte + X-lukk
            HStack(spacing: 8) {
                Button(action: onFavoriteToggle) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFavorited ? .red : .neutral900)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.trailing, 12)

            // Top-left: gjestefavoritt-badge hvis høy rating
            if isGuestFavorite {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Gjestefavoritt")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.95))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                .padding(.top, 12)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Åpningstid-tag flyttet til .overlay på TabView lenger oppe —
            // VStack+Spacer-pattern her vil ikke fungere fordi ZStack-en
            // ikke har høyde-constraint og overflyte image-bunnen.
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(1)
                Spacer()
                if let rating = listing.rating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral900)
                        Text(String(format: "%.2f", rating))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        if let reviews = listing.reviewCount, reviews > 0 {
                            Text("(\(reviews))")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                        }
                    }
                }
            }

            if let city = listing.city {
                Text(city)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if let label = distanceLabel {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(label)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.neutral500)
                }
                if listing.instantBooking == true {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.primary600)
                        Text("Direktebooking")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary600)
                    }
                }
            }

            if let h = listing.headlinePrice {
                Text(h.suffix.isEmpty
                    ? "\(h.price) kr/\(listing.priceUnit?.displayName ?? "døgn")"
                    : "\(h.price) kr\(h.suffix)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.neutral900)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var isGuestFavorite: Bool {
        guard let rating = listing.rating, rating >= 4.8 else { return false }
        guard let count = listing.reviewCount, count >= 5 else { return false }
        return true
    }
}
