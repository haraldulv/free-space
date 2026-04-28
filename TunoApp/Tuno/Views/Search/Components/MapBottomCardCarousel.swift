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

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(listings.enumerated()), id: \.offset) { index, listing in
                MapListingBigCard(
                    listing: listing,
                    isFavorited: isFavorited(listing.id),
                    onTap: { onTap(listing) },
                    onClose: onClose,
                    onFavoriteToggle: { onFavoriteToggle(listing.id) }
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

    @State private var imageIndex: Int = 0

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
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 180)
            .clipped()

            // Top-right: hjerte + X-lukk
            HStack(spacing: 8) {
                Button(action: onFavoriteToggle) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFavorited ? .red : .white)
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
                if let spots = listing.spots, spots > 1 {
                    Text("\(spots) plasser")
                        .font(.system(size: 12))
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

            Text("\(listing.displayPriceText) kr/\(listing.priceUnit?.displayName ?? "natt")")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.top, 2)
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
