import SwiftUI

struct ListingCard: View {
    let listing: Listing
    var isFavorited: Bool = false
    var onFavoriteToggle: ((Bool) -> Void)? = nil

    @State private var imageIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image carousel
            ZStack(alignment: .topTrailing) {
                TabView(selection: $imageIndex) {
                    ForEach(Array(listing.images.enumerated()), id: \.offset) { index, url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(Color.neutral100)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundStyle(.neutral400)
                                    )
                            default:
                                Rectangle()
                                    .fill(Color.neutral100)
                                    .overlay(ProgressView())
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: listing.images.count > 1 ? .automatic : .never))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Favorite button
                if let onFavoriteToggle {
                    Button {
                        onFavoriteToggle(!isFavorited)
                    } label: {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isFavorited ? .red : .white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(10)
                }

                // Instant booking badge
                if listing.instantBooking {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("Direktebestilling")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(10)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)

                    Spacer()

                    if let rating = listing.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral900)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.neutral900)
                        }
                    }
                }

                Text("\(listing.city), \(listing.region)")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(listing.price) kr")
                        .font(.system(size: 15, weight: .bold))
                    Text("/ \(listing.priceUnit.displayName)")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)

                    Spacer()

                    if listing.spots > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 11))
                            Text("\(listing.spots)p")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.neutral500)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 2)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }
}
