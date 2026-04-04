import SwiftUI

struct ListingDetailView: View {
    let listingId: String
    @EnvironmentObject var authManager: AuthManager
    @State private var listing: Listing?
    @State private var isLoading = true
    @State private var imageIndex = 0
    @State private var showLogin = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let listing {
                let images = listing.images ?? []
                let amenities = listing.amenities ?? []
                let hideExact = listing.hideExactLocation ?? false

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Image gallery
                        TabView(selection: $imageIndex) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        Rectangle().fill(Color.neutral100)
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 300)

                        VStack(alignment: .leading, spacing: 20) {
                            // Category badge + title
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    if let cat = listing.category {
                                        Text(cat.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.primary50)
                                            .foregroundStyle(.primary600)
                                            .clipShape(Capsule())
                                    }

                                    if let maxLen = listing.maxVehicleLength {
                                        Text("Max \(Int(maxLen))m")
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.neutral100)
                                            .foregroundStyle(.neutral600)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(listing.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.neutral900)
                            }

                            // Location, spots, times
                            VStack(spacing: 8) {
                                InfoRow(icon: "mappin", text: "\(listing.address ?? ""), \(listing.city ?? "")")
                                InfoRow(icon: "car.2.fill", text: "\(listing.spots ?? 1) plasser")
                                InfoRow(icon: "clock", text: "Inn \(listing.checkInTime ?? "15:00") / Ut \(listing.checkOutTime ?? "11:00")")
                            }

                            Divider()

                            // Description
                            if let desc = listing.description, !desc.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Om denne plassen")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(desc)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.neutral600)
                                        .lineSpacing(4)
                                }

                                Divider()
                            }

                            // Amenities
                            if !amenities.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Fasiliteter")
                                        .font(.system(size: 18, weight: .semibold))

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                        ForEach(amenities, id: \.self) { amenity in
                                            let type = AmenityType(rawValue: amenity)
                                            HStack(spacing: 8) {
                                                Image(systemName: type?.icon ?? "checkmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.primary600)
                                                    .frame(width: 20)
                                                Text(type?.label ?? amenity)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.neutral700)
                                                Spacer()
                                            }
                                        }
                                    }
                                }

                                Divider()
                            }

                            // Map
                            if let lat = listing.lat, let lng = listing.lng {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(hideExact ? "Omtrentlig plassering" : "Plassering")
                                        .font(.system(size: 18, weight: .semibold))

                                    if !hideExact {
                                        HStack(spacing: 4) {
                                            Image(systemName: "mappin")
                                                .font(.system(size: 12))
                                            Text(listing.address ?? "")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundStyle(.neutral500)
                                    }

                                    ListingMapView(
                                        lat: lat,
                                        lng: lng,
                                        spotMarkers: listing.spotMarkers ?? [],
                                        hideExactLocation: hideExact
                                    )
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    if hideExact {
                                        Text("Eksakt adresse deles etter bekreftet booking.")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral400)
                                    }
                                }

                                Divider()
                            }

                            // Rating
                            if let rating = listing.rating, let count = listing.reviewCount, count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.neutral900)
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 16, weight: .bold))
                                    Text("(\(count) anmeldelser)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.neutral500)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .bottom) {
                    // Booking bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(listing.price ?? 0) kr")
                                    .font(.system(size: 18, weight: .bold))
                                Text("/ \(listing.priceUnit?.displayName ?? "natt")")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.neutral500)
                            }
                            if listing.instantBooking == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10))
                                    Text("Direktebestilling")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        if authManager.isAuthenticated {
                            NavigationLink {
                                BookingView(listing: listing)
                            } label: {
                                Text("Bestill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.primary600)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Button {
                                showLogin = true
                            } label: {
                                Text("Logg inn for å bestille")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.primary600)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            } else {
                Text("Fant ikke annonsen")
                    .foregroundStyle(.neutral500)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: Share
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.neutral600)
                }
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .task {
            let service = ListingService()
            listing = await service.fetchListing(id: listingId)
            isLoading = false
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.neutral400)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
        }
    }
}

