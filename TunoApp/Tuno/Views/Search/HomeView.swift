import SwiftUI

struct HomeView: View {
    @StateObject private var listingService = ListingService()
    @State private var searchText = ""
    @State private var showSearch = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 16) {
                    Image("TunoLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)

                    // Search bar
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.neutral400)
                            Text("Hvor skal du?")
                                .foregroundStyle(.neutral400)
                            Spacer()
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if listingService.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if listingService.popularListings.isEmpty && listingService.featuredListings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundStyle(.neutral300)
                        Text("Ingen plasser å vise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(.top, 40)
                } else {
                    // Popular listings
                    if !listingService.popularListings.isEmpty {
                        ListingSection(
                            title: "Populære i Norge",
                            listings: listingService.popularListings
                        )
                    }

                    // Featured
                    if !listingService.featuredListings.isEmpty {
                        ListingSection(
                            title: "Fremhevede i Norge",
                            listings: listingService.featuredListings
                        )
                    }

                    // Available today
                    if !listingService.availableTodayListings.isEmpty {
                        ListingSection(
                            title: "Tilgjengelig i dag",
                            listings: listingService.availableTodayListings
                        )
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.neutral50)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showSearch) {
            SearchView()
        }
        .task {
            await listingService.fetchHomeListings()
        }
    }
}

struct ListingSection: View {
    let title: String
    let listings: [Listing]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingCard(listing: listing)
                                .frame(width: 280)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationDestination(for: Listing.self) { listing in
            ListingDetailView(listingId: listing.id)
        }
    }
}
