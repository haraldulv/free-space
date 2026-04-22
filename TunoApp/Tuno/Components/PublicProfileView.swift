import SwiftUI

/// Offentlig profil-sheet — vises når man trykker på en host/utleier.
/// Kun offentlige felt: navn, avatar, medlem-siden, antall annonser, rating, bio.
/// Viser også listen over hostens andre aktive annonser og en "kontakt"-knapp
/// (hvis visende bruker ikke er host selv).
struct PublicProfileView: View {
    let hostId: String
    var initialName: String? = nil
    var initialAvatar: String? = nil
    var initialJoinedYear: Int? = nil
    var initialListingsCount: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var chatService = ChatService()
    @State private var profile: PublicHostProfile?
    @State private var hostListings: [Listing] = []
    @State private var isLoading = true
    @State private var selectedListing: Listing?
    @State private var contactingConvoId: String?
    @State private var isContacting = false
    @State private var contactError: String?

    private var viewingSelf: Bool {
        authManager.currentUser?.id.uuidString.lowercased() == hostId.lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    nameSection
                    statsRow

                    if let bio = profile?.bio, !bio.isEmpty {
                        bioSection(bio)
                    }

                    if !viewingSelf {
                        contactButton
                    }

                    if !hostListings.isEmpty {
                        listingsSection
                    }

                    if isLoading {
                        ProgressView()
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedListing) { listing in
                ListingDetailView(listingId: listing.id)
            }
            .navigationDestination(item: $contactingConvoId) { convoId in
                ChatView(
                    conversationId: convoId,
                    otherUserName: profile?.fullName ?? initialName ?? "Utleier",
                    listingTitle: hostListings.first?.title ?? "",
                    listingId: hostListings.first?.id,
                    listingImage: hostListings.first?.images?.first
                )
            }
            .alert("Kunne ikke starte samtale", isPresented: .init(
                get: { contactError != nil },
                set: { if !$0 { contactError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(contactError ?? "")
            }
        }
        .task { await loadProfile() }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(url: URL(string: profile?.avatarUrl ?? initialAvatar ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color.neutral100).overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.neutral400)
                )
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primary600, lineWidth: 3))

            if isVerified {
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                    Image(systemName: "seal.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#1d9bf0"))
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.top, 20)
    }

    /// Verifisert = fullført Stripe-onboarding. Matcher logikken i
    /// ProfileSummaryCard på ens egen profil. Kan utvides senere med BankID o.l.
    private var isVerified: Bool {
        profile?.stripeOnboardingComplete ?? false
    }

    private var nameSection: some View {
        VStack(spacing: 6) {
            Text(profile?.fullName ?? initialName ?? "Utleier")
                .font(.system(size: 22, weight: .bold))
            if let loc = profile?.location, !loc.isEmpty {
                Text(loc)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral600)
            }
            if let joined = profile?.joinedYear ?? initialJoinedYear {
                // String(joined) omgår Norwegian locale thousand-separator ("2 026")
                Text("Medlem siden \(String(joined))")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 24) {
            let count = hostListings.isEmpty ? initialListingsCount : hostListings.count
            if let count {
                statBlock(value: "\(count)", label: count == 1 ? "annonse" : "annonser")
            }
            if let rating = profile?.rating, rating > 0, let reviewCount = profile?.reviewCount, reviewCount > 0 {
                statBlock(
                    value: String(format: "%.1f", rating).replacingOccurrences(of: ".", with: ","),
                    label: reviewCount == 1 ? "anmeldelse" : "anmeldelser",
                    icon: "star.fill"
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Om")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text(bio)
                .font(.system(size: 14))
                .foregroundStyle(.neutral700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var contactButton: some View {
        Button {
            Task { await startConversation() }
        } label: {
            HStack(spacing: 8) {
                if isContacting {
                    ProgressView().tint(.primary600)
                } else {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                }
                Text(isContacting ? "Åpner samtale …" : "Kontakt \(profile?.fullName?.components(separatedBy: " ").first ?? "utleier")")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.primary600)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isContacting || hostListings.isEmpty)
        .opacity(hostListings.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20)
    }

    private var listingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hostListings.count == 1 ? "Annonse" : "Annonser (\(hostListings.count))")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hostListings) { listing in
                        Button {
                            selectedListing = listing
                        } label: {
                            listingCard(listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func listingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.neutral100)
            }
            .frame(width: 220, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(listing.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral900)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)

            if let city = listing.city {
                Text(city)
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                    .frame(width: 220, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 14))
                }
                Text(value).font(.system(size: 18, weight: .bold))
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.neutral500)
        }
    }

    // MARK: - Data loading + contact

    @MainActor
    private func loadProfile() async {
        do {
            async let profileTask: [PublicHostProfile] = supabase
                .from("profiles")
                .select("id, full_name, avatar_url, joined_year, rating, review_count, bio, location, stripe_onboarding_complete")
                .eq("id", value: hostId)
                .limit(1)
                .execute()
                .value

            async let listingsTask: [Listing] = supabase
                .from("listings")
                .select()
                .eq("host_id", value: hostId)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            let (profiles, listings) = try await (profileTask, listingsTask)
            profile = profiles.first
            hostListings = listings
        } catch {
            print("loadProfile error: \(error)")
        }
        isLoading = false
    }

    @MainActor
    private func startConversation() async {
        guard let userId = authManager.currentUser?.id else {
            contactError = "Du må være logget inn."
            return
        }
        guard let firstListing = hostListings.first else {
            contactError = "Denne verten har ingen aktive annonser akkurat nå."
            return
        }
        isContacting = true
        let convoId = await chatService.getOrCreateConversation(
            listingId: firstListing.id,
            guestId: userId.uuidString,
            hostId: hostId
        )
        isContacting = false
        if let convoId {
            contactingConvoId = convoId
        } else {
            contactError = "Noe gikk galt. Prøv igjen."
        }
    }
}

struct PublicHostProfile: Codable {
    let id: String
    let fullName: String?
    let avatarUrl: String?
    let joinedYear: Int?
    let rating: Double?
    let reviewCount: Int?
    let bio: String?
    let location: String?
    let stripeOnboardingComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case joinedYear = "joined_year"
        case rating
        case reviewCount = "review_count"
        case bio
        case location
        case stripeOnboardingComplete = "stripe_onboarding_complete"
    }
}
