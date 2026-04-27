import SwiftUI

/// Vedvarende drawer i bunnen av kartsøket. To tilstander:
/// - Kollapset peek (~76pt) viser "X plasser" + drag handle
/// - Ekspandert (~75% av skjermen) viser scrollable liste av annonser
/// Drar opp for å åpne, drar ned eller trykker chevron for å lukke.
/// Lever som .overlay på kartet, så kartet er interaktivt overalt
/// utenfor selve drawer-arealet.
struct BottomListDrawer: View {
    let listings: [Listing]
    let isFavorited: (String) -> Bool
    let onFavorite: (String) -> Void
    let onSelect: (Listing) -> Void

    @State private var isExpanded = false
    @State private var dragTranslation: CGFloat = 0

    private let collapsedHeight: CGFloat = 76

    var body: some View {
        GeometryReader { geo in
            let expandedHeight: CGFloat = max(420, geo.size.height * 0.78)
            let baseHeight = isExpanded ? expandedHeight : collapsedHeight
            // Drag-justering: positiv translation = drar ned (mindre høyde), negativ = opp (større)
            let height = max(collapsedHeight, min(expandedHeight, baseHeight - dragTranslation))

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                drawerContent(height: height, geoHeight: geo.size.height)
                    .frame(height: height)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
                    )
                    .gesture(dragGesture)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
                    .animation(.interactiveSpring(), value: dragTranslation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func drawerContent(height: CGFloat, geoHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Drag handle — alltid synlig
            Capsule()
                .fill(Color.neutral300)
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            if isExpanded {
                // Header med tittel og lukk-knapp
                HStack {
                    Text(countLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.neutral700)
                            .frame(width: 32, height: 32)
                            .background(Color.neutral100)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(listings) { listing in
                            Button {
                                onSelect(listing)
                            } label: {
                                ListingCard(
                                    listing: listing,
                                    isFavorited: isFavorited(listing.id),
                                    onFavoriteToggle: { _ in onFavorite(listing.id) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isExpanded = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(countLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.neutral900)
                        Spacer()
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
    }

    private var countLabel: String {
        listings.count == 1 ? "1 plass" : "\(listings.count) plasser"
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if isExpanded {
                        // Lukk hvis dratt ned mer enn 100pt eller har høy ned-fart
                        if predicted > 100 { isExpanded = false }
                    } else {
                        // Åpne hvis dratt opp mer enn 60pt eller har høy opp-fart
                        if predicted < -60 { isExpanded = true }
                    }
                    dragTranslation = 0
                }
            }
    }
}

/// Liten sirkulær toggle-knapp for å bytte mellom standard og satellitt-kart.
/// Plasseres typisk øverst-til-høyre på kartet, under filter-knappen.
struct MapTypeToggleButton: View {
    let isSatellite: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isSatellite ? "map.fill" : "globe.europe.africa.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
