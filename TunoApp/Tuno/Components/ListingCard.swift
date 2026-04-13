import SwiftUI

struct ListingCard: View {
    let listing: Listing
    var isFavorited: Bool = false
    var onFavoriteToggle: ((Bool) -> Void)? = nil
    var compact: Bool = false

    @State private var imageIndex = 0

    private var images: [String] { listing.images ?? [] }

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
                            AsyncImage(url: URL(string: images[imageIndex])) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundStyle(.neutral400)
                                default:
                                    ProgressView()
                                }
                            }
                        )
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Arrow buttons
                if images.count > 1 {
                    HStack {
                        // Left arrow
                        if imageIndex > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    imageIndex -= 1
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.neutral700)
                                    .frame(width: 28, height: 28)
                                    .background(.white.opacity(0.85))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                        } else {
                            Spacer().frame(width: 28)
                        }

                        Spacer()

                        // Right arrow
                        if imageIndex < images.count - 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    imageIndex += 1
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.neutral700)
                                    .frame(width: 28, height: 28)
                                    .background(.white.opacity(0.85))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                        } else {
                            Spacer().frame(width: 28)
                        }
                    }
                    .padding(.horizontal, 8)
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

                // Favorite button
                if let onFavoriteToggle {
                    VStack {
                        HStack {
                            Spacer()
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
                        Spacer()
                    }
                }

                // Instant booking badge
                if listing.instantBooking == true {
                    VStack {
                        Spacer()
                        HStack {
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
                            Spacer()
                        }
                        .padding(10)
                    }
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
                    Text("\(listing.price ?? 0) kr")
                        .font(.system(size: 14, weight: .bold))
                    Text("/ \(listing.priceUnit?.displayName ?? "natt")")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)

                    Spacer()

                    if (listing.spots ?? 1) > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 10))
                            Text("\(listing.spots ?? 1)p")
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
