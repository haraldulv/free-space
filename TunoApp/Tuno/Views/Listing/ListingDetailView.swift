import SwiftUI

/// Airbnb-inspirert annonse-detaljside. Full-bleed image-gallery øverst som
/// strekker seg under toppen, flytende hvit rounded-card under, rating-pill
/// med Gjeste-favoritt-badge når ratingen er høy, kompakt host-kort, og
/// "Ting du bør vite"-seksjon nederst. Bestill-knapp i flytende bunnlinje.
struct ListingDetailView: View {
    let listingId: String
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var favoritesService: FavoritesService
    @State private var listing: Listing?
    @State private var isLoading = true
    @State private var imageIndex = 0
    @State private var showLogin = false
    @State private var chatConversationId: String?
    @State private var chatHostName: String?
    @State private var showChat = false
    @State private var showHostProfile = false
    @State private var showAllAmenities = false
    @StateObject private var chatService = ChatService()

    /// Triggers navbar bakgrunn når man scroller forbi bildene.
    @State private var scrollOffset: CGFloat = 0
    private let heroHeight: CGFloat = 360

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let listing {
                contentView(listing: listing)
            } else {
                Text("Fant ikke annonsen")
                    .foregroundStyle(.neutral500)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
                    roundIconButton(systemName: "square.and.arrow.up") {
                        // TODO share
                    }
                    if authManager.isAuthenticated {
                        roundIconButton(
                            systemName: favoritesService.favoriteIds.contains(listingId) ? "heart.fill" : "heart",
                            foreground: favoritesService.favoriteIds.contains(listingId) ? .red : .neutral900
                        ) {
                            guard let userId = authManager.currentUser?.id else { return }
                            Task { await favoritesService.toggle(listingId: listingId, userId: userId.uuidString) }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .navigationDestination(isPresented: $showChat) {
            if let convoId = chatConversationId {
                ChatView(
                    conversationId: convoId,
                    otherUserName: chatHostName ?? "Utleier",
                    listingTitle: listing?.title ?? "",
                    listingId: listing?.id,
                    listingImage: listing?.images?.first
                )
            }
        }
        .task {
            let service = ListingService()
            listing = await service.fetchListing(id: listingId)
            isLoading = false
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func contentView(listing: Listing) -> some View {
        let images = listing.images ?? []
        let amenities = listing.amenities ?? []
        let hideExact = listing.hideExactLocation ?? false
        let isGuestFavorite = (listing.rating ?? 0) >= 4.8 && (listing.reviewCount ?? 0) >= 5

        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero-gallery
                    heroGallery(images: images)

                    // Innholds-kort som "flyter" opp over bildene
                    VStack(alignment: .leading, spacing: 24) {
                        titleBlock(listing: listing)

                        ratingPillRow(listing: listing, isGuestFavorite: isGuestFavorite)

                        Divider()

                        hostRow(listing: listing)

                        if isGuestFavorite {
                            Divider()
                            guestFavoriteBadge(listing: listing)
                        }

                        Divider()

                        if let desc = listing.description, !desc.isEmpty {
                            descriptionSection(desc)
                            Divider()
                        }

                        if !amenities.isEmpty {
                            amenitiesSection(amenities: amenities)
                            Divider()
                        }

                        extrasSection(listing: listing)

                        locationSection(listing: listing, hideExact: hideExact)
                            .padding(.top, 4)

                        Divider()

                        reviewsSection(listing: listing)

                        Divider()

                        meetHostSection(listing: listing)

                        Divider()

                        thingsToKnowSection(listing: listing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 140)
                    .background(Color.white)
                    .clipShape(RoundedCornersShape(radius: 20, corners: [.topLeft, .topRight]))
                    .offset(y: -20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)

            bookingBar(listing: listing)
        }
        .sheet(isPresented: $showHostProfile) {
            if let hostId = listing.hostId {
                PublicProfileView(
                    hostId: hostId,
                    initialName: listing.hostName,
                    initialAvatar: listing.hostAvatar,
                    initialJoinedYear: listing.hostJoinedYear,
                    initialListingsCount: listing.hostListingsCount
                )
            }
        }
        .sheet(isPresented: $showAllAmenities) {
            AllAmenitiesSheet(amenities: listing.amenities ?? [])
        }
    }

    // MARK: - Hero gallery

    @ViewBuilder
    private func heroGallery(images: [String]) -> some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $imageIndex) {
                if images.isEmpty {
                    Rectangle()
                        .fill(Color.neutral100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.neutral300)
                        )
                        .tag(0)
                } else {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        CachedAsyncImage(url: URL(string: url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.neutral100)
                        }
                        .clipped()
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: heroHeight)

            if !images.isEmpty {
                Text("\(imageIndex + 1) / \(images.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(14)
            }
        }
    }

    // MARK: - Title block

    @ViewBuilder
    private func titleBlock(listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(listing.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
                .lineLimit(3)

            Text(subtitleText(for: listing))
                .font(.system(size: 14))
                .foregroundStyle(.neutral600)
        }
    }

    private func subtitleText(for listing: Listing) -> String {
        var parts: [String] = []
        if let category = listing.category {
            parts.append(category.displayName.capitalized)
        }
        if let city = listing.city, !city.isEmpty {
            parts.append(city)
        }
        let spotCount = listing.spots ?? 1
        parts.append("\(spotCount) \(spotCount == 1 ? "plass" : "plasser")")
        if let maxLen = listing.maxVehicleLength, maxLen > 0 {
            parts.append("Maks \(Int(maxLen))m")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Rating pill row

    @ViewBuilder
    private func ratingPillRow(listing: Listing, isGuestFavorite: Bool) -> some View {
        HStack(spacing: 0) {
            if let rating = listing.rating, (listing.reviewCount ?? 0) > 0 {
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral900)
                        Text(String(format: "%.2f", rating).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.neutral900)
                    }
                    Text("Vurdering")
                        .font(.system(size: 10))
                        .foregroundStyle(.neutral500)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 4) {
                    Text("Ny")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Vurdering")
                        .font(.system(size: 10))
                        .foregroundStyle(.neutral500)
                }
                .frame(maxWidth: .infinity)
            }

            if isGuestFavorite {
                Divider().frame(height: 36)
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#d4a84b"))
                        Text("Gjeste")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.neutral900)
                        Image(systemName: "laurel.trailing")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#d4a84b"))
                    }
                    Text("favoritt")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.neutral900)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().frame(height: 36)
            VStack(spacing: 4) {
                Text("\(listing.reviewCount ?? 0)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text((listing.reviewCount ?? 0) == 1 ? "Anmeldelse" : "Anmeldelser")
                    .font(.system(size: 10))
                    .foregroundStyle(.neutral500)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral50)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.neutral200.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Host row (kompakt versjon)

    @ViewBuilder
    private func hostRow(listing: Listing) -> some View {
        Button {
            showHostProfile = true
        } label: {
            HStack(spacing: 12) {
                CachedAsyncImage(url: URL(string: listing.hostAvatar ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.primary100).overlay(
                        Text(String((listing.hostName ?? "?").prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary600)
                    )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(listing.hostName ?? "Utleier") er vertskap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    if let year = listing.hostJoinedYear {
                        let years = max(Calendar.current.component(.year, from: Date()) - year, 0)
                        Text(years == 0 ? "Ny vert" : "\(years) år som vertskap")
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gjeste-favoritt-badge

    @ViewBuilder
    private func guestFavoriteBadge(listing: Listing) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#d4a84b"))
                Text(String(format: "%.2f", listing.rating ?? 0).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.neutral900)
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#d4a84b"))
            }
            Text("Gjeste-favoritt")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text("Dette stedet er blant de **topp 1 %** av utleiestedene basert på vurderinger, anmeldelser og pålitelighet.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Om denne plassen")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)
            Text(desc)
                .font(.system(size: 15))
                .foregroundStyle(.neutral700)
                .lineSpacing(4)
        }
    }

    // MARK: - Amenities

    @ViewBuilder
    private func amenitiesSection(amenities: [String]) -> some View {
        let preview = Array(amenities.prefix(6))
        VStack(alignment: .leading, spacing: 14) {
            Text("Dette stedet byr på")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)

            VStack(spacing: 12) {
                ForEach(preview, id: \.self) { amenity in
                    let type = AmenityType(rawValue: amenity)
                    HStack(spacing: 14) {
                        Image(systemName: type?.icon ?? "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.neutral900)
                            .frame(width: 26)
                        Text(type?.label ?? amenity)
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral800)
                        Spacer()
                    }
                }
            }

            if amenities.count > 6 {
                Button {
                    showAllAmenities = true
                } label: {
                    Text("Vis alle \(amenities.count) fasiliteter")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.neutral900, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Extras

    @ViewBuilder
    private func extrasSection(listing: Listing) -> some View {
        let listingExtras = listing.extras ?? []
        let spotsWithExtras = (listing.spotMarkers ?? []).enumerated().filter { !($0.element.extras ?? []).isEmpty }
        if !listingExtras.isEmpty || !spotsWithExtras.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tilgjengelige tillegg")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.neutral900)

                if !listingExtras.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Felles tillegg")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                        extrasChips(listingExtras)
                    }
                }

                if !spotsWithExtras.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Per plass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.neutral500)
                        ForEach(spotsWithExtras, id: \.offset) { idx, spot in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(spot.label?.trimmingCharacters(in: .whitespaces).isEmpty == false ? spot.label! : "Plass \(idx + 1)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.neutral900)
                                extrasChips(spot.extras ?? [])
                            }
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neutral200, lineWidth: 1))
                        }
                    }
                }
            }

            Divider()
        }
    }

    // MARK: - Location

    @ViewBuilder
    private func locationSection(listing: Listing, hideExact: Bool) -> some View {
        if let lat = listing.lat, let lng = listing.lng {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hvor du kommer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.neutral900)

                if let city = listing.city {
                    Text(hideExact ? "\(city), Norge" : (listing.address ?? city))
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral600)
                }

                ListingMapView(
                    lat: lat,
                    lng: lng,
                    spotMarkers: listing.spotMarkers ?? [],
                    hideExactLocation: hideExact
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if hideExact {
                    Text("Eksakt adresse deles etter bekreftet booking.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
            }
        }
    }

    // MARK: - Reviews placeholder

    @ViewBuilder
    private func reviewsSection(listing: Listing) -> some View {
        let count = listing.reviewCount ?? 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                Text(String(format: "%.2f", listing.rating ?? 0).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 18, weight: .bold))
                Text("·")
                    .foregroundStyle(.neutral400)
                Text("\(count) \(count == 1 ? "anmeldelse" : "anmeldelser")")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.neutral900)

            if count == 0 {
                Text("Ingen anmeldelser ennå — vær den første til å dele din opplevelse!")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    // MARK: - Meet host

    @ViewBuilder
    private func meetHostSection(listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Møt verten")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    CachedAsyncImage(url: URL(string: listing.hostAvatar ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.primary100).overlay(
                            Text(String((listing.hostName ?? "?").prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.primary600)
                        )
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())

                    Text(listing.hostName ?? "Utleier")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Tuno-vert")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("\(listing.reviewCount ?? 0)")
                            .font(.system(size: 20, weight: .bold))
                        Text("anmeldelser")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                    Divider().padding(.vertical, 8)
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Text(String(format: "%.2f", listing.rating ?? 0).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 20, weight: .bold))
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                        }
                        Text("vurdering")
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                    if let year = listing.hostJoinedYear {
                        let years = max(Calendar.current.component(.year, from: Date()) - year, 0)
                        Divider().padding(.vertical, 8)
                        VStack(spacing: 2) {
                            Text("\(years)")
                                .font(.system(size: 20, weight: .bold))
                            Text(years == 1 ? "år som vertskap" : "år som vertskap")
                                .font(.system(size: 11))
                                .foregroundStyle(.neutral500)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(width: 120)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.neutral200, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            if authManager.isAuthenticated,
               let hostId = listing.hostId,
               hostId != authManager.currentUser?.id.uuidString {
                Button {
                    Task {
                        guard let userId = authManager.currentUser?.id else { return }
                        let convoId = await chatService.getOrCreateConversation(
                            listingId: listing.id,
                            guestId: userId.uuidString,
                            hostId: hostId
                        )
                        if let convoId {
                            chatConversationId = convoId
                            chatHostName = listing.hostName ?? "Utleier"
                            showChat = true
                        }
                    }
                } label: {
                    Text("Kontakt verten")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.neutral900, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Things to know

    @ViewBuilder
    private func thingsToKnowSection(listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ting du bør vite")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.neutral900)

            thingsRow(icon: "calendar",
                      title: "Kansellering",
                      subtitle: "Gratis avbestilling innen 48 t — etterpå gjelder utleiers vilkår.")

            thingsRow(icon: "clock",
                      title: "Inn- og utsjekking",
                      subtitle: "Innsjekking fra \(listing.checkInTime ?? "15:00") · Utsjekking innen \(listing.checkOutTime ?? "11:00")")

            if let spots = listing.spots {
                thingsRow(icon: "car.2.fill",
                          title: "Plasser",
                          subtitle: "\(spots) \(spots == 1 ? "plass tilgjengelig" : "plasser tilgjengelig")" +
                          (listing.maxVehicleLength.map { " · Maks \(Int($0))m" } ?? ""))
            }

            thingsRow(icon: "shield.lefthalf.filled",
                      title: "Trygg betaling",
                      subtitle: "Tuno holder pengene til du har sjekket inn.")
        }
    }

    @ViewBuilder
    private func thingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.neutral900)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
            }
            Spacer()
        }
    }

    // MARK: - Booking bar

    @ViewBuilder
    private func bookingBar(listing: Listing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("\(listing.displayPriceText) kr")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("/ \(listing.priceUnit?.displayName ?? "natt")")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral600)
                }
                if listing.instantBooking == true {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("Direktebestilling")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.primary600)
                } else if let rating = listing.rating, (listing.reviewCount ?? 0) > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.2f", rating).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 12, weight: .semibold))
                        Text("· \(listing.reviewCount ?? 0)")
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral500)
                    }
                    .foregroundStyle(.neutral900)
                }
            }

            Spacer()

            if authManager.isAuthenticated {
                if let userId = authManager.currentUser?.id.uuidString.lowercased(),
                   let hostId = listing.hostId?.lowercased(),
                   userId == hostId {
                    Text("Din annonse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.neutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    NavigationLink {
                        BookingView(listing: listing)
                    } label: {
                        Text("Reserver")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(Color.primary600)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.primary600.opacity(0.3), radius: 8, y: 2)
                    }
                }
            } else {
                Button {
                    showLogin = true
                } label: {
                    Text("Logg inn")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.neutral200).frame(height: 0.5)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func extrasChips(_ extras: [ListingExtra]) -> some View {
        VStack(spacing: 8) {
            ForEach(extras, id: \.id) { ex in
                HStack(spacing: 10) {
                    Image(systemName: ExtraType(rawValue: ex.id)?.icon ?? "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary600)
                        .frame(width: 20)
                    Text(ex.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral800)
                    Spacer()
                    Text("\(ex.price) kr\(ex.perNight ? "/natt" : "")")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.neutral200, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func roundIconButton(systemName: String, foreground: Color = .neutral900, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        }
    }
}

// MARK: - InfoRow (gjenbrukt andre steder)

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

// MARK: - Rounded corners på topp (kun topLeft + topRight)

private struct RoundedCornersShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Alle fasiliteter-sheet

private struct AllAmenitiesSheet: View {
    let amenities: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(amenities, id: \.self) { amenity in
                        let type = AmenityType(rawValue: amenity)
                        HStack(spacing: 14) {
                            Image(systemName: type?.icon ?? "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.neutral900)
                                .frame(width: 26)
                            Text(type?.label ?? amenity)
                                .font(.system(size: 15))
                                .foregroundStyle(.neutral800)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Det dette stedet byr på")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
        }
    }
}
