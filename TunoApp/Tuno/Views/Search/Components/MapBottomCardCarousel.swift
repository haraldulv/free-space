import SwiftUI

/// Swipebar carousel som vises i bunnen av kartsøket når en boble er
/// valgt. Bruker TabView med page-stil; sveip horisontalt for å bla
/// til neste annonse — kartet zoomer automatisk til den nye listingen.
struct MapBottomCardCarousel: View {
    let listings: [Listing]
    @Binding var selectedIndex: Int
    let onTap: (Listing) -> Void

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(listings.enumerated()), id: \.offset) { index, listing in
                MapListingCard(listing: listing) { onTap(listing) }
                    .padding(.horizontal, 12)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 110)
        .padding(.bottom, 12)
    }
}
